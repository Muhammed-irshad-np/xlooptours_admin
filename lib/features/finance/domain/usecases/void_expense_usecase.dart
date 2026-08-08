import '../entities/expense_entity.dart';
import '../repositories/finance_repository.dart';

/// Voids a paid expense and reverses the fund posting.
class VoidExpenseUseCase {
  final FinanceRepository repository;

  VoidExpenseUseCase(this.repository);

  Future<ExpenseEntity> call({
    required String expenseId,
    required String actorName,
    required String actorUserId,
    required String reason,
  }) {
    return repository.voidPaidExpense(
      expenseId: expenseId,
      actorName: actorName,
      actorUserId: actorUserId,
      reason: reason,
    );
  }
}
