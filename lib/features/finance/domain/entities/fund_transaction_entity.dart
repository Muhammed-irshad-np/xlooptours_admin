import 'package:equatable/equatable.dart';

enum FundTransactionType {
  deposit,
  withdrawal,
  transfer,
  adjustment,
  /// Expense payment posted to a fund.
  expensePayment,
  /// Reversal of a previous ledger line.
  reversal;

  String get displayName {
    switch (this) {
      case FundTransactionType.deposit:
        return 'Deposit';
      case FundTransactionType.withdrawal:
        return 'Withdrawal';
      case FundTransactionType.transfer:
        return 'Transfer';
      case FundTransactionType.adjustment:
        return 'Adjustment';
      case FundTransactionType.expensePayment:
        return 'Expense payment';
      case FundTransactionType.reversal:
        return 'Reversal';
    }
  }
}

/// Which balance bucket moved (for petty-cash style split wallets).
enum FundBucket {
  total,
  cash,
  stcPay;

  String get displayName {
    switch (this) {
      case FundBucket.total:
        return 'Total';
      case FundBucket.cash:
        return 'Cash';
      case FundBucket.stcPay:
        return 'STC Pay';
    }
  }
}

/// Append-only money movement. Balances on this row are computed server-side.
class FundTransactionEntity extends Equatable {
  final String id;

  /// Human-readable sequential ledger number, e.g. `TXN-10001`.
  /// Null only on rows written before numbering existed and not yet backfilled.
  final String? referenceNumber;
  final String fundAccountId;
  final FundTransactionType type;

  /// Always positive magnitude; direction comes from [type] / sign of effect.
  final double amount;
  final int? amountMinor;
  final String currency;
  final String description;

  final String? referenceExpenseId;
  final String? transferToAccountId;
  final String? transferPairId;
  final String? reversesTransactionId;

  final String performedBy;
  final String? performedByUserId;
  final DateTime date;
  final DateTime createdAt;

  /// Computed at write time inside a transaction — never trusted from UI.
  final double balanceBefore;
  final double balanceAfter;

  final FundBucket bucket;
  final bool isReversed;
  final String? auditNote;

  const FundTransactionEntity({
    required this.id,
    this.referenceNumber,
    required this.fundAccountId,
    required this.type,
    required this.amount,
    this.amountMinor,
    required this.currency,
    required this.description,
    this.referenceExpenseId,
    this.transferToAccountId,
    this.transferPairId,
    this.reversesTransactionId,
    required this.performedBy,
    this.performedByUserId,
    required this.date,
    required this.createdAt,
    required this.balanceBefore,
    required this.balanceAfter,
    this.bucket = FundBucket.total,
    this.isReversed = false,
    this.auditNote,
  });

  /// ID to show users: the sequential number, or a short form of the
  /// document id for rows that have not been numbered.
  String get displayReference => referenceNumber ?? shortReference(id);

  /// Short form of a ledger document id, e.g. `TX-3F9A2C1B`.
  static String shortReference(String id) =>
      'TX-${(id.length > 8 ? id.substring(0, 8) : id).toUpperCase()}';

  int get resolvedAmountMinor => amountMinor ?? (amount * 100).round();

  factory FundTransactionEntity.empty() {
    return FundTransactionEntity(
      id: '',
      fundAccountId: '',
      type: FundTransactionType.deposit,
      amount: 0,
      currency: 'SAR',
      description: '',
      performedBy: '',
      date: DateTime.now(),
      createdAt: DateTime.now(),
      balanceBefore: 0,
      balanceAfter: 0,
    );
  }

  @override
  List<Object?> get props => [
        id,
        referenceNumber,
        fundAccountId,
        type,
        amount,
        amountMinor,
        currency,
        description,
        referenceExpenseId,
        transferToAccountId,
        transferPairId,
        reversesTransactionId,
        performedBy,
        performedByUserId,
        date,
        createdAt,
        balanceBefore,
        balanceAfter,
        bucket,
        isReversed,
        auditNote,
      ];
}
