import 'package:image_picker/image_picker.dart';
import 'package:xloop_invoice/features/auth/domain/entities/user_entity.dart';
import 'package:xloop_invoice/features/maintenance/domain/entities/work_order_entity.dart';
import 'package:xloop_invoice/features/maintenance/domain/entities/work_order_line.dart';
import 'package:xloop_invoice/features/maintenance/domain/entities/work_order_status.dart';
import 'package:xloop_invoice/features/maintenance/domain/repositories/work_order_repository.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/maintenance_type_entity.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/shop_entity.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_entity.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_make_entity.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_settings_entity.dart';
import 'package:xloop_invoice/features/vehicle/domain/repositories/vehicle_repository.dart';

class FakeWorkOrderRepository implements WorkOrderRepository {
  final Map<String, WorkOrderEntity> store = {};
  final List<WorkOrderEntity> updates = [];
  int numberCounter = 0;

  @override
  Future<List<WorkOrderEntity>> getWorkOrders({int limit = 300}) async =>
      store.values.toList();

  @override
  Future<List<WorkOrderEntity>> getWorkOrdersForVehicle(
    String vehicleId,
  ) async =>
      store.values.where((w) => w.vehicleId == vehicleId).toList();

  @override
  Future<List<WorkOrderEntity>> getOpenWorkOrders() async =>
      store.values.where((w) => w.isOpen).toList();

  @override
  Future<WorkOrderEntity?> getWorkOrderById(String id) async => store[id];

  @override
  Future<void> insertWorkOrder(WorkOrderEntity workOrder) async {
    store[workOrder.id] = workOrder;
  }

  @override
  Future<void> updateWorkOrder(WorkOrderEntity workOrder) async {
    store[workOrder.id] = workOrder;
    updates.add(workOrder);
  }

  @override
  Future<void> deleteWorkOrder(String id) async {
    store.remove(id);
  }

  @override
  Future<String> generateWorkOrderNumber() async {
    numberCounter++;
    return 'WO-2026-${numberCounter.toString().padLeft(4, '0')}';
  }

  @override
  Future<String> uploadAttachment(
    XFile file,
    String workOrderId,
    String kind,
  ) async =>
      'https://example.test/$workOrderId/$kind';
}

class FakeVehicleRepository implements VehicleRepository {
  final Map<String, VehicleEntity> store = {};
  final List<VehicleEntity> updates = [];

  @override
  Future<List<VehicleEntity>> getAllVehicles() async => store.values.toList();

  @override
  Future<VehicleEntity?> getVehicleById(String id) async => store[id];

  @override
  Future<void> insertVehicle(VehicleEntity vehicle) async {
    store[vehicle.id] = vehicle;
  }

  @override
  Future<void> updateVehicle(VehicleEntity vehicle) async {
    store[vehicle.id] = vehicle;
    updates.add(vehicle);
  }

  @override
  Future<void> deleteVehicle(String id) async => store.remove(id);

  @override
  Future<String> uploadVehicleImage(XFile image, String vehicleId) async => '';

  @override
  Future<String> uploadDocumentAttachment(
    XFile file,
    String vehicleId,
    String docType,
  ) async =>
      '';

  @override
  Future<List<VehicleMakeEntity>> getAllVehicleMakes() async => [];

  @override
  Future<void> insertVehicleMake(VehicleMakeEntity make) async {}

  @override
  Future<void> updateVehicleMake(VehicleMakeEntity make) async {}

  @override
  Future<void> deleteVehicleMake(String id) async {}

  @override
  Future<List<MaintenanceTypeEntity>> getAllMaintenanceTypes() async => [];

  @override
  Future<void> insertMaintenanceType(MaintenanceTypeEntity type) async {}

  @override
  Future<void> updateMaintenanceType(MaintenanceTypeEntity type) async {}

  @override
  Future<void> deleteMaintenanceType(String id) async {}

  @override
  Future<List<ShopEntity>> getAllShops() async => [];

  @override
  Future<void> insertShop(ShopEntity shop) async {}

  @override
  Future<void> updateShop(ShopEntity shop) async {}

  @override
  Future<void> deleteShop(String id) async {}

  @override
  Future<VehicleSettingsEntity> getVehicleSettings() async =>
      const VehicleSettingsEntity();

  @override
  Future<void> updateVehicleSettings(VehicleSettingsEntity settings) async {}
}

// ─── Builders ────────────────────────────────────────────────

UserEntity testUser({
  String id = 'user-1',
  String role = 'coordinator',
  String name = 'Coordinator A',
}) =>
    UserEntity(
      id: id,
      email: '$id@example.test',
      displayName: name,
      roleId: role,
      permissions: const [],
    );

VehicleEntity testVehicle({
  String id = 'veh-1',
  String status = 'Active',
  int odometer = 50000,
}) =>
    VehicleEntity(
      id: id,
      make: 'Toyota',
      model: 'Land Cruiser',
      year: 2022,
      color: 'White',
      plateNumber: 'ABC 1234',
      type: 'SUV',
      status: status,
      currentOdometer: odometer,
    );

WorkOrderLine testLine({
  String id = 'line-1',
  String typeId = 'engine_oil',
  String typeName = 'Engine Oil',
  double estimate = 400,
  double? actual,
  bool completed = true,
}) =>
    WorkOrderLine(
      id: id,
      maintenanceTypeId: typeId,
      maintenanceTypeName: typeName,
      estimatedCost: estimate,
      actualCost: actual,
      completed: completed,
    );

WorkOrderEntity testWorkOrder({
  String id = 'WO-2026-0001',
  WorkOrderStatus status = WorkOrderStatus.completed,
  List<WorkOrderLine>? lines,
  double? approvedAmount = 400,
  String? fundAccountId = 'acc-1',
  String? expenseId,
  String vehicleStatusBefore = 'Active',
  bool paidFromDriverAdvance = false,
  List<String> invoiceUrls = const ['https://example.test/invoice.pdf'],
}) =>
    WorkOrderEntity(
      id: id,
      workOrderNumber: id,
      status: status,
      vehicleId: 'veh-1',
      vehiclePlate: 'ABC 1234',
      vehicleName: 'Toyota Land Cruiser 2022',
      complaint: 'Service due',
      createdBy: 'Coordinator A',
      createdByUserId: 'user-1',
      createdAt: DateTime(2026, 1, 10),
      completedAt: DateTime(2026, 1, 12),
      odometerAtService: 52000,
      lines: lines ?? [testLine(actual: 380)],
      approvedAmount: approvedAmount,
      approvedBy: 'Manager A',
      approvedByUserId: 'mgr-1',
      approvedAt: DateTime(2026, 1, 11),
      shopId: 'shop-1',
      shopName: 'Al-Amana Auto',
      fundAccountId: fundAccountId,
      fundAccountName: 'Riyadh Petty Cash',
      expenseId: expenseId,
      vehicleStatusBefore: vehicleStatusBefore,
      paidFromDriverAdvance: paidFromDriverAdvance,
      invoiceUrls: invoiceUrls,
    );
