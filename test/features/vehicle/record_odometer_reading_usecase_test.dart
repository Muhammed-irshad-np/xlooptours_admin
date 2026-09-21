import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/odometer_policy.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/odometer_reading_entity.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_entity.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_make_entity.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/maintenance_type_entity.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_settings_entity.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/shop_entity.dart';
import 'package:xloop_invoice/features/vehicle/domain/repositories/odometer_repository.dart';
import 'package:xloop_invoice/features/vehicle/domain/repositories/vehicle_repository.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/record_odometer_reading_usecase.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/review_odometer_reading_usecase.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/validate_odometer_reading_usecase.dart';

class _FakeOdometerRepository implements OdometerRepository {
  final Map<String, List<OdometerReadingEntity>> store = {};

  @override
  Future<List<OdometerReadingEntity>> getReadings(String vehicleId) async =>
      [...(store[vehicleId] ?? const <OdometerReadingEntity>[])]
        ..sort((a, b) => a.readingAt.compareTo(b.readingAt));

  @override
  Future<void> insertReading(OdometerReadingEntity reading) async {
    store.putIfAbsent(reading.vehicleId, () => []).add(reading);
  }

  @override
  Future<void> updateReadingReview(OdometerReadingEntity reading) async {
    final list = store[reading.vehicleId]!;
    final i = list.indexWhere((r) => r.id == reading.id);
    list[i] = reading;
  }

  @override
  Future<List<OdometerReadingEntity>> getQuarantinedReadings() async => store
      .values
      .expand((l) => l)
      .where((r) => r.needsReview)
      .toList();

  @override
  Future<List<OdometerReadingEntity>> getRecentReadings({int limit = 500}) async =>
      store.values.expand((l) => l).where((r) => r.isUsable).toList();

  @override
  Future<String> uploadOdometerPhoto(
    XFile photo,
    String vehicleId,
    String readingId,
  ) async => 'https://example.test/$readingId.jpg';
}

class _FakeVehicleRepository implements VehicleRepository {
  final List<VehicleEntity> saved = [];

  @override
  Future<void> updateVehicle(VehicleEntity vehicle) async => saved.add(vehicle);

  // Declared to satisfy the interface; none of these are reached by the code
  // under test, which only ever calls updateVehicle.
  @override
  Future<List<VehicleEntity>> getAllVehicles() => throw UnimplementedError();
  @override
  Future<void> insertVehicle(VehicleEntity v) => throw UnimplementedError();
  @override
  Future<void> deleteVehicle(String id) => throw UnimplementedError();
  @override
  Future<String> uploadVehicleImage(XFile i, String id) =>
      throw UnimplementedError();
  @override
  Future<String> uploadDocumentAttachment(XFile f, String id, String t) =>
      throw UnimplementedError();
  @override
  Future<List<VehicleMakeEntity>> getAllVehicleMakes() =>
      throw UnimplementedError();
  @override
  Future<void> insertVehicleMake(VehicleMakeEntity m) =>
      throw UnimplementedError();
  @override
  Future<void> updateVehicleMake(VehicleMakeEntity m) =>
      throw UnimplementedError();
  @override
  Future<void> deleteVehicleMake(String id) => throw UnimplementedError();
  @override
  Future<List<MaintenanceTypeEntity>> getAllMaintenanceTypes() =>
      throw UnimplementedError();
  @override
  Future<void> insertMaintenanceType(MaintenanceTypeEntity t) =>
      throw UnimplementedError();
  @override
  Future<void> updateMaintenanceType(MaintenanceTypeEntity t) =>
      throw UnimplementedError();
  @override
  Future<void> deleteMaintenanceType(String id) => throw UnimplementedError();
  @override
  Future<List<ShopEntity>> getAllShops() => throw UnimplementedError();
  @override
  Future<void> insertShop(ShopEntity s) => throw UnimplementedError();
  @override
  Future<void> updateShop(ShopEntity s) => throw UnimplementedError();
  @override
  Future<void> deleteShop(String id) => throw UnimplementedError();
  @override
  Future<VehicleSettingsEntity> getVehicleSettings() =>
      throw UnimplementedError();
  @override
  Future<void> updateVehicleSettings(VehicleSettingsEntity s) =>
      throw UnimplementedError();
}

