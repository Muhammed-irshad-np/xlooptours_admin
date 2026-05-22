import '../entities/feedback_entity.dart';
import '../repositories/feedback_repository.dart';

class GetLatestFeedbacksUseCase {
  final FeedbackRepository repository;

  GetLatestFeedbacksUseCase(this.repository);

  Future<List<FeedbackEntity>> call({int limit = 5}) async {
    return await repository.getLatestFeedbacks(limit: limit);
  }
}
