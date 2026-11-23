/// What the closer submits when closing a petty cash register.
/// All amounts are in minor units (halalas).
class PettyCashCloseRequest {
  final String sessionId;
  final int countedCashMinor;
  final int countedStcMinor;

  /// The account's Cash/STC balances the closer was comparing against.
  /// If the account moved since (someone posted an expense meanwhile),
  /// the close is refused so the closer reviews the new figures.
  final int seenAccountCashMinor;
  final int seenAccountStcMinor;

  /// Money moved between the buckets and not yet recorded.
  /// Positive = Cash → STC Pay, negative = STC Pay → Cash, 0 = none.
  final int transferCashToStcMinor;

  final String? notes;

  /// How many times the closer recounted (0 = counted once).
  final int recountCount;

  /// The first count, kept when a recount happened.
  final int? firstCountCashMinor;
  final int? firstCountStcMinor;

  final String closedBy;
  final String? closedByUserId;

  /// Whether the closer may close above the admin threshold
  /// (has the verify-session permission).
  final bool closerCanApproveLargeVariance;

  const PettyCashCloseRequest({
    required this.sessionId,
    required this.countedCashMinor,
    required this.countedStcMinor,
    required this.seenAccountCashMinor,
    required this.seenAccountStcMinor,
    this.transferCashToStcMinor = 0,
    this.notes,
    this.recountCount = 0,
    this.firstCountCashMinor,
    this.firstCountStcMinor,
    required this.closedBy,
    this.closedByUserId,
    this.closerCanApproveLargeVariance = false,
  });
}

/// How the verifier settles the difference of a session whose variance was
/// already posted to the account at closing.
class PettyCashResolution {
  /// Part of a shortage recovered from an employee's salary (minor units).
  final int salaryRecoveryMinor;
  final String? employeeId;
  final String? employeeName;

  /// Why the rest of a shortage is written off, or why an overage is
  /// accepted. Required whenever there is a written-off part or an overage.
  final String? reason;

  const PettyCashResolution({
    this.salaryRecoveryMinor = 0,
    this.employeeId,
    this.employeeName,
    this.reason,
  });
}

/// Thrown when the account balances changed while the closer was counting.
class PettyCashBalancesChangedError extends StateError {
  final int accountCashMinor;
  final int accountStcMinor;

  PettyCashBalancesChangedError({
    required this.accountCashMinor,
    required this.accountStcMinor,
  }) : super(
          'The account balance changed while you were counting (a payment '
          'or deposit was just posted). The expected amounts have been '
          'updated - please check them and close again.',
        );
}
