import '../entities/fund_account_type_entity.dart';
import '../repositories/finance_repository.dart';

class InsertFundAccountTypeUseCase {
  final FinanceRepository repository;

  const InsertFundAccountTypeUseCase(this.repository);

  Future<void> call(FundAccountTypeEntity type) {
    return repository.insertFundAccountType(type);
  }
}
