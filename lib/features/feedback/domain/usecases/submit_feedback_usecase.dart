import '../entities/feedback_entity.dart';
import '../repositories/feedback_repository.dart';

class SubmitFeedbackUseCase {
  final FeedbackRepository repository;

  SubmitFeedbackUseCase(this.repository);

  Future<void> call(FeedbackEntity feedback) async {
    return await repository.submitFeedback(feedback);
  }
}
