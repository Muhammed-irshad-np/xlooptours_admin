import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/odometer_policy.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/odometer_reading_entity.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/odometer_review_item.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_entity.dart';
import 'package:xloop_invoice/features/vehicle/domain/repositories/odometer_repository.dart';
import 'package:xloop_invoice/features/vehicle/domain/repositories/vehicle_repository.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/get_odometer_readings_usecase.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/get_odometer_review_queue_usecase.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/record_odometer_reading_usecase.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/review_odometer_reading_usecase.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/validate_odometer_reading_usecase.dart';
import 'package:xloop_invoice/features/vehicle/presentation/providers/odometer_provider.dart';

/// A repository whose collection-group queries fail, the way they do when the
/// Firestore composite index has not been deployed.
class _IndexlessOdometerRepository implements OdometerRepository {
  final Map<String, List<OdometerReadingEntity>> store = {};

  /// Set when the code under test reaches for a collection-group query.
  bool collectionGroupAttempted = false;

  @override
  Future<List<OdometerReadingEntity>> getReadings(String vehicleId) async =>
      [...(store[vehicleId] ?? const <OdometerReadingEntity>[])]
        ..sort((a, b) => a.readingAt.compareTo(b.readingAt));

  @override
  Future<List<OdometerReadingEntity>> getQuarantinedReadings() async {
    collectionGroupAttempted = true;
    throw Exception(
      'FAILED_PRECONDITION: The query requires an index.',
    );
  }

  @override
  Future<List<OdometerReadingEntity>> getRecentReadings({int limit = 500}) {
    collectionGroupAttempted = true;
    throw Exception('FAILED_PRECONDITION: The query requires an index.');
  }

  @override
  Future<void> insertReading(OdometerReadingEntity reading) async {
    store.putIfAbsent(reading.vehicleId, () => []).add(reading);
  }

  @override
  Future<void> updateReadingReview(OdometerReadingEntity reading) async {
    final list = store[reading.vehicleId]!;
    list[list.indexWhere((r) => r.id == reading.id)] = reading;
  }

  @override
  Future<String> uploadOdometerPhoto(XFile p, String v, String r) async => '';
}

