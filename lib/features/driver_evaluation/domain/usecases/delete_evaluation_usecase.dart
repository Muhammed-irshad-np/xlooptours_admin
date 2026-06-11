import 'package:dartz/dartz.dart';
import 'package:xloop_invoice/core/error/failures.dart';
import 'package:xloop_invoice/features/driver_evaluation/domain/repositories/evaluation_repository.dart';

class DeleteEvaluationUseCase {
  final EvaluationRepository repository;

  DeleteEvaluationUseCase(this.repository);

  Future<Either<Failure, void>> call(String evaluationId) async {
    return await repository.deleteEvaluation(evaluationId);
  }
}
