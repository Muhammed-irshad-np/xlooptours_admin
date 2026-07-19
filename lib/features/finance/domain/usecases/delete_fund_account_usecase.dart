import '../repositories/finance_repository.dart';

/// Deletes a fund account by its ID.
class DeleteFundAccountUseCase {
  final FinanceRepository repository;

  DeleteFundAccountUseCase(this.repository);

  Future<void> call(String id) async {
    return await repository.deleteFundAccount(id);
  }
}
