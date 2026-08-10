import '../entities/expense_entity.dart';
import '../repositories/finance_repository.dart';

/// Approves a pending expense, updating its status and recording who approved it.
class ApproveExpenseUseCase {
  final FinanceRepository repository;

  ApproveExpenseUseCase(this.repository);

  Future<void> call(ExpenseEntity expense, String approvedBy) async {
    final approved = expense.copyWith(
      status: ExpenseStatus.approved,
      approvedBy: approvedBy,
      approvedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return await repository.updateExpense(approved);
  }
}
