import '../repositories/finance_repository.dart';

/// Deletes an expense category by its ID.
class DeleteExpenseCategoryUseCase {
  final FinanceRepository repository;

  DeleteExpenseCategoryUseCase(this.repository);

  Future<void> call(String id) async {
    return await repository.deleteExpenseCategory(id);
  }
}
