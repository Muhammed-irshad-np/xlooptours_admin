import 'package:flutter/material.dart';
import '../../domain/entities/feedback_entity.dart';
import '../../domain/usecases/submit_feedback_usecase.dart';
import '../../domain/usecases/get_latest_feedbacks_usecase.dart';

class FeedbackProvider extends ChangeNotifier {
  final SubmitFeedbackUseCase submitFeedbackUseCase;
  final GetLatestFeedbacksUseCase getLatestFeedbacksUseCase;

  FeedbackProvider({
    required this.submitFeedbackUseCase,
    required this.getLatestFeedbacksUseCase,
  });

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isSuccess = false;
  bool get isSuccess => _isSuccess;

  List<FeedbackEntity> _latestFeedbacks = [];
  List<FeedbackEntity> get latestFeedbacks => _latestFeedbacks;

  bool _isLoadingFeedbacks = false;
  bool get isLoadingFeedbacks => _isLoadingFeedbacks;

  Future<void> submitFeedback(FeedbackEntity feedback) async {
    _isLoading = true;
    _errorMessage = null;
    _isSuccess = false;
    notifyListeners();

    try {
      await submitFeedbackUseCase(feedback);
      _isSuccess = true;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchLatestFeedbacks({int limit = 5}) async {
    _isLoadingFeedbacks = true;
    notifyListeners();

    try {
      _latestFeedbacks = await getLatestFeedbacksUseCase(limit: limit);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoadingFeedbacks = false;
      notifyListeners();
    }
  }

  void resetState() {
    _isLoading = false;
    _errorMessage = null;
    _isSuccess = false;
    notifyListeners();
  }
}
