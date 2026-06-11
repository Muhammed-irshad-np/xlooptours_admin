import 'package:dartz/dartz.dart';
import 'package:xloop_invoice/core/error/failures.dart';
import 'package:xloop_invoice/features/driver_evaluation/domain/repositories/evaluation_repository.dart';

class SubmitDriverFormUseCase {
  final EvaluationRepository repository;

  SubmitDriverFormUseCase(this.repository);

  Future<Either<Failure, void>> call(String evaluationId, Map<String, dynamic> media) async {
    return await repository.submitDriverForm(evaluationId, media);
  }
}
