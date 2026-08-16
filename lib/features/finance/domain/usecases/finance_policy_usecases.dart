import '../entities/finance_policy_entity.dart';
import '../repositories/finance_repository.dart';

class GetFinancePolicyUseCase {
  final FinanceRepository repository;
  GetFinancePolicyUseCase(this.repository);
  Future<FinancePolicyEntity> call() => repository.getFinancePolicy();
}

class SaveFinancePolicyUseCase {
  final FinanceRepository repository;
  SaveFinancePolicyUseCase(this.repository);
  Future<void> call(FinancePolicyEntity policy) =>
      repository.saveFinancePolicy(policy);
}

class GetLedgerDayTotalsUseCase {
  final FinanceRepository repository;
  GetLedgerDayTotalsUseCase(this.repository);
  Future call(String accountId, DateTime day) =>
      repository.getLedgerDayTotals(accountId, day);
}
