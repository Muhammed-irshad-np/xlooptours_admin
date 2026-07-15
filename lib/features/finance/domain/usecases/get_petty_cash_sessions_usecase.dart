import '../entities/petty_cash_session_entity.dart';
import '../repositories/finance_repository.dart';

/// Fetches all petty cash sessions for a specific fund account.
class GetPettyCashSessionsUseCase {
  final FinanceRepository repository;

  GetPettyCashSessionsUseCase(this.repository);

  Future<List<PettyCashSessionEntity>> call(String accountId) async {
    return await repository.getPettyCashSessions(accountId);
  }
}
