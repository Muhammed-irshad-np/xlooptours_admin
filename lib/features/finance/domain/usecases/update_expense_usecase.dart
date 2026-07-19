import '../entities/expense_entity.dart';
import '../repositories/finance_repository.dart';

/// Updates an existing expense record.
class UpdateExpenseUseCase {
  final FinanceRepository repository;

  UpdateExpenseUseCase(this.repository);

  Future<void> call(ExpenseEntity expense) async {
    return await repository.updateExpense(expense);
  }
}
