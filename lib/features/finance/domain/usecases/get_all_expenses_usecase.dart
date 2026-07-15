import '../entities/expense_entity.dart';
import '../repositories/finance_repository.dart';

/// Fetches all expenses ordered by date (newest first).
class GetAllExpensesUseCase {
  final FinanceRepository repository;

  GetAllExpensesUseCase(this.repository);

  Future<List<ExpenseEntity>> call() async {
    return await repository.getAllExpenses();
  }
}
