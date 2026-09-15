import '../entities/fund_transaction_entity.dart';
import '../repositories/finance_repository.dart';

/// Transfers money between Cash and STC Pay buckets within the same
/// fund account. The total account balance remains unchanged — only
/// the cash/STC split is rebalanced.
///
/// Typical use: coordinator moves physical cash into STC Pay (or vice
/// versa) at end-of-day before closing the petty cash register.
class TransferBucketUseCase {
  final FinanceRepository repository;

  TransferBucketUseCase(this.repository);

  Future<void> call({
    required String fundAccountId,
    required double amountMajor,
    required FundBucket fromBucket,
    required FundBucket toBucket,
    required String performedBy,
    required String? performedByUserId,
  }) {
    return repository.transferBucket(
      fundAccountId: fundAccountId,
      amountMajor: amountMajor,
      fromBucket: fromBucket,
      toBucket: toBucket,
      performedBy: performedBy,
      performedByUserId: performedByUserId,
    );
  }
}
