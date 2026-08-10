import '../entities/petty_cash_session_entity.dart';
import '../repositories/finance_repository.dart';

/// Closes an open petty cash session with the reported balances.
class ClosePettyCashSessionUseCase {
  final FinanceRepository repository;

  ClosePettyCashSessionUseCase(this.repository);

  Future<void> call(PettyCashSessionEntity session) async {
    return await repository.closePettyCashSession(session);
  }
}