void main() {
  const policy = OdometerPolicy.defaults;
  final today = DateTime.now();
  final anchor = DateTime(
    today.year,
    today.month,
    today.day,
  ).subtract(const Duration(days: 30));

  late _FakeOdometerRepository odoRepo;
  late _FakeVehicleRepository vehicleRepo;
  late RecordOdometerReadingUseCase record;
  late ReviewOdometerReadingUseCase review;

  VehicleEntity vehicle({int? current, DateTime? lastUpdate}) => VehicleEntity(
    id: 'v1',
    make: 'Toyota',
    model: 'Hiace',
    year: 2022,
    color: 'White',
    plateNumber: 'ABC 1234',
    type: 'Van',
    currentOdometer: current,
    lastOdometerUpdateDate: lastUpdate,
  );

  setUp(() {
    odoRepo = _FakeOdometerRepository();
    vehicleRepo = _FakeVehicleRepository();
    record = RecordOdometerReadingUseCase(
      odometerRepository: odoRepo,
      vehicleRepository: vehicleRepo,
      validator: const ValidateOdometerReadingUseCase(policy: policy),
      policy: policy,
    );
    review = ReviewOdometerReadingUseCase(
      odometerRepository: odoRepo,
      vehicleRepository: vehicleRepo,
    );
  });

  group('seeding legacy vehicles', () {
    test('an existing currentOdometer becomes the first logged reading', () async {
      final v = vehicle(current: 40000, lastUpdate: anchor);

      await record(
        vehicle: v,
        value: 41000,
        source: OdometerSource.weeklyUpdate,
        readingAt: anchor.add(const Duration(days: 7)),
      );

      final readings = await odoRepo.getReadings('v1');
      expect(readings.length, 2);
      expect(readings.first.source, OdometerSource.initial);
      expect(readings.first.value, 40000);
      expect(readings.last.value, 41000);
    });

    test('the seeded value anchors validation, so a slip is still caught', () async {
      final v = vehicle(current: 40000, lastUpdate: anchor);

      await expectLater(
        record(
          vehicle: v,
          value: 410000, // an extra zero
          source: OdometerSource.weeklyUpdate,
          readingAt: anchor.add(const Duration(days: 7)),
        ),
        throwsA(isA<OdometerReadingRejected>()),
      );
    });
  });

  group('derived currentOdometer', () {
    test('an accepted reading moves it', () async {
      final v = vehicle(current: 40000, lastUpdate: anchor);

      final result = await record(
        vehicle: v,
        value: 40800,
        source: OdometerSource.weeklyUpdate,
        readingAt: anchor.add(const Duration(days: 7)),
      );

      expect(result.wasAccepted, isTrue);
      expect(result.updatedVehicle?.currentOdometer, 40800);
      expect(vehicleRepo.saved.last.currentOdometer, 40800);
    });

    test('a quarantined reading does NOT move it', () async {
      // Build enough history for a learned baseline of ~110 km/day.
      final v = vehicle(current: 40000, lastUpdate: anchor);
      await record(
        vehicle: v,
        value: 40770,
        source: OdometerSource.weeklyUpdate,
        readingAt: anchor.add(const Duration(days: 7)),
      );
      await record(
        vehicle: vehicleRepo.saved.last,
        value: 41540,
        source: OdometerSource.weeklyUpdate,
        readingAt: anchor.add(const Duration(days: 14)),
      );
      await record(
        vehicle: vehicleRepo.saved.last,
        value: 42310,
        source: OdometerSource.weeklyUpdate,
        readingAt: anchor.add(const Duration(days: 21)),
      );

      final before = vehicleRepo.saved.last;
      expect(before.currentOdometer, 42310);

      // Now a wildly high but not-impossible week.
      final result = await record(
        vehicle: before,
        value: 46000,
        source: OdometerSource.weeklyUpdate,
        readingAt: anchor.add(const Duration(days: 28)),
      );

      expect(result.needsReview, isTrue);
      expect(
        result.updatedVehicle,
        isNull,
        reason: 'a quarantined reading must not become the vehicle odometer',
      );
      expect(vehicleRepo.saved.last.currentOdometer, 42310);
    });

    test('accepting a quarantined reading then moves it', () async {
      final v = vehicle(current: 40000, lastUpdate: anchor);
      final result = await record(
        vehicle: v,
        value: 44000, // ~571 km/day against the 120 km/day fallback
        source: OdometerSource.weeklyUpdate,
        readingAt: anchor.add(const Duration(days: 7)),
      );
      expect(result.needsReview, isTrue);

      final updated = await review.accept(
        vehicle: v,
        reading: result.reading,
        reviewerUid: 'admin',
        reviewerName: 'Admin',
      );

      expect(updated?.currentOdometer, 44000);
    });
  });

  group('corrections', () {
    test('a correction supersedes the original and restores the truth', () async {
      final v = vehicle(current: 40000, lastUpdate: anchor);
      final result = await record(
        vehicle: v,
        value: 44000,
        source: OdometerSource.weeklyUpdate,
        readingAt: anchor.add(const Duration(days: 7)),
      );

      final updated = await review.correct(
        vehicle: v,
        original: result.reading,
        correctedValue: 40800,
        reviewerUid: 'admin',
        reviewerName: 'Admin',
      );

      expect(updated?.currentOdometer, 40800);

      final readings = await odoRepo.getReadings('v1');
      final original = readings.firstWhere((r) => r.id == result.reading.id);

      expect(original.status, OdometerReadingStatus.superseded);
      expect(original.supersededByReadingId, isNotNull);
      expect(
        original.value,
        44000,
        reason: 'the bad observation is kept verbatim for audit',
      );

      final correction = readings.firstWhere(
        (r) => r.supersedesReadingId == result.reading.id,
      );
      expect(correction.source, OdometerSource.correction);
      expect(correction.status, OdometerReadingStatus.accepted);
    });

    test('rejecting falls back to the last good reading', () async {
      final v = vehicle(current: 40000, lastUpdate: anchor);
      final good = await record(
        vehicle: v,
        value: 40800,
        source: OdometerSource.weeklyUpdate,
        readingAt: anchor.add(const Duration(days: 7)),
      );
      final bad = await record(
        vehicle: good.updatedVehicle!,
        value: 45000,
        source: OdometerSource.weeklyUpdate,
        readingAt: anchor.add(const Duration(days: 14)),
      );
      expect(bad.needsReview, isTrue);

      await review.accept(
        vehicle: good.updatedVehicle!,
        reading: bad.reading,
      );
      expect(vehicleRepo.saved.last.currentOdometer, 45000);

      final afterReject = await review.reject(
        vehicle: vehicleRepo.saved.last,
        reading: bad.reading.copyWith(status: OdometerReadingStatus.accepted),
      );
      expect(afterReject?.currentOdometer, 40800);
    });
  });

  group('cluster replacement', () {
    test('retires the old series and starts a new baseline', () async {
      final v = vehicle(current: 250000, lastUpdate: anchor);
      await record(
        vehicle: v,
        value: 250800,
        source: OdometerSource.weeklyUpdate,
        readingAt: anchor.add(const Duration(days: 7)),
      );

      final updated = await review.recordClusterReplacement(
        vehicle: vehicleRepo.saved.last,
        newValue: 0,
        replacedAt: anchor.add(const Duration(days: 8)),
        reviewerName: 'Admin',
      );

      expect(
        updated?.currentOdometer,
        0,
        reason: 'the only legitimate way an odometer goes down',
      );

      final readings = await odoRepo.getReadings('v1');
      final retired = readings.where(
        (r) => r.status == OdometerReadingStatus.superseded,
      );
      expect(retired.length, 2, reason: 'seed + weekly reading both retired');
      expect(readings.where((r) => r.isUsable).length, 1);
    });
  });

  group('secondary sources', () {
    test('an impossible expense mileage is quarantined, never thrown away', () async {
      final v = vehicle(current: 40000, lastUpdate: anchor);

      final result = await record(
        vehicle: v,
        value: 400000, // fat-fingered on a fuel receipt
        source: OdometerSource.expense,
        readingAt: anchor.add(const Duration(days: 3)),
        sourceRefId: 'exp-1',
        throwOnBlock: false,
      );

      expect(result.reading.status, OdometerReadingStatus.quarantined);
      expect(result.reading.sourceRefId, 'exp-1');
      expect(result.updatedVehicle, isNull);
      expect(
        (await odoRepo.getReadings('v1')).length,
        2,
        reason: 'the contradiction is preserved for the review queue',
      );
    });
  });
}
