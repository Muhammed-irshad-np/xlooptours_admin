import '../entities/expense_entity.dart';
import '../repositories/finance_repository.dart';

/// Fetches expenses for a specific fund account.
class GetExpensesByAccountUseCase {
  final FinanceRepository repository;

  GetExpensesByAccountUseCase(this.repository);

  Future<List<ExpenseEntity>> call(String fundAccountId) async {
    return await repository.getExpensesByAccount(fundAccountId);
  }
}
