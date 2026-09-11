import 'package:equatable/equatable.dart';
import 'expense_entity.dart';
import 'fund_transaction_entity.dart';

/// Represents a single expense record or ledger outflow that occurred
/// during a specific daily petty cash session.
class SessionExpenseItem extends Equatable {
  final String id;
  final String? transactionId;
  final String? expenseId;
  final String referenceNumber;
  final String title;
  final String category;
  final String expenseType;
  final double amount;
  final FundBucket bucket;
  final DateTime date;
  final String performedBy;
  final String? notes;
  final List<String> receiptUrls;
  final String status;
  final String? vehicleName;
  final String? employeeName;
  final ExpenseEntity? originalExpense;
  final FundTransactionEntity? originalTransaction;

  const SessionExpenseItem({
    required this.id,
    this.transactionId,
    this.expenseId,
    required this.referenceNumber,
    required this.title,
    required this.category,
    required this.expenseType,
    required this.amount,
    required this.bucket,
    required this.date,
    required this.performedBy,
    this.notes,
    this.receiptUrls = const [],
    this.status = 'Paid',
    this.vehicleName,
    this.employeeName,
    this.originalExpense,
    this.originalTransaction,
  });

  @override
  List<Object?> get props => [
        id,
        transactionId,
        expenseId,
        referenceNumber,
        title,
        category,
        expenseType,
        amount,
        bucket,
        date,
        performedBy,
        notes,
        receiptUrls,
        status,
        vehicleName,
        employeeName,
      ];
}
