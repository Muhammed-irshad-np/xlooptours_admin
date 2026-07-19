import '../repositories/finance_repository.dart';

/// Deletes an expense by its ID.
class DeleteExpenseUseCase {
  final FinanceRepository repository;

  DeleteExpenseUseCase(this.repository);

  Future<void> call(String id) async {
    return await repository.deleteExpense(id);
  }
}
