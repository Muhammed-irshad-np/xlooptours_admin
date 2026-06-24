import 'package:dartz/dartz.dart';
import 'package:xloop_invoice/core/error/exceptions.dart';
import 'package:xloop_invoice/core/error/failures.dart';
import 'package:xloop_invoice/features/driver_evaluation/data/datasources/evaluation_remote_data_source.dart';
import 'package:xloop_invoice/features/driver_evaluation/domain/entities/evaluation_entity.dart';
import 'package:xloop_invoice/features/driver_evaluation/domain/repositories/evaluation_repository.dart';

class EvaluationRepositoryImpl implements EvaluationRepository {
  final EvaluationRemoteDataSource remoteDataSource;

  EvaluationRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, String>> generateEvaluationLink(String driverId, String driverName, String? vehicleId) async {
    try {
      final id = await remoteDataSource.generateEvaluationLink(driverId, driverName, vehicleId);
      return Right(id);
    } on ServerException {
      return Left(ServerFailure('Failed to generate link'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<EvaluationEntity>>> getPendingEvaluations() async {
    try {
      final models = await remoteDataSource.getPendingEvaluations();
      return Right(models);
    } on ServerException {
      return Left(ServerFailure('Failed to fetch pending evaluations'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> submitAdminScore(String evaluationId, Map<String, dynamic> scores) async {
    try {
      await remoteDataSource.submitAdminScore(evaluationId, scores);
      return const Right(null);
    } on ServerException {
      return Left(ServerFailure('Failed to submit score'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> submitDriverForm(String evaluationId, Map<String, dynamic> media) async {
    try {
      await remoteDataSource.submitDriverForm(evaluationId, media);
      return const Right(null);
    } on ServerException {
      return Left(ServerFailure('Failed to submit driver form'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, EvaluationEntity>> getEvaluationById(String evaluationId) async {
    try {
      final model = await remoteDataSource.getEvaluationById(evaluationId);
      return Right(model);
    } on ServerException {
      return Left(ServerFailure('Failed to fetch evaluation by id'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteEvaluation(String evaluationId) async {
    try {
      await remoteDataSource.deleteEvaluation(evaluationId);
      return const Right(null);
    } on ServerException {
      return Left(ServerFailure('Failed to delete evaluation'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}