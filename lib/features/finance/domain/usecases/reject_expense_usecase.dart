import '../entities/expense_entity.dart';
import '../repositories/finance_repository.dart';

class RejectExpenseUseCase {
  final FinanceRepository repository;

  RejectExpenseUseCase(this.repository);

  Future<ExpenseEntity> call({
    required String expenseId,
    required String actorName,
    required String actorUserId,
    required String reason,
  }) {
    return repository.rejectExpense(
      expenseId: expenseId,
      actorName: actorName,
      actorUserId: actorUserId,
      reason: reason,
    );
  }
}
