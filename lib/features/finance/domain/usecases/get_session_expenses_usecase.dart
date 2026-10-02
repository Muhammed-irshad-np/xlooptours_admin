import '../entities/petty_cash_session_entity.dart';
import '../entities/session_expense_item.dart';
import '../repositories/finance_repository.dart';

/// Fetches all expense records and ledger outflows for a given petty cash session.
class GetSessionExpensesUseCase {
  final FinanceRepository repository;

  GetSessionExpensesUseCase(this.repository);

  Future<List<SessionExpenseItem>> call(PettyCashSessionEntity session) async {
    return await repository.getSessionExpenses(session);
  }
}
