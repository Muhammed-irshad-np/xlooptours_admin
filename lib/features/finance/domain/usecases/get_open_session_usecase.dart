import '../entities/petty_cash_session_entity.dart';
import '../repositories/finance_repository.dart';

/// Checks if there is a currently open petty cash session for the given account.
class GetOpenSessionUseCase {
  final FinanceRepository repository;

  GetOpenSessionUseCase(this.repository);

  Future<PettyCashSessionEntity?> call(String accountId) async {
    return await repository.getOpenSession(accountId);
  }
}
