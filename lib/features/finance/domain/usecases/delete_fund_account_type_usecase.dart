import '../repositories/finance_repository.dart';

class DeleteFundAccountTypeUseCase {
  final FinanceRepository repository;

  const DeleteFundAccountTypeUseCase(this.repository);

  Future<void> call(String id) {
    return repository.deleteFundAccountType(id);
  }
}
