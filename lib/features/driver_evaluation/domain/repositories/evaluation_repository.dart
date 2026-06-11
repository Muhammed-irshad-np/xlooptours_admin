import 'package:dartz/dartz.dart';
import 'package:xloop_invoice/core/error/failures.dart';
import 'package:xloop_invoice/features/driver_evaluation/domain/entities/evaluation_entity.dart';

abstract class EvaluationRepository {
  Future<Either<Failure, String>> generateEvaluationLink(String driverId, String driverName, String? vehicleId);
  Future<Either<Failure, List<EvaluationEntity>>> getPendingEvaluations();
  Future<Either<Failure, void>> submitAdminScore(String evaluationId, Map<String, dynamic> scores);
  Future<Either<Failure, void>> submitDriverForm(String evaluationId, Map<String, dynamic> media);
  Future<Either<Failure, EvaluationEntity>> getEvaluationById(String evaluationId);
  Future<Either<Failure, void>> deleteEvaluation(String evaluationId);
}
