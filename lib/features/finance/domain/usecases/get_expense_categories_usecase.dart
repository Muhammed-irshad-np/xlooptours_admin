import '../entities/expense_category_entity.dart';
import '../repositories/finance_repository.dart';

/// Fetches all expense categories with their types.
class GetExpenseCategoriesUseCase {
  final FinanceRepository repository;

  GetExpenseCategoriesUseCase(this.repository);

  Future<List<ExpenseCategoryEntity>> call() async {
    return await repository.getExpenseCategories();
  }
}
