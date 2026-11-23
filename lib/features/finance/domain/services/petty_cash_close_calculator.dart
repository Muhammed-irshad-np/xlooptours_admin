import '../entities/fund_transaction_entity.dart';

/// All petty-cash closing maths, in integer minor units (halalas), so no
/// floating point rounding can creep into a balance.
///
/// The expected closing amounts are the account's own Cash and STC Pay
/// balances. Those are maintained inside Firestore transactions for every
/// posting, so they already include everything the ledger did today
/// (expenses, deposits, advances, salaries, transfers, adjustments, voids)
/// with the exact Cash/STC split each posting used.
class PettyCashCloseCalculator {
  const PettyCashCloseCalculator._();

  /// Parses a typed amount ("1200", "1,200.5", ".75") into minor units.
  /// Returns null for empty, negative, malformed or >2-decimal input.
  static int? parseMinor(String? text) {
    if (text == null) return null;
    final t = text.trim().replaceAll(',', '');
    if (t.isEmpty) return null;
    final match = RegExp(r'^(\d*)(?:\.(\d{0,2}))?$').firstMatch(t);
    if (match == null) return null;
    final whole = match.group(1) ?? '';
    final frac = match.group(2) ?? '';
    if (whole.isEmpty && frac.isEmpty) return null;
    final wholeVal = whole.isEmpty ? 0 : int.parse(whole);
    final fracVal = frac.isEmpty ? 0 : int.parse(frac.padRight(2, '0'));
    return wholeVal * 100 + fracVal;
  }

  /// Major units → minor units, for values already rounded to 2 decimals
  /// (policy thresholds, stored balances).
  static int toMinor(double major) => (major * 100).round();

  /// Formats minor units as "1234.50" (no grouping), for text fields.
  static String formatPlain(int minor) {
    final neg = minor < 0;
    final abs = minor.abs();
    final s = '${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
    return neg ? '-$s' : s;
  }

  /// When Cash and STC Pay are off in opposite directions, the most likely
  /// cause is money moved between them and not recorded. Returns the signed
  /// transfer that explains as much of it as possible:
  /// positive = Cash → STC Pay, negative = STC Pay → Cash, null = no pattern.
  static int? suggestedTransferCashToStc({
    required int cashDiffMinor,
    required int stcDiffMinor,
  }) {
    if (cashDiffMinor < 0 && stcDiffMinor > 0) {
      final m = -cashDiffMinor < stcDiffMinor ? -cashDiffMinor : stcDiffMinor;
      return m;
    }
    if (cashDiffMinor > 0 && stcDiffMinor < 0) {
      final m = cashDiffMinor < -stcDiffMinor ? cashDiffMinor : -stcDiffMinor;
      return -m;
    }
    return null;
  }

  /// Builds the closing: the optional Cash↔STC transfer, the per-bucket
  /// variance, the ledger lines to post and the account balances afterwards.
  ///
  /// Throws [StateError] for impossible input (negative counts, a transfer
  /// larger than the source bucket holds).
  static PettyCashClosePlan plan({
    required int accountTotalMinor,
    required int accountCashMinor,
    required int accountStcMinor,
    required int countedCashMinor,
    required int countedStcMinor,
    int transferCashToStcMinor = 0,
  }) {
    if (countedCashMinor < 0 || countedStcMinor < 0) {
      throw StateError('Counted amounts cannot be negative');
    }
    if (transferCashToStcMinor > 0 && transferCashToStcMinor > accountCashMinor) {
      throw StateError('Transfer is larger than the Cash balance');
    }
    if (transferCashToStcMinor < 0 && -transferCashToStcMinor > accountStcMinor) {
      throw StateError('Transfer is larger than the STC Pay balance');
    }

    final lines = <PettyCashLedgerLine>[];
    var running = accountTotalMinor;

    if (transferCashToStcMinor != 0) {
      final cashToStc = transferCashToStcMinor > 0;
      lines.add(PettyCashLedgerLine(
        kind: PettyCashLineKind.transfer,
        bucket: cashToStc ? FundBucket.cash : FundBucket.stcPay,
        toBucket: cashToStc ? FundBucket.stcPay : FundBucket.cash,
        amountMinor: transferCashToStcMinor.abs(),
        balanceBeforeMinor: running,
        balanceAfterMinor: running,
      ));
    }

    final expectedCash = accountCashMinor - transferCashToStcMinor;
    final expectedStc = accountStcMinor + transferCashToStcMinor;
    final cashVar = countedCashMinor - expectedCash;
    final stcVar = countedStcMinor - expectedStc;

    // Post money coming in before money going out, so the running total
    // never dips below the lower of the start and end balances.
    final variances = <(FundBucket, int)>[
      if (cashVar != 0) (FundBucket.cash, cashVar),
      if (stcVar != 0) (FundBucket.stcPay, stcVar),
    ]..sort((a, b) => b.$2.compareTo(a.$2));

    for (final (bucket, delta) in variances) {
      final before = running;
      running += delta;
      lines.add(PettyCashLedgerLine(
        kind: PettyCashLineKind.variance,
        bucket: bucket,
        amountMinor: delta.abs(),
        balanceBeforeMinor: before,
        balanceAfterMinor: running,
      ));
    }

    return PettyCashClosePlan(
      accountCashBeforeMinor: accountCashMinor,
      accountStcBeforeMinor: accountStcMinor,
      transferCashToStcMinor: transferCashToStcMinor,
      expectedCashMinor: expectedCash,
      expectedStcMinor: expectedStc,
      countedCashMinor: countedCashMinor,
      countedStcMinor: countedStcMinor,
      newTotalMinor: running,
      lines: List.unmodifiable(lines),
    );
  }

