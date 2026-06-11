import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/core/error/failures.dart';
import 'package:xloop_invoice/features/driver_evaluation/domain/entities/evaluation_entity.dart';
import 'package:xloop_invoice/features/driver_evaluation/domain/repositories/evaluation_repository.dart';
import 'package:xloop_invoice/features/driver_evaluation/domain/usecases/generate_evaluation_link_usecase.dart';
import 'package:xloop_invoice/features/driver_evaluation/domain/usecases/get_evaluation_by_id_usecase.dart';
import 'package:xloop_invoice/features/driver_evaluation/domain/usecases/get_pending_evaluations_usecase.dart';
import 'package:xloop_invoice/features/driver_evaluation/domain/usecases/submit_admin_score_usecase.dart';
import 'package:xloop_invoice/features/driver_evaluation/domain/usecases/submit_driver_form_usecase.dart';
import 'package:xloop_invoice/features/driver_evaluation/domain/usecases/delete_evaluation_usecase.dart';

class MockEvaluationRepository implements EvaluationRepository {
  String? generatedLinkId;
  List<EvaluationEntity>? pendingEvaluations;
  bool submitAdminScoreCalled = false;
  bool submitDriverFormCalled = false;
  EvaluationEntity? evaluationById;
  Failure? failure;

  @override
  Future<Either<Failure, String>> generateEvaluationLink(String driverId, String driverName, String? vehicleId) async {
    if (failure != null) return Left(failure!);
    return Right(generatedLinkId ?? 'test-link-id');
  }

  @override
  Future<Either<Failure, List<EvaluationEntity>>> getPendingEvaluations() async {
    if (failure != null) return Left(failure!);
    return Right(pendingEvaluations ?? []);
  }

  @override
  Future<Either<Failure, void>> submitAdminScore(String evaluationId, Map<String, dynamic> scores) async {
    if (failure != null) return Left(failure!);
    submitAdminScoreCalled = true;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> submitDriverForm(String evaluationId, Map<String, dynamic> media) async {
    if (failure != null) return Left(failure!);
    submitDriverFormCalled = true;
    return const Right(null);
  }

  @override
  Future<Either<Failure, EvaluationEntity>> getEvaluationById(String evaluationId) async {
    if (failure != null) return Left(failure!);
    return Right(evaluationById ?? EvaluationEntity(
      id: evaluationId,
      driverId: 'd1',
      driverName: 'Driver 1',
      status: 'pending',
      createdAt: DateTime.now(),
      media: const {},
    ));
  }

  bool deleteEvaluationCalled = false;
  @override
  Future<Either<Failure, void>> deleteEvaluation(String evaluationId) async {
    if (failure != null) return Left(failure!);
    deleteEvaluationCalled = true;
    return const Right(null);
  }
}

void main() {
  late MockEvaluationRepository mockRepository;

  setUp(() {
    mockRepository = MockEvaluationRepository();
  });

  group('GenerateEvaluationLinkUseCase', () {
    test('should generate and return evaluation link ID from repository', () async {
      // arrange
      final useCase = GenerateEvaluationLinkUseCase(mockRepository);
      mockRepository.generatedLinkId = 'new-id-123';

      // act
      final result = await useCase('driver1', 'Driver Name', 'vehicle1');

      // assert
      expect(result, const Right('new-id-123'));
    });
  });

  group('GetPendingEvaluationsUseCase', () {
    test('should retrieve pending evaluations from repository', () async {
      // arrange
      final useCase = GetPendingEvaluationsUseCase(mockRepository);
      final list = [
        EvaluationEntity(
          id: 'eval1',
          driverId: 'd1',
          driverName: 'Driver 1',
          status: 'pending',
          createdAt: DateTime.now(),
          media: const {},
        )
      ];
      mockRepository.pendingEvaluations = list;

      // act
      final result = await useCase();

      // assert
      expect(result, Right(list));
    });
  });

  group('SubmitAdminScoreUseCase', () {
    test('should forward admin scores to repository', () async {
      // arrange
      final useCase = SubmitAdminScoreUseCase(mockRepository);
      final scores = {'appearance': 5, 'vehicle': 4, 'passed': true};

      // act
      final result = await useCase('eval1', scores);

      // assert
      expect(result, const Right(null));
      expect(mockRepository.submitAdminScoreCalled, true);
    });
  });

  group('SubmitDriverFormUseCase', () {
    test('should forward driver media form data to repository', () async {
      // arrange
      final useCase = SubmitDriverFormUseCase(mockRepository);
      final media = {'full_body': {'url': 'http://test.com', 'timestamp': '2026-06-11'}};

      // act
      final result = await useCase('eval1', media);

      // assert
      expect(result, const Right(null));
      expect(mockRepository.submitDriverFormCalled, true);
    });
  });

  group('GetEvaluationByIdUseCase', () {
    test('should retrieve evaluation by id from repository', () async {
      // arrange
      final useCase = GetEvaluationByIdUseCase(mockRepository);
      final eval = EvaluationEntity(
        id: 'eval123',
        driverId: 'd1',
        driverName: 'Driver 1',
        status: 'pending',
        createdAt: DateTime.now(),
        media: const {},
      );
      mockRepository.evaluationById = eval;

      // act
      final result = await useCase('eval123');

      // assert
      expect(result, Right(eval));
    });
  });

  group('DeleteEvaluationUseCase', () {
    test('should call repository to delete the evaluation', () async {
      // arrange
      final useCase = DeleteEvaluationUseCase(mockRepository);

      // act
      final result = await useCase('eval123');

      // assert
      expect(result, const Right(null));
      expect(mockRepository.deleteEvaluationCalled, true);
    });
  });
}
