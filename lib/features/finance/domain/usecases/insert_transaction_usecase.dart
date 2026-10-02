import '../entities/fund_transaction_entity.dart';
import '../entities/post_fund_request.dart';
import '../repositories/finance_repository.dart';

/// Posts a deposit/withdrawal with server-side balance computation.
/// Prefer [PostFundMovementUseCase] for new code.
class InsertTransactionUseCase {
  final FinanceRepository repository;

  InsertTransactionUseCase(this.repository);

  Future<FundTransactionEntity> call({
    required String fundAccountId,
    required FundTransactionType type,
    required double amountMajor,
    required String currency,
    required String description,
    required String performedBy,
    required String performedByUserId,
    FundBucket bucket = FundBucket.total,
    double? cashDelta,
    double? stcPayDelta,
  }) {
    final isCredit = type == FundTransactionType.deposit ||
        type == FundTransactionType.reversal;
    return repository.postFundMovement(
      PostFundRequest(
        fundAccountId: fundAccountId,
        type: type,
        amountMajor: amountMajor,
        currency: currency,
        description: description,
        performedBy: performedBy,
        performedByUserId: performedByUserId,
        bucket: bucket,
        credit: isCredit,
        cashDeltaMajor: cashDelta,
        stcPayDeltaMajor: stcPayDelta,
      ),
    );
  }
}
