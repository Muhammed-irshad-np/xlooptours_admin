import '../entities/fund_transaction_entity.dart';
import '../entities/post_fund_request.dart';
import '../repositories/finance_repository.dart';

class PostFundMovementUseCase {
  final FinanceRepository repository;

  PostFundMovementUseCase(this.repository);

  Future<FundTransactionEntity> call(PostFundRequest request) {
    return repository.postFundMovement(request);
  }
}
