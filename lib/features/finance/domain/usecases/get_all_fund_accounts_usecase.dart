import '../entities/fund_account_entity.dart';
import '../repositories/finance_repository.dart';

/// Fetches all virtual fund accounts.
class GetAllFundAccountsUseCase {
  final FinanceRepository repository;

  GetAllFundAccountsUseCase(this.repository);

  Future<List<FundAccountEntity>> call() async {
    return await repository.getAllFundAccounts();
  }
}