  /// What the closer must do before the register can close.
  static PettyCashCloseChecks checks({
    required int cashVarianceMinor,
    required int stcVarianceMinor,
    required int recountAboveMinor,
    required int adminCloseAboveMinor,
  }) {
    final total = cashVarianceMinor + stcVarianceMinor;
    final largestBucket = cashVarianceMinor.abs() > stcVarianceMinor.abs()
        ? cashVarianceMinor.abs()
        : stcVarianceMinor.abs();
    return PettyCashCloseChecks(
      needsReason: cashVarianceMinor != 0 || stcVarianceMinor != 0,
      needsRecount: largestBucket > recountAboveMinor,
      needsAdmin: adminCloseAboveMinor > 0 && total.abs() > adminCloseAboveMinor,
    );
  }

  /// Splits a shortage between salary recovery and write-off.
  /// Throws [StateError] when the split does not add up.
  static ({int recoveryMinor, int writeOffMinor}) splitShortage({
    required int shortageMinor,
    required int recoveryMinor,
  }) {
    if (shortageMinor <= 0) {
      throw StateError('There is no shortage to resolve');
    }
    if (recoveryMinor < 0 || recoveryMinor > shortageMinor) {
      throw StateError(
        'Salary recovery must be between 0 and the shortage '
        '(${formatPlain(shortageMinor)})',
      );
    }
    return (
      recoveryMinor: recoveryMinor,
      writeOffMinor: shortageMinor - recoveryMinor,
    );
  }
}

enum PettyCashLineKind { transfer, variance }

/// One ledger row the closing will post.
class PettyCashLedgerLine {
  final PettyCashLineKind kind;

  /// For a transfer: the source bucket. For a variance: the bucket corrected.
  final FundBucket bucket;

  /// For a transfer only: the destination bucket.
  final FundBucket? toBucket;

  /// Always positive.
  final int amountMinor;
  final int balanceBeforeMinor;
  final int balanceAfterMinor;

  const PettyCashLedgerLine({
    required this.kind,
    required this.bucket,
    this.toBucket,
    required this.amountMinor,
    required this.balanceBeforeMinor,
    required this.balanceAfterMinor,
  });

  bool get isCredit => balanceAfterMinor > balanceBeforeMinor;
}

class PettyCashClosePlan {
  final int accountCashBeforeMinor;
  final int accountStcBeforeMinor;

  /// Positive = Cash → STC Pay, negative = STC Pay → Cash.
  final int transferCashToStcMinor;

  /// Expected after the transfer.
  final int expectedCashMinor;
  final int expectedStcMinor;
  final int countedCashMinor;
  final int countedStcMinor;

  /// Account total after every line is posted.
  final int newTotalMinor;
  final List<PettyCashLedgerLine> lines;

  const PettyCashClosePlan({
    required this.accountCashBeforeMinor,
    required this.accountStcBeforeMinor,
    required this.transferCashToStcMinor,
    required this.expectedCashMinor,
    required this.expectedStcMinor,
    required this.countedCashMinor,
    required this.countedStcMinor,
    required this.newTotalMinor,
    required this.lines,
  });

  int get cashVarianceMinor => countedCashMinor - expectedCashMinor;
  int get stcVarianceMinor => countedStcMinor - expectedStcMinor;
  int get totalVarianceMinor => cashVarianceMinor + stcVarianceMinor;
  int get expectedTotalMinor => expectedCashMinor + expectedStcMinor;
  int get countedTotalMinor => countedCashMinor + countedStcMinor;
  bool get isBalanced => cashVarianceMinor == 0 && stcVarianceMinor == 0;

  /// The account's buckets after closing are exactly the counted amounts.
  int get newCashMinor => countedCashMinor;
  int get newStcMinor => countedStcMinor;
}

class PettyCashCloseChecks {
  /// Any Cash or STC Pay difference needs an explanation.
  final bool needsReason;

  /// A difference above the recount threshold needs a second count.
  final bool needsRecount;

  /// A total difference above the admin threshold can only be closed by
  /// someone allowed to verify sessions.
  final bool needsAdmin;

  const PettyCashCloseChecks({
    required this.needsReason,
    required this.needsRecount,
    required this.needsAdmin,
  });
}
