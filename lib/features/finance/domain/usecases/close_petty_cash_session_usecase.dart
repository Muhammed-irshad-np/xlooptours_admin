import '../entities/petty_cash_close_request.dart';
import '../entities/petty_cash_session_entity.dart';
import '../repositories/finance_repository.dart';

class ClosePettyCashSessionUseCase {
  final FinanceRepository repository;

  ClosePettyCashSessionUseCase(this.repository);

  Future<PettyCashSessionEntity> call(PettyCashCloseRequest request) {
    return repository.closePettyCashSession(request);
  }
}
