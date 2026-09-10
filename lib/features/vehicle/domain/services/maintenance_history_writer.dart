import '../entities/maintenance_type_entity.dart';
import '../entities/vehicle_documents.dart';
import '../entities/vehicle_entity.dart';

/// Special sentinel IDs for built-in extras that are not part of the
/// Firestore-managed maintenance-type master list.
const String kCarWashTypeId = '__car_wash__';
const String kOtherTypeId = '__other__';

/// A maintenance record paired with the maintenance-type id it belongs to.
typedef TypedMaintenanceRecord = ({String typeId, MaintenanceRecord record});

/// Single source of truth for writing maintenance records onto a vehicle.
///
/// Both [AddMaintenanceRecordDialog] (manual / retro entry) and
/// `CloseWorkOrderUseCase` (work-order driven) need to append to the flat
/// `maintenanceHistory` list **and** mirror the record into the typed
/// [VehicleMaintenance] slot, otherwise
/// `GetVehicleMaintenanceAlertsUseCase` cannot reset the service interval.
///
/// Keeping that in one place stops the two callers from drifting apart.
class MaintenanceHistoryWriter {
  const MaintenanceHistoryWriter();

  /// Resolves the human-readable service-type name for a maintenance type id.
  ///
  /// Handles the [kCarWashTypeId] / [kOtherTypeId] sentinels and falls back to
  /// [customName] (then the raw id) when the id is not in [types].
  String resolveTypeName({
    required String typeId,
    required List<MaintenanceTypeEntity> types,
    String? customName,
  }) {
    if (typeId == kCarWashTypeId) return 'Car Wash';
    if (typeId == kOtherTypeId) {
      final custom = customName?.trim() ?? '';
      return custom.isNotEmpty ? custom : 'Other';
    }
    for (final type in types) {
      if (type.id == typeId) return type.name;
    }
    final custom = customName?.trim() ?? '';
    return custom.isNotEmpty ? custom : typeId;
  }

  /// Mirrors [record] into the typed [VehicleMaintenance] slot for [typeId].
  ///
  /// Ad-hoc types (car wash, custom "other", or any future type with no typed
  /// slot) are only kept in the flat history and returned unchanged.
  VehicleMaintenance applyTypedRecord(
    VehicleMaintenance m,
    String typeId,
    MaintenanceRecord record,
  ) {
    final normId = typeId.toLowerCase().replaceAll(' ', '_');
    if (normId == 'engine_oil' ||
        normId == 'engine_oil_&_filter' ||
        normId.contains('engine_oil')) {
      return m.copyWith(engineOil: record);
    }
    switch (typeId) {
      case 'gear_oil':
        return m.copyWith(gearOil: record);
      case 'housing_oil':
        return m.copyWith(housingOil: record);
      case 'tyre_change':
        return m.copyWith(tyreChange: record);
      case 'battery_change':
        return m.copyWith(batteryChange: record);
      case 'brake_pads':
        return m.copyWith(brakePads: record);
      case 'air_filter':
        return m.copyWith(airFilter: record);
      case 'ac_service':
        return m.copyWith(acService: record);
      case 'wheel_alignment':
        return m.copyWith(wheelAlignment: record);
      case 'spark_plugs':
        return m.copyWith(sparkPlugs: record);
      case 'coolant_flush':
        return m.copyWith(coolantFlush: record);
      case 'wiper_blades':
        return m.copyWith(wiperBlades: record);
      case 'timing_belt':
        return m.copyWith(timingBelt: record);
      case 'transmission_fluid':
        return m.copyWith(transmissionFluid: record);
      case 'brake_fluid':
        return m.copyWith(brakeFluid: record);
      case 'fuel_filter':
        return m.copyWith(fuelFilter: record);
      default:
        return m;
    }
  }

  /// Appends every record in [records] to [vehicle]'s flat history and mirrors
  /// each one into its typed slot, returning the updated vehicle.
  ///
  /// Records whose `sourceWorkOrderId` is already present in the vehicle's
  /// history for the same service type are skipped, so closing a work order
  /// twice (or logging the same job manually afterwards) cannot double-reset
  /// an interval.
  VehicleEntity applyRecords(
    VehicleEntity vehicle,
    List<TypedMaintenanceRecord> records,
  ) {
    if (records.isEmpty) return vehicle;

    final history = List<MaintenanceRecord>.from(
      vehicle.maintenanceHistory ?? const [],
    );
    var maintenance = vehicle.maintenance ?? const VehicleMaintenance();

    for (final entry in records) {
      if (_isDuplicate(history, entry.record)) continue;
      history.add(entry.record);
      maintenance = applyTypedRecord(maintenance, entry.typeId, entry.record);
    }

    return vehicle.copyWith(
      maintenanceHistory: history,
      maintenance: maintenance,
    );
  }

  bool _isDuplicate(
    List<MaintenanceRecord> history,
    MaintenanceRecord candidate,
  ) {
    final workOrderId = candidate.sourceWorkOrderId;
    if (workOrderId == null || workOrderId.isEmpty) return false;
    final type = candidate.serviceType?.toLowerCase().trim();
    return history.any(
      (r) =>
          r.sourceWorkOrderId == workOrderId &&
          (r.serviceType?.toLowerCase().trim()) == type,
    );
  }
}
