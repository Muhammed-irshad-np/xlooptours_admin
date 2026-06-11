import 'package:flutter/material.dart';
import 'package:xloop_invoice/features/driver_evaluation/domain/entities/evaluation_entity.dart';
import 'package:xloop_invoice/features/driver_evaluation/domain/usecases/generate_evaluation_link_usecase.dart';
import 'package:xloop_invoice/features/driver_evaluation/domain/usecases/get_pending_evaluations_usecase.dart';
import 'package:xloop_invoice/features/driver_evaluation/domain/usecases/submit_admin_score_usecase.dart';
import 'package:xloop_invoice/features/driver_evaluation/domain/usecases/delete_evaluation_usecase.dart';

class AdminEvaluationProvider extends ChangeNotifier {
  final GenerateEvaluationLinkUseCase generateLinkUseCase;
  final GetPendingEvaluationsUseCase getPendingEvaluationsUseCase;
  final SubmitAdminScoreUseCase submitAdminScoreUseCase;
  final DeleteEvaluationUseCase deleteEvaluationUseCase;

  AdminEvaluationProvider({
    required this.generateLinkUseCase,
    required this.getPendingEvaluationsUseCase,
    required this.submitAdminScoreUseCase,
    required this.deleteEvaluationUseCase,
  });

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<EvaluationEntity> _pendingEvaluations = [];
  List<EvaluationEntity> get pendingEvaluations => _pendingEvaluations;

  List<EvaluationEntity> _evaluatedEvaluations = [];
  List<EvaluationEntity> get evaluatedEvaluations => _evaluatedEvaluations;

  Future<String?> generateLink(String driverId, String driverName, String? vehicleId) async {
    _setLoading(true);
    final result = await generateLinkUseCase(driverId, driverName, vehicleId);
    _setLoading(false);

    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        notifyListeners();
        return null;
      },
      (id) {
        return id;
      },
    );
  }

  Future<void> loadPendingEvaluations() async {
    _setLoading(true);
    final result = await getPendingEvaluationsUseCase();
    _setLoading(false);

    result.fold(
      (failure) {
        _errorMessage = failure.message;
        notifyListeners();
      },
      (evaluations) {
        _pendingEvaluations = evaluations.where((e) => e.status == 'pending').toList();
        _evaluatedEvaluations = evaluations.where((e) => e.status == 'evaluated').toList();
        _errorMessage = null;
        notifyListeners();
      },
    );
  }

  Future<bool> submitScore(String evaluationId, Map<String, dynamic> scores) async {
    _setLoading(true);
    final result = await submitAdminScoreUseCase(evaluationId, scores);
    _setLoading(false);

    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (_) {
        _errorMessage = null;
        loadPendingEvaluations();
        return true;
      },
    );
  }

  Future<bool> deleteEvaluation(String evaluationId) async {
    _setLoading(true);
    final result = await deleteEvaluationUseCase(evaluationId);
    _setLoading(false);

    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (_) {
        _errorMessage = null;
        _pendingEvaluations.removeWhere((e) => e.id == evaluationId);
        _evaluatedEvaluations.removeWhere((e) => e.id == evaluationId);
        notifyListeners();
        return true;
      },
    );
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}