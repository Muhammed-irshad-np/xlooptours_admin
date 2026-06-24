import 'package:dartz/dartz.dart';
import 'package:xloop_invoice/core/error/failures.dart';
import 'package:xloop_invoice/features/driver_evaluation/domain/repositories/evaluation_repository.dart';

class SubmitAdminScoreUseCase {
  final EvaluationRepository repository;

  SubmitAdminScoreUseCase(this.repository);

  Future<Either<Failure, void>> call(String evaluationId, Map<String, dynamic> scores) async {
    return await repository.submitAdminScore(evaluationId, scores);
  }
}
