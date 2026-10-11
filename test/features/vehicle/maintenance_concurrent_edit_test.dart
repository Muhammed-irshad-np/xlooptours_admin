import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/features/vehicle/data/models/vehicle_model.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_documents.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_entity.dart';
import 'package:xloop_invoice/features/vehicle/domain/repositories/vehicle_repository.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/delete_maintenance_type_usecase.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/delete_shop_usecase.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/delete_vehicle_make_usecase.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/delete_vehicle_usecase.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/extend_vehicle_maintenance_usecase.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/get_all_maintenance_types_usecase.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/get_all_shops_usecase.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/get_all_vehicle_makes_usecase.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/get_all_vehicles_usecase.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/get_vehicle_settings_usecase.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/insert_maintenance_type_usecase.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/insert_shop_usecase.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/insert_vehicle_make_usecase.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/insert_vehicle_usecase.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/modify_vehicle_usecase.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/update_maintenance_type_usecase.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/update_shop_usecase.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/update_vehicle_make_usecase.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/update_vehicle_settings_usecase.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/update_vehicle_usecase.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/upload_vehicle_document_usecase.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/upload_vehicle_image_usecase.dart';
import 'package:xloop_invoice/features/vehicle/presentation/providers/vehicle_provider.dart';

/// Stores vehicles as JSON and writes them the way the Firestore data source
/// does: [modifyVehicle] patches only changed fields of the stored copy, and
/// [updateVehicle] never writes maintenance.
class _StoredVehicleRepository implements VehicleRepository {
  final Map<String, Map<String, dynamic>> docs = {};

  void put(VehicleEntity v) => docs[v.id] = VehicleModel.fromEntity(v).toJson();
  VehicleEntity stored(String id) => VehicleModel.fromJson(docs[id]!);

  @override
  Future<VehicleEntity> modifyVehicle(
    String vehicleId,
    VehicleEntity Function(VehicleEntity latest) change,
  ) async {
    final latest = stored(vehicleId);
    docs[vehicleId]!.addAll(vehicleChangePatch(latest, change(latest)));
    return stored(vehicleId);
  }

  @override
  Future<void> updateVehicle(VehicleEntity vehicle) async {
    final json = VehicleModel.fromEntity(vehicle).toJson()
      ..remove('maintenanceHistory')
      ..remove('maintenance');
    docs[vehicle.id]!.addAll(json);
  }

  @override
  Future<List<VehicleEntity>> getAllVehicles() async =>
      docs.keys.map(stored).toList();

  // A concrete noSuchMethod stands in for the rest of the interface, none of
  // which the code under test reaches.
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName} is not used by this test');
}

VehicleProvider _provider(VehicleRepository repo) => VehicleProvider(
  getAllVehiclesUseCase: GetAllVehiclesUseCase(repo),
  insertVehicleUseCase: InsertVehicleUseCase(repo),
  updateVehicleUseCase: UpdateVehicleUseCase(repo),
  deleteVehicleUseCase: DeleteVehicleUseCase(repo),
  uploadVehicleImageUseCase: UploadVehicleImageUseCase(repo),
  uploadVehicleDocumentUseCase: UploadVehicleDocumentUseCase(repo),
  getAllVehicleMakesUseCase: GetAllVehicleMakesUseCase(repo),
  insertVehicleMakeUseCase: InsertVehicleMakeUseCase(repo),
  updateVehicleMakeUseCase: UpdateVehicleMakeUseCase(repo),
  deleteVehicleMakeUseCase: DeleteVehicleMakeUseCase(repo),
  getAllMaintenanceTypesUseCase: GetAllMaintenanceTypesUseCase(repo),
  insertMaintenanceTypeUseCase: InsertMaintenanceTypeUseCase(repo),
  updateMaintenanceTypeUseCase: UpdateMaintenanceTypeUseCase(repo),
  deleteMaintenanceTypeUseCase: DeleteMaintenanceTypeUseCase(repo),
  getAllShopsUseCase: GetAllShopsUseCase(repo),
  insertShopUseCase: InsertShopUseCase(repo),
  updateShopUseCase: UpdateShopUseCase(repo),
  deleteShopUseCase: DeleteShopUseCase(repo),
  getVehicleSettingsUseCase: GetVehicleSettingsUseCase(repo),
  updateVehicleSettingsUseCase: UpdateVehicleSettingsUseCase(repo),
  extendVehicleMaintenanceUseCase: ExtendVehicleMaintenanceUseCase(repo),
  modifyVehicleUseCase: ModifyVehicleUseCase(repo),
);

MaintenanceRecord _record(String type, int km, DateTime date) =>
    MaintenanceRecord(
      date: date,
      mileage: km,
      serviceType: type,
      serviceProvider: 'SELF CHANGE',
      cost: 382,
      notes: '',
      isFollowUpRequired: false,
      performedBy: 'Tester',
    );

