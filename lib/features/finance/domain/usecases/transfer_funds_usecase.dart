import '../entities/fund_transaction_entity.dart';
import '../repositories/finance_repository.dart';

class TransferFundsUseCase {
  final FinanceRepository repository;

  TransferFundsUseCase(this.repository);

  Future<void> call({
    required String fromAccountId,
    required String toAccountId,
    required double amountMajor,
    required String currency,
    required String description,
    required String performedBy,
    required String performedByUserId,
    FundBucket fromBucket = FundBucket.total,
    FundBucket toBucket = FundBucket.total,
  }) {
    return repository.transferBetweenAccounts(
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      amountMajor: amountMajor,
      currency: currency,
      description: description,
      performedBy: performedBy,
      performedByUserId: performedByUserId,
      fromBucket: fromBucket,
      toBucket: toBucket,
    );
  }
}
