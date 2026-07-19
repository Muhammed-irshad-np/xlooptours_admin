import '../entities/expense_entity.dart';
import '../repositories/finance_repository.dart';

/// Rejects a pending expense with a reason.
class RejectExpenseUseCase {
  final FinanceRepository repository;

  RejectExpenseUseCase(this.repository);

  Future<void> call(
    ExpenseEntity expense,
    String rejectedBy,
    String reason,
  ) async {
    final rejected = expense.copyWith(
      status: ExpenseStatus.rejected,
      approvedBy: rejectedBy,
      approvedAt: DateTime.now(),
      rejectionReason: reason,
      updatedAt: DateTime.now(),
    );
    return await repository.updateExpense(rejected);
  }
}
