import '../repositories/finance_repository.dart';

/// Saves the order fund accounts are shown in, as a list of account ids.
class ReorderFundAccountsUseCase {
  final FinanceRepository repository;

  ReorderFundAccountsUseCase(this.repository);

  Future<void> call(List<String> orderedIds) =>
      repository.updateFundAccountOrder(orderedIds);
}
