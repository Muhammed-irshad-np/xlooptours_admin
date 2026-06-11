import 'package:dartz/dartz.dart';
import 'package:xloop_invoice/core/error/failures.dart';
import 'package:xloop_invoice/features/driver_evaluation/domain/entities/evaluation_entity.dart';
import 'package:xloop_invoice/features/driver_evaluation/domain/repositories/evaluation_repository.dart';

class GetEvaluationByIdUseCase {
  final EvaluationRepository repository;

  GetEvaluationByIdUseCase(this.repository);

  Future<Either<Failure, EvaluationEntity>> call(String evaluationId) async {
    return await repository.getEvaluationById(evaluationId);
  }
}
