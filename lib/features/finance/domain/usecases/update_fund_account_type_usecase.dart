import '../entities/fund_account_type_entity.dart';
import '../repositories/finance_repository.dart';

class UpdateFundAccountTypeUseCase {
  final FinanceRepository repository;

  const UpdateFundAccountTypeUseCase(this.repository);

  Future<void> call(FundAccountTypeEntity type) {
    return repository.updateFundAccountType(type);
  }
}
