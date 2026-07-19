import '../entities/fund_transaction_entity.dart';
import '../repositories/finance_repository.dart';

/// Records a new fund transaction (deposit, withdrawal, transfer, or adjustment).
/// Also atomically updates the fund account balance.
class InsertTransactionUseCase {
  final FinanceRepository repository;

  InsertTransactionUseCase(this.repository);

  Future<void> call(FundTransactionEntity transaction) async {
    return await repository.insertTransaction(transaction);
  }
}
