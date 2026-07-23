import '../repositories/finance_repository.dart';

class VerifyPettyCashSessionUseCase {
  final FinanceRepository repository;

  VerifyPettyCashSessionUseCase(this.repository);

  Future<void> call({
    required String sessionId,
    required String verifiedBy,
    required String? verifiedByUserId,
  }) {
    return repository.verifyPettyCashSession(
      sessionId: sessionId,
      verifiedBy: verifiedBy,
      verifiedByUserId: verifiedByUserId,
    );
  }
}