void main() {
  final oil = _record('Engine Oil & Filter', 219654, DateTime(2026, 10, 8));
  final fanBelt = _record('Fan Belt', 220000, DateTime(2026, 10, 10));
  final acFilter = _record('AC Filter', 220416, DateTime(2026, 10, 11, 18, 55));
  final airFilter = _record('Air Filter', 220416, DateTime(2026, 10, 11, 18, 56));

  const base = VehicleEntity(
    id: 'yukon',
    make: 'GMC',
    model: 'Yukon',
    year: 2020,
    color: 'White',
    plateNumber: '5400 TNR',
    type: 'SUV',
    currentOdometer: 220416,
  );

  // What a page opened before the two filters were added still holds.
  final stalePage = base.copyWith(maintenanceHistory: [oil, fanBelt]);

  late _StoredVehicleRepository repo;

  setUp(() {
    repo = _StoredVehicleRepository()
      ..put(base.copyWith(
        maintenanceHistory: [oil, fanBelt, acFilter, airFilter],
      ));
  });

  test('deleting from a page loaded earlier keeps records added since',
      () async {
    await _provider(repo).deleteMaintenanceRecord(stalePage, fanBelt);

    expect(repo.stored('yukon').maintenanceHistory, [oil, acFilter, airFilter]);
  });

  test('deleting a record already removed elsewhere fails and saves nothing',
      () async {
    repo.put(base.copyWith(maintenanceHistory: [oil, acFilter, airFilter]));

    await expectLater(
      _provider(repo).deleteMaintenanceRecord(stalePage, fanBelt),
      throwsStateError,
    );
    expect(repo.stored('yukon').maintenanceHistory, [oil, acFilter, airFilter]);
  });

  test('adding from a page loaded earlier keeps records added since', () async {
    final wiper = _record('Wiper Blades', 220500, DateTime(2026, 10, 12));

    await _provider(repo).modifyVehicle(
      stalePage.id,
      (latest) => latest.copyWith(
        maintenanceHistory: [...?latest.maintenanceHistory, wiper],
      ),
    );

    expect(
      repo.stored('yukon').maintenanceHistory,
      [oil, fanBelt, acFilter, airFilter, wiper],
    );
  });

  test('extending an alert from a page loaded earlier keeps records added since',
      () async {
    await ExtendVehicleMaintenanceUseCase(repo)(
      vehicle: stalePage,
      category: 'Engine Oil & Filter',
      extensionKm: 1000,
      reason: 'Test',
    );

    final history = repo.stored('yukon').maintenanceHistory!;
    expect(history, containsAll([fanBelt, acFilter, airFilter]));
    expect(history.last.serviceType, 'Extension: Engine Oil & Filter');
  });

  test('saving other vehicle details from a page loaded earlier keeps records',
      () async {
    final provider = _provider(repo);
    await provider.fetchAllVehicles();

    await provider.updateVehicle(stalePage.copyWith(color: 'Black'));

    final stored = repo.stored('yukon');
    expect(stored.color, 'Black');
    expect(stored.maintenanceHistory, [oil, fanBelt, acFilter, airFilter]);
    expect(
      provider.vehicles.single.maintenanceHistory,
      [oil, fanBelt, acFilter, airFilter],
      reason: 'the cache should not take the stale list either',
    );
  });

  group('vehicleChangePatch', () {
    test('holds only the fields that changed', () {
      final before = base.copyWith(maintenanceHistory: [oil]);
      final after = before.copyWith(maintenanceHistory: [oil, fanBelt]);

      expect(vehicleChangePatch(before, after).keys, ['maintenanceHistory']);
    });

    test('is empty when nothing changed', () {
      final v = base.copyWith(maintenanceHistory: [oil]);
      expect(vehicleChangePatch(v, v.copyWith()), isEmpty);
    });
  });

  test('a record still equals itself after a save and reload', () {
    // Delete and follow-up completion find their record by equality against
    // the freshly loaded copy, so the round trip must not change it. Shaped
    // like the add dialog's records, which set attachmentUrl to the first of
    // attachmentUrls.
    final record = MaintenanceRecord(
      date: DateTime(2026, 10, 11, 18, 55, 12, 345),
      mileage: 220416,
      cost: 361.6,
      serviceType: 'AC Filter',
      serviceProvider: 'SELF CHANGE',
      notes: 'note',
      attachmentUrl: 'https://example.test/a.jpg',
      attachmentUrls: const ['https://example.test/a.jpg'],
      isFollowUpRequired: true,
      followUpReason: 'check',
      nextServiceDate: DateTime(2026, 11, 1),
      nextServiceMileage: 225000,
      isFollowUpCompleted: false,
      followUpCompletions: const [],
      performedBy: 'Nithin Mathew',
    );
    VehicleEntity reload(VehicleEntity v) =>
        VehicleModel.fromJson(VehicleModel.fromEntity(v).toJson());

    final once = reload(base.copyWith(maintenanceHistory: [record]));
    expect(once.maintenanceHistory!.single, record);
    expect(reload(once).maintenanceHistory, once.maintenanceHistory);
  });
}
