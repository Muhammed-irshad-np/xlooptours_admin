import '../entities/petty_cash_session_entity.dart';
import '../repositories/finance_repository.dart';

/// Opens a new daily petty cash session.
class OpenPettyCashSessionUseCase {
  final FinanceRepository repository;

  OpenPettyCashSessionUseCase(this.repository);

  Future<void> call(PettyCashSessionEntity session) async {
    return await repository.openPettyCashSession(session);
  }
}
