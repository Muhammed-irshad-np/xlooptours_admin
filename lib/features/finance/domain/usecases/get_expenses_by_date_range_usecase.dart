import '../entities/expense_entity.dart';
import '../repositories/finance_repository.dart';

/// Fetches expenses within a specified date range.
class GetExpensesByDateRangeUseCase {
  final FinanceRepository repository;

  GetExpensesByDateRangeUseCase(this.repository);

  Future<List<ExpenseEntity>> call(DateTime start, DateTime end) async {
    return await repository.getExpensesByDateRange(start, end);
  }
}
