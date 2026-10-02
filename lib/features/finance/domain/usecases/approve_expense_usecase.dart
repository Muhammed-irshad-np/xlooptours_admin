import '../entities/expense_entity.dart';
import '../repositories/finance_repository.dart';

class ApproveExpenseUseCase {
  final FinanceRepository repository;

  ApproveExpenseUseCase(this.repository);

  Future<ExpenseEntity> call({
    required String expenseId,
    required String actorName,
    required String actorUserId,
    required String actorRole,
    bool allowSelfApprove = false,
  }) {
    return repository.approveAndPostExpense(
      expenseId: expenseId,
      actorName: actorName,
      actorUserId: actorUserId,
      actorRole: actorRole,
      allowSelfApprove: allowSelfApprove,
    );
  }
}
