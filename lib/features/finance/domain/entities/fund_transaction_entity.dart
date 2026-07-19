import 'package:equatable/equatable.dart';

/// The type of fund transaction (money movement).
enum FundTransactionType {
  deposit,
  withdrawal,
  transfer,
  adjustment;

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
    }
  }
}

/// Represents a single money movement in/out of a fund account.
///
/// Every deposit, withdrawal, expense payment, or inter-account transfer
/// creates a transaction record for full audit trail.
class FundTransactionEntity extends Equatable {
  final String id;
  final String fundAccountId;
  final FundTransactionType type;
  final double amount;
  final String currency;
  final String description;

  /// If this transaction was triggered by an expense.
  final String? referenceExpenseId;

  /// If this is a transfer, the destination account.
  final String? transferToAccountId;

  final String performedBy;
  final DateTime date;
  final DateTime createdAt;
  final double balanceBefore;
  final double balanceAfter;

  const FundTransactionEntity({
    required this.id,
    required this.fundAccountId,
    required this.type,
    required this.amount,
    required this.currency,
    required this.description,
    this.referenceExpenseId,
    this.transferToAccountId,
    required this.performedBy,
    required this.date,
    required this.createdAt,
    required this.balanceBefore,
    required this.balanceAfter,
  });

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
        fundAccountId,
        type,
        amount,
        currency,
        description,
        referenceExpenseId,
        transferToAccountId,
        performedBy,
        date,
        createdAt,
        balanceBefore,
        balanceAfter,
      ];
}
