import '../entities/fund_transaction_entity.dart';
import '../repositories/finance_repository.dart';

/// Fetches every ledger row across all fund accounts (used by reports).
class GetAllTransactionsUseCase {
  final FinanceRepository repository;

  GetAllTransactionsUseCase(this.repository);

  Future<List<FundTransactionEntity>> call() => repository.getAllTransactions();
}
