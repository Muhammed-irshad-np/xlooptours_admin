import '../entities/expense_entity.dart';
import '../repositories/finance_repository.dart';

/// Creates a new expense record.
class InsertExpenseUseCase {
  final FinanceRepository repository;

  InsertExpenseUseCase(this.repository);

  Future<void> call(ExpenseEntity expense) async {
    return await repository.insertExpense(expense);
  }
}
