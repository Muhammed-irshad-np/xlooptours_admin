import '../entities/fund_account_type_entity.dart';
import '../repositories/finance_repository.dart';

class GetFundAccountTypesUseCase {
  final FinanceRepository repository;

  const GetFundAccountTypesUseCase(this.repository);

  Future<List<FundAccountTypeEntity>> call() {
    return repository.getFundAccountTypes();
  }
}
