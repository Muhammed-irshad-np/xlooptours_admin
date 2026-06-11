import 'package:dartz/dartz.dart';
import 'package:xloop_invoice/core/error/failures.dart';
import 'package:xloop_invoice/features/driver_evaluation/domain/repositories/evaluation_repository.dart';

class GenerateEvaluationLinkUseCase {
  final EvaluationRepository repository;

  GenerateEvaluationLinkUseCase(this.repository);

  Future<Either<Failure, String>> call(String driverId, String driverName, String? vehicleId) async {
    return await repository.generateEvaluationLink(driverId, driverName, vehicleId);
  }
}