void main() {
  const policy = OdometerPolicy.defaults;
  final today = DateTime.now();
  final anchor = DateTime(
    today.year,
    today.month,
    today.day,
  ).subtract(const Duration(days: 14));

  late _IndexlessOdometerRepository repo;
  late OdometerProvider provider;

  VehicleEntity vehicle(String id, {bool isActive = true}) => VehicleEntity(
    id: id,
    make: 'Chevrolet',
    model: 'Suburban',
    year: 2021,
    color: 'White',
    plateNumber: '6156 ASR',
    type: 'SUV',
    isActive: isActive,
    currentOdometer: 313964,
    lastOdometerUpdateDate: anchor,
  );

  OdometerReadingEntity reading(
    String id,
    String vehicleId,
    int value,
    DateTime at, {
    OdometerReadingStatus status = OdometerReadingStatus.accepted,
    OdometerSource source = OdometerSource.weeklyUpdate,
  }) => OdometerReadingEntity(
    id: id,
    vehicleId: vehicleId,
    value: value,
    readingAt: at,
    recordedAt: at,
    source: source,
    status: status,
  );

  setUp(() {
    repo = _IndexlessOdometerRepository();
    provider = OdometerProvider(
      getReadingsUseCase: GetOdometerReadingsUseCase(repo),
      recordReadingUseCase: RecordOdometerReadingUseCase(
        odometerRepository: repo,
        vehicleRepository: throw_(),
        validator: const ValidateOdometerReadingUseCase(policy: policy),
      ),
      reviewReadingUseCase: ReviewOdometerReadingUseCase(
        odometerRepository: repo,
        vehicleRepository: throw_(),
      ),
      getReviewQueueUseCase: const GetOdometerReviewQueueUseCase(
        policy: policy,
      ),
      getFleetDailyMedianUseCase: GetFleetDailyMedianUseCase(repo),
      validator: const ValidateOdometerReadingUseCase(policy: policy),
      repository: repo,
      policy: policy,
    );
  });

  group('review queue survives a missing Firestore index', () {
    test('a quarantined reading is listed', () async {
      final v = vehicle('v1');
      repo.store['v1'] = [
        reading('r1', 'v1', 313964, anchor),
        reading(
          'r2',
          'v1',
          320000,
          anchor.add(const Duration(days: 1)),
          status: OdometerReadingStatus.quarantined,
        ),
      ];

      await provider.loadReviewQueue([v]);

      expect(provider.queueError, isNull);
      expect(provider.queueLoaded, isTrue);

      final flagged = provider.reviewQueue.where(
        (i) => i.reason == OdometerReviewReason.quarantined,
      );
      expect(
        flagged,
        hasLength(1),
        reason: 'the flagged reading must appear even with no index deployed',
      );
      expect(flagged.first.reading?.value, 320000);
      expect(provider.pendingReviewCount, 1);
    });

    test('a stale vehicle is still listed alongside it', () async {
      final v = vehicle('v1');
      repo.store['v1'] = [
        reading('r1', 'v1', 313964, anchor.subtract(const Duration(days: 40))),
      ];

      await provider.loadReviewQueue([v]);

      expect(
        provider.reviewQueue.where(
          (i) => i.reason == OdometerReviewReason.stale,
        ),
        hasLength(1),
      );
    });

    test('inactive vehicles are left out', () async {
      await provider.loadReviewQueue([vehicle('v1', isActive: false)]);
      expect(provider.reviewQueue, isEmpty);
      expect(provider.queueError, isNull);
    });
  });

  group('failures are surfaced, not disguised as an empty queue', () {
    test('queueError is set when the per-vehicle read fails', () async {
      final failing = _AlwaysFailingRepository();
      final p = OdometerProvider(
        getReadingsUseCase: GetOdometerReadingsUseCase(failing),
        recordReadingUseCase: RecordOdometerReadingUseCase(
          odometerRepository: failing,
          vehicleRepository: throw_(),
          validator: const ValidateOdometerReadingUseCase(policy: policy),
        ),
        reviewReadingUseCase: ReviewOdometerReadingUseCase(
          odometerRepository: failing,
          vehicleRepository: throw_(),
        ),
        getReviewQueueUseCase: const GetOdometerReviewQueueUseCase(
          policy: policy,
        ),
        getFleetDailyMedianUseCase: GetFleetDailyMedianUseCase(failing),
        validator: const ValidateOdometerReadingUseCase(policy: policy),
        repository: failing,
        policy: policy,
      );

      await p.loadReviewQueue([vehicle('v1')]);

      expect(p.reviewQueue, isEmpty);
      expect(
        p.queueError,
        isNotNull,
        reason:
            'an empty queue and a failed load must be distinguishable, or a '
            'flagged reading silently goes unnoticed',
      );
    });
  });
}

class _AlwaysFailingRepository implements OdometerRepository {
  @override
  Future<List<OdometerReadingEntity>> getReadings(String vehicleId) =>
      throw Exception('PERMISSION_DENIED');
  @override
  Future<List<OdometerReadingEntity>> getQuarantinedReadings() =>
      throw Exception('PERMISSION_DENIED');
  @override
  Future<List<OdometerReadingEntity>> getRecentReadings({int limit = 500}) =>
      throw Exception('PERMISSION_DENIED');
  @override
  Future<void> insertReading(OdometerReadingEntity r) =>
      throw UnimplementedError();
  @override
  Future<void> updateReadingReview(OdometerReadingEntity r) =>
      throw UnimplementedError();
  @override
  Future<String> uploadOdometerPhoto(XFile p, String v, String r) =>
      throw UnimplementedError();
}

/// The review-queue path never touches the vehicle repository, so tests supply
/// a stub that fails loudly if that ever stops being true.
VehicleRepository throw_() => _UnusedVehicleRepository();

class _UnusedVehicleRepository implements VehicleRepository {
  // A concrete noSuchMethod lets this stand in for the full interface while
  // making any unexpected call fail loudly rather than silently succeed.
  @override
  dynamic noSuchMethod(Invocation i) => throw StateError(
    'the vehicle repository must not be touched while building the queue',
  );
}
