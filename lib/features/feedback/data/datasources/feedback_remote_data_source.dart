import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/feedback_model.dart';

abstract class FeedbackRemoteDataSource {
  Future<void> submitFeedback(FeedbackModel feedback);
  Future<List<FeedbackModel>> getLatestFeedbacks({int limit = 5});
}

class FeedbackRemoteDataSourceImpl implements FeedbackRemoteDataSource {
  final FirebaseFirestore firestore;

  FeedbackRemoteDataSourceImpl({required this.firestore});

  @override
  Future<void> submitFeedback(FeedbackModel feedback) async {
    try {
      await firestore
          .collection('feedbacks')
          .doc(feedback.id)
          .set(feedback.toJson());
    } catch (e) {
      throw Exception('Failed to submit feedback: $e');
    }
  }

  @override
  Future<List<FeedbackModel>> getLatestFeedbacks({int limit = 5}) async {
    try {
      final snapshot = await firestore
          .collection('feedbacks')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => FeedbackModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch latest feedbacks: $e');
    }
  }
}
