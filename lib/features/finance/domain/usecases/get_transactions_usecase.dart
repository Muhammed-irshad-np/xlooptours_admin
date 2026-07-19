import '../entities/fund_transaction_entity.dart';
import '../repositories/finance_repository.dart';

/// Fetches all transactions for a specific fund account.
class GetTransactionsUseCase {
  final FinanceRepository repository;

  GetTransactionsUseCase(this.repository);

  Future<List<FundTransactionEntity>> call(String accountId) async {
    return await repository.getTransactionsForAccount(accountId);
  }
}
