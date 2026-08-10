import '../repositories/finance_repository.dart';

/// Marks a closed petty cash session as verified by admin.
class VerifyPettyCashSessionUseCase {
  final FinanceRepository repository;

  VerifyPettyCashSessionUseCase(this.repository);

  Future<void> call(String sessionId, String verifiedBy) async {
    return await repository.verifyPettyCashSession(sessionId, verifiedBy);
  }
}
