import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/core/error/exceptions.dart';
import 'package:xloop_invoice/core/error/failures.dart';
import 'package:xloop_invoice/features/driver_evaluation/data/datasources/evaluation_remote_data_source.dart';
import 'package:xloop_invoice/features/driver_evaluation/data/models/evaluation_model.dart';
import 'package:xloop_invoice/features/driver_evaluation/data/repositories/evaluation_repository_impl.dart';

class MockEvaluationRemoteDataSource implements EvaluationRemoteDataSource {
  String? generatedLinkId;
  List<EvaluationModel>? pendingEvaluations;
  bool submitAdminScoreCalled = false;
  bool submitDriverFormCalled = false;
  EvaluationModel? evaluationById;
  bool throwException = false;

  @override
  Future<String> generateEvaluationLink(
    String driverId,
    String driverName,
    String? vehicleId,
  ) async {
    if (throwException) throw ServerException();
    return generatedLinkId ?? 'link-id';
  }

  @override
  Future<List<EvaluationModel>> getPendingEvaluations() async {
    if (throwException) throw ServerException();
    return pendingEvaluations ?? [];
  }

  @override
  Future<void> submitAdminScore(
    String evaluationId,
    Map<String, dynamic> scores,
  ) async {
    if (throwException) throw ServerException();
    submitAdminScoreCalled = true;
  }

  @override
  Future<void> submitDriverForm(
    String evaluationId,
    Map<String, dynamic> media,
  ) async {
    if (throwException) throw ServerException();
    submitDriverFormCalled = true;
  }

  @override
  Future<EvaluationModel> getEvaluationById(String evaluationId) async {
    if (throwException) throw ServerException();
    return evaluationById ??
        EvaluationModel(
          id: evaluationId,
          driverId: 'd1',
          driverName: 'Driver 1',
          status: 'pending',
          createdAt: DateTime.now(),
          media: const {},
        );
  }

  bool deleteEvaluationCalled = false;
  @override
  Future<void> deleteEvaluation(String evaluationId) async {
    if (throwException) throw ServerException();
    deleteEvaluationCalled = true;
  }
}

void main() {
  late EvaluationRepositoryImpl repository;
  late MockEvaluationRemoteDataSource mockRemoteDataSource;

  setUp(() {
    mockRemoteDataSource = MockEvaluationRemoteDataSource();
    repository = EvaluationRepositoryImpl(
      remoteDataSource: mockRemoteDataSource,
    );
  });

  group('generateEvaluationLink', () {
    test(
      'should return Right(id) when remote data source call is successful',
      () async {
        // arrange
        mockRemoteDataSource.generatedLinkId = 'eval-id-abc';

        // act
        final result = await repository.generateEvaluationLink(
          'd1',
          'Driver 1',
          'v1',
        );

        // assert
        expect(result, const Right('eval-id-abc'));
      },
    );

    test(
      'should return Left(ServerFailure) when remote data source throws ServerException',
      () async {
        // arrange
        mockRemoteDataSource.throwException = true;

        // act
        final result = await repository.generateEvaluationLink(
          'd1',
          'Driver 1',
          'v1',
        );

        // assert
        expect(result, const Left(ServerFailure('Failed to generate link')));
      },
    );
  });

  group('getPendingEvaluations', () {
    test(
      'should return list of evaluations when remote call is successful',
      () async {
        // arrange
        final list = [
          EvaluationModel(
            id: 'eval1',
            driverId: 'd1',
            driverName: 'Driver 1',
            status: 'pending',
            createdAt: DateTime.now(),
            media: const {},
          ),
        ];
        mockRemoteDataSource.pendingEvaluations = list;

        // act
        final result = await repository.getPendingEvaluations();

        // assert
        expect(result, Right(list));
      },
    );

    test(
      'should return Left(ServerFailure) when remote data source throws Exception',
      () async {
        // arrange
        mockRemoteDataSource.throwException = true;

        // act
        final result = await repository.getPendingEvaluations();

        // assert
        expect(
          result,
          const Left(ServerFailure('Failed to fetch pending evaluations')),
        );
      },
    );
  });

  group('submitAdminScore', () {
    test('should return Right(null) when remote call is successful', () async {
      // act
      final result = await repository.submitAdminScore('eval1', const {});

      // assert
      expect(result, const Right(null));
      expect(mockRemoteDataSource.submitAdminScoreCalled, true);
    });

    test(
      'should return Left(ServerFailure) when remote data source throws Exception',
      () async {
        // arrange
        mockRemoteDataSource.throwException = true;

        // act
        final result = await repository.submitAdminScore('eval1', const {});

        // assert
        expect(result, const Left(ServerFailure('Failed to submit score')));
      },
    );
  });

  group('submitDriverForm', () {
    test('should return Right(null) when remote call is successful', () async {
      // act
      final result = await repository.submitDriverForm('eval1', const {});

      // assert
      expect(result, const Right(null));
      expect(mockRemoteDataSource.submitDriverFormCalled, true);
    });

    test(
      'should return Left(ServerFailure) when remote data source throws Exception',
      () async {
        // arrange
        mockRemoteDataSource.throwException = true;

        // act
        final result = await repository.submitDriverForm('eval1', const {});

        // assert
        expect(
          result,
          const Left(ServerFailure('Failed to submit driver form')),
        );
      },
    );
  });

  group('getEvaluationById', () {
    test(
      'should return evaluation model when remote call is successful',
      () async {
        // arrange
        final eval = EvaluationModel(
          id: 'eval-123',
          driverId: 'd1',
          driverName: 'Driver 1',
          status: 'pending',
          createdAt: DateTime.now(),
          media: const {},
        );
        mockRemoteDataSource.evaluationById = eval;

        // act
        final result = await repository.getEvaluationById('eval-123');

        // assert
        expect(result, Right(eval));
      },
    );

    test(
      'should return Left(ServerFailure) when remote data source throws Exception',
      () async {
        // arrange
        mockRemoteDataSource.throwException = true;

        // act
        final result = await repository.getEvaluationById('eval-123');

        // assert
        expect(
          result,
          const Left(ServerFailure('Failed to fetch evaluation by id')),
        );
      },
    );
  });

  group('deleteEvaluation', () {
    test('should return Right(null) when remote call is successful', () async {
      // act
      final result = await repository.deleteEvaluation('eval-123');

      // assert
      expect(result, const Right(null));
      expect(mockRemoteDataSource.deleteEvaluationCalled, true);
    });

    test(
      'should return Left(ServerFailure) when remote data source throws Exception',
      () async {
        // arrange
        mockRemoteDataSource.throwException = true;

        // act
        final result = await repository.deleteEvaluation('eval-123');

        // assert
        expect(
          result,
          const Left(ServerFailure('Failed to delete evaluation')),
        );
      },
    );
  });
}
