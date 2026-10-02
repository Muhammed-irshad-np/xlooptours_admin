import '../entities/fund_transaction_entity.dart';
import '../repositories/finance_repository.dart';

/// Fetches a specific fund transaction by its unique ID (ledger entry ID).
class GetTransactionByIdUseCase {
  final FinanceRepository repository;

  GetTransactionByIdUseCase(this.repository);

  Future<FundTransactionEntity?> call(String id) async {
    return await repository.getTransactionById(id);
  }
}
