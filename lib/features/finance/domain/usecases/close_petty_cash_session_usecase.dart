import '../entities/petty_cash_session_entity.dart';
import '../repositories/finance_repository.dart';

class ClosePettyCashSessionUseCase {
  final FinanceRepository repository;

  ClosePettyCashSessionUseCase(this.repository);

  Future<PettyCashSessionEntity> call({
    required PettyCashSessionEntity session,
    required String closedBy,
    required String? closedByUserId,
  }) {
    return repository.closePettyCashSession(
      session: session,
      closedBy: closedBy,
      closedByUserId: closedByUserId,
    );
  }
}
