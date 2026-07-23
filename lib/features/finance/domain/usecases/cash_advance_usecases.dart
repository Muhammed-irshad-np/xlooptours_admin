import '../entities/cash_advance_entity.dart';
import '../repositories/finance_repository.dart';

class GetCashAdvancesUseCase {
  final FinanceRepository repository;
  GetCashAdvancesUseCase(this.repository);
  Future<List<CashAdvanceEntity>> call({String? fundAccountId}) =>
      repository.getCashAdvances(fundAccountId: fundAccountId);
}

class IssueCashAdvanceUseCase {
  final FinanceRepository repository;
  IssueCashAdvanceUseCase(this.repository);
  Future<CashAdvanceEntity> call(CashAdvanceEntity advance) =>
      repository.issueCashAdvance(advance);
}

class SettleCashAdvanceUseCase {
  final FinanceRepository repository;
  SettleCashAdvanceUseCase(this.repository);
  Future<CashAdvanceEntity> call({
    required String advanceId,
    required double settleAmountMajor,
    required String actorName,
    required String actorUserId,
    required bool returnToFund,
  }) =>
      repository.settleCashAdvance(
        advanceId: advanceId,
        settleAmountMajor: settleAmountMajor,
        actorName: actorName,
        actorUserId: actorUserId,
        returnToFund: returnToFund,
      );
}

class WriteOffCashAdvanceUseCase {
  final FinanceRepository repository;
  WriteOffCashAdvanceUseCase(this.repository);
  Future<CashAdvanceEntity> call({
    required String advanceId,
    required String reason,
    required String actorName,
    required String actorUserId,
  }) =>
      repository.writeOffCashAdvance(
        advanceId: advanceId,
        reason: reason,
        actorName: actorName,
        actorUserId: actorUserId,
      );
}
