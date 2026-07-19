import '../entities/expense_category_entity.dart';
import '../repositories/finance_repository.dart';

/// Updates an existing expense category.
class UpdateExpenseCategoryUseCase {
  final FinanceRepository repository;

  UpdateExpenseCategoryUseCase(this.repository);

  Future<void> call(ExpenseCategoryEntity category) async {
    return await repository.updateExpenseCategory(category);
  }
}
