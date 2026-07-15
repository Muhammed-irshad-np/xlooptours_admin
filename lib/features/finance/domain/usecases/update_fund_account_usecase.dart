import '../entities/fund_account_entity.dart';
import '../repositories/finance_repository.dart';

/// Updates an existing fund account.
class UpdateFundAccountUseCase {
  final FinanceRepository repository;

  UpdateFundAccountUseCase(this.repository);

  Future<void> call(FundAccountEntity account) async {
    return await repository.updateFundAccount(account);
  }
}
