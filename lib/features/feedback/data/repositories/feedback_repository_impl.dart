import '../../domain/entities/feedback_entity.dart';
import '../../domain/repositories/feedback_repository.dart';
import '../datasources/feedback_remote_data_source.dart';
import '../models/feedback_model.dart';

class FeedbackRepositoryImpl implements FeedbackRepository {
  final FeedbackRemoteDataSource remoteDataSource;

  FeedbackRepositoryImpl({required this.remoteDataSource});

  @override
  Future<void> submitFeedback(FeedbackEntity feedback) async {
    try {
      final model = FeedbackModel.fromEntity(feedback);
      await remoteDataSource.submitFeedback(model);
    } catch (e) {
      throw Exception('Error submitting feedback: $e');
    }
  }

  @override
  Future<List<FeedbackEntity>> getLatestFeedbacks({int limit = 5}) async {
    try {
      return await remoteDataSource.getLatestFeedbacks(limit: limit);
    } catch (e) {
      throw Exception('Error fetching latest feedbacks: $e');
    }
  }
}
