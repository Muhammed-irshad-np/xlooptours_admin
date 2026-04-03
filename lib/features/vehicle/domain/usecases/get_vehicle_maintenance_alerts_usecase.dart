import '../entities/vehicle_entity.dart';
import '../entities/maintenance_type_entity.dart';

class VehicleMaintenanceAlert {
  final VehicleEntity vehicle;
  final String category;
  final int currentMileage;
  final int lastServiceMileage;
  final int nextServiceMileage;
  final int kmOverdue;

  VehicleMaintenanceAlert({
    required this.vehicle,
    required this.category,
    required this.currentMileage,
    required this.lastServiceMileage,
    required this.nextServiceMileage,
    required this.kmOverdue,
  });
}

/// Checks every vehicle's maintenance history against the configured intervals.
/// For each [MaintenanceTypeEntity] that has records in history, it finds the
/// most recent service (highest mileage) and flags it when:
///   currentOdometer >= lastServiceMileage + intervalKm
///
/// This logic is purely history-driven — it does NOT rely on `vehicle.maintenance`
/// typed fields, so old records logged before the typed-field fix still work.
class GetVehicleMaintenanceAlertsUseCase {
  List<VehicleMaintenanceAlert> call({
    required List<VehicleEntity> vehicles,
    required List<MaintenanceTypeEntity> maintenanceTypes,
  }) {
    if (maintenanceTypes.isEmpty) return [];

    final alerts = <VehicleMaintenanceAlert>[];

    for (final vehicle in vehicles) {
      final currentMileage = vehicle.currentOdometer;
      if (currentMileage == null || currentMileage == 0) continue;

      // Collect ALL history entries (flat list + typed fields fallback).
      final allHistory = _gatherHistory(vehicle);
      if (allHistory.isEmpty) continue;

      // Group by serviceType name (case-insensitive).
      final Map<String, List<_HistoryEntry>> byType = {};
      for (final entry in allHistory) {
        final key = entry.serviceType.toLowerCase().trim();
        byType.putIfAbsent(key, () => []).add(entry);
      }

      // For each maintenance type configured, check if service is overdue.
      for (final type in maintenanceTypes) {
        if (type.defaultIntervalKm <= 0) continue;

        final key = type.name.toLowerCase().trim();
        final entries = byType[key];
        if (entries == null || entries.isEmpty) continue;

        // Find the most recent service (highest mileage).
        entries.sort((a, b) => b.mileage.compareTo(a.mileage));
        final lastService = entries.first;

        final nextDue = lastService.mileage + type.defaultIntervalKm;

        if (currentMileage >= nextDue) {
          alerts.add(
            VehicleMaintenanceAlert(
              vehicle: vehicle,
              category: type.name,
              currentMileage: currentMileage,
              lastServiceMileage: lastService.mileage,
              nextServiceMileage: nextDue,
              kmOverdue: currentMileage - nextDue,
            ),
          );
        }
      }
    }

    return alerts;
  }

  /// Gathers all maintenance records from both the flat history list and the
  /// typed `VehicleMaintenance` fields (backwards compatibility).
  List<_HistoryEntry> _gatherHistory(VehicleEntity vehicle) {
    final result = <_HistoryEntry>[];

    // Flat history (primary source — written by AddMaintenanceRecordDialog).
    for (final r in vehicle.maintenanceHistory ?? []) {
      final type = r.serviceType;
      if (type != null && type.isNotEmpty) {
        result.add(_HistoryEntry(serviceType: type, mileage: r.mileage));
      }
    }

    // Typed fields (legacy / secondary source).
    final m = vehicle.maintenance;
    if (m != null) {
      void add(dynamic record, String name) {
        if (record == null) return;
        // Avoid double-counting if already present in flat history.
        final already = result.any(
          (e) =>
              e.serviceType.toLowerCase() == name.toLowerCase() &&
              e.mileage == record.mileage,
        );
        if (!already) {
          result.add(_HistoryEntry(serviceType: name, mileage: record.mileage));
        }
      }

      add(m.engineOil, 'Engine Oil');
      add(m.gearOil, 'Gear Oil');
      add(m.housingOil, 'Housing Oil');
      add(m.tyreChange, 'Tyre Change');
      add(m.batteryChange, 'Battery Change');
      add(m.brakePads, 'Brake Pads');
      add(m.airFilter, 'Air Filter');
      add(m.acService, 'AC Service');
      add(m.wheelAlignment, 'Wheel Alignment');
      add(m.sparkPlugs, 'Spark Plugs');
      add(m.coolantFlush, 'Coolant Flush');
      add(m.wiperBlades, 'Wiper Blades');
      add(m.timingBelt, 'Timing Belt');
      add(m.transmissionFluid, 'Transmission Fluid');
      add(m.brakeFluid, 'Brake Fluid');
      add(m.fuelFilter, 'Fuel Filter');
    }

    return result;
  }
}

class _HistoryEntry {
  final String serviceType;
  final int mileage;
  _HistoryEntry({required this.serviceType, required this.mileage});
}
