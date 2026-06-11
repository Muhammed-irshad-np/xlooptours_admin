import 'package:dartz/dartz.dart';
import 'package:xloop_invoice/core/error/failures.dart';
import 'package:xloop_invoice/features/driver_evaluation/domain/entities/evaluation_entity.dart';
import 'package:xloop_invoice/features/driver_evaluation/domain/repositories/evaluation_repository.dart';

class GetPendingEvaluationsUseCase {
  final EvaluationRepository repository;

  GetPendingEvaluationsUseCase(this.repository);

  Future<Either<Failure, List<EvaluationEntity>>> call() async {
    return await repository.getPendingEvaluations();
  }
}
