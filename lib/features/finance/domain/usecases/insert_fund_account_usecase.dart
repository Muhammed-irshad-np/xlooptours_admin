import '../entities/fund_account_entity.dart';
import '../repositories/finance_repository.dart';

/// Creates a new virtual fund account.
class InsertFundAccountUseCase {
  final FinanceRepository repository;

  InsertFundAccountUseCase(this.repository);

  Future<void> call(FundAccountEntity account) async {
    return await repository.insertFundAccount(account);
  }
}
