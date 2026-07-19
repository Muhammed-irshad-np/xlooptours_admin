import '../entities/expense_category_entity.dart';
import '../repositories/finance_repository.dart';

/// Creates a new expense category.
class InsertExpenseCategoryUseCase {
  final FinanceRepository repository;

  InsertExpenseCategoryUseCase(this.repository);

  Future<void> call(ExpenseCategoryEntity category) async {
    return await repository.insertExpenseCategory(category);
  }
}
