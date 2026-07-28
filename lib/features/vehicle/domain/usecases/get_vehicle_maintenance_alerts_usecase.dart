import '../entities/vehicle_entity.dart';
import '../entities/maintenance_type_entity.dart';
import '../entities/vehicle_documents.dart';

class VehicleMaintenanceAlert {
  final VehicleEntity vehicle;
  final String category;
  final int currentMileage;
  final int lastServiceMileage;
  final int nextServiceMileage;
  final int kmOverdue;
  final bool isExtended;
  final List<MaintenanceRecord> extensionHistory;
  final int originalDueMileage;

  // Date trigger fields
  final String triggerType;
  final DateTime? lastServiceDate;
  final DateTime? nextServiceDate;
  final int? daysOverdue;
  final int? daysRemaining;

  // Shop / Provider field
  final String? shopName;

  VehicleMaintenanceAlert({
    required this.vehicle,
    required this.category,
    required this.currentMileage,
    required this.lastServiceMileage,
    required this.nextServiceMileage,
    required this.kmOverdue,
    this.isExtended = false,
    this.extensionHistory = const [],
    required this.originalDueMileage,
    this.triggerType = 'odometer',
    this.lastServiceDate,
    this.nextServiceDate,
    this.daysOverdue,
    this.daysRemaining,
    this.shopName,
  });

  bool get isDateTrigger => triggerType == 'date';
}

/// Checks every vehicle's maintenance history against the configured intervals.
/// For each [MaintenanceTypeEntity] that has records in history, it flags overdue services:
/// - Odometer trigger: currentOdometer >= lastServiceMileage + intervalKm
/// - Date trigger: DateTime.now() >= lastServiceDate + interval (months/weeks/days)
class GetVehicleMaintenanceAlertsUseCase {
  List<VehicleMaintenanceAlert> call({
    required List<VehicleEntity> vehicles,
    required List<MaintenanceTypeEntity> maintenanceTypes,
    bool includeAll = false,
  }) {
    if (maintenanceTypes.isEmpty) return [];

    final alerts = <VehicleMaintenanceAlert>[];

    for (final vehicle in vehicles) {
      final currentMileage = vehicle.currentOdometer ?? 0;

      // Collect ALL history entries (flat list + typed fields fallback).
      final allHistory = _gatherHistory(vehicle);
      if (allHistory.isEmpty) continue;

      // Group by serviceType name (case-insensitive, normalized).
      final Map<String, List<_HistoryEntry>> byType = {};
      for (final entry in allHistory) {
        final key = _normalizeServiceType(entry.serviceType);
        byType.putIfAbsent(key, () => []).add(entry);
      }

      // For each maintenance type configured, check if service is overdue.
      for (final type in maintenanceTypes) {
        final key = _normalizeServiceType(type.name);
        final entries = byType[key];
        if (entries == null || entries.isEmpty) continue;

        final serviceEntries = entries
            .where((e) => !e.serviceType.startsWith('Extension:'))
            .toList();

        if (serviceEntries.isEmpty) continue;

        if (type.isDateTrigger) {
          // --- DATE-BASED TRIGGER ---
          // Sort entries by date descending to find the most recent service
          serviceEntries.sort((a, b) {
            final dateA = a.originalRecord?.date ?? DateTime(2000);
            final dateB = b.originalRecord?.date ?? DateTime(2000);
            return dateB.compareTo(dateA);
          });
          final lastService = serviceEntries.first;
          final lastDate = lastService.originalRecord?.date;

          DateTime? targetDueDate =
              lastService.originalRecord?.nextServiceDate;

          final extensionHistory = <MaintenanceRecord>[];
          if (vehicle.maintenanceHistory != null) {
            for (final record in vehicle.maintenanceHistory!) {
              if (record.serviceType != null) {
                final normRecordType = _normalizeServiceType(record.serviceType!);
                final normCat = _normalizeServiceType(type.name);

                if (record.serviceType!.startsWith('Extension:') &&
                    normRecordType.replaceFirst('extension: ', '') == normCat) {
                  if (record.date.isAfter(lastService.originalRecord?.date ?? DateTime(2000)) ||
                      (record.date.isAtSameMomentAs(lastService.originalRecord?.date ?? DateTime(2000)))) {
                    extensionHistory.add(record);
                  }
                }
              }
            }
            extensionHistory.sort((a, b) => a.date.compareTo(b.date));
          }

          bool isExt = false;
          if (lastService.originalRecord != null &&
              lastService.originalRecord!.isExtended == true &&
              lastService.originalRecord!.nextServiceDate != null) {
            targetDueDate = lastService.originalRecord!.nextServiceDate!;
            isExt = true;
          }

          if (targetDueDate == null) continue;

          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final dueDay = DateTime(
            targetDueDate.year,
            targetDueDate.month,
            targetDueDate.day,
          );

          final diffDays = today.difference(dueDay).inDays;

          if (includeAll || diffDays >= 0) {
            alerts.add(
              VehicleMaintenanceAlert(
                vehicle: vehicle,
                category: type.name,
                currentMileage: currentMileage,
                lastServiceMileage: lastService.mileage,
                nextServiceMileage: 0,
                kmOverdue: 0,
                isExtended: isExt,
                extensionHistory: extensionHistory,
                originalDueMileage: 0,
                triggerType: 'date',
                lastServiceDate: lastDate,
                nextServiceDate: targetDueDate,
                daysOverdue: diffDays > 0 ? diffDays : 0,
                daysRemaining: diffDays < 0 ? -diffDays : 0,
                shopName: lastService.originalRecord?.serviceProvider,
              ),
            );
          }
        } else {
          // --- ODOMETER-BASED TRIGGER ---
          if (currentMileage == 0) continue;

          final String vType = vehicle.type.toLowerCase();
          final int intervalKm = vType.contains('sedan')
              ? type.sedanIntervalKm
              : type.suvIntervalKm;

          if (intervalKm <= 0) continue;

          serviceEntries.sort((a, b) => b.mileage.compareTo(a.mileage));
          final lastService = serviceEntries.first;

          final originalDue = lastService.mileage + intervalKm;
          int nextDue = originalDue;
          bool isExt = false;

          final extensionHistory = <MaintenanceRecord>[];
          if (vehicle.maintenanceHistory != null) {
            for (final record in vehicle.maintenanceHistory!) {
              if (record.serviceType != null) {
                final normRecordType = _normalizeServiceType(record.serviceType!);
                final normCat = _normalizeServiceType(type.name);

                if (record.serviceType!.startsWith('Extension:') &&
                    normRecordType.replaceFirst('extension: ', '') == normCat) {
                  if (record.date.isAfter(lastService.originalRecord?.date ?? DateTime(2000)) ||
                      (record.date.isAtSameMomentAs(lastService.originalRecord?.date ?? DateTime(2000))) ||
                      record.mileage >= lastService.mileage) {
                    extensionHistory.add(record);
                  }
                }
              }
            }
            extensionHistory.sort((a, b) => a.date.compareTo(b.date));
          }

          if (lastService.originalRecord != null &&
              lastService.originalRecord!.isExtended == true &&
              lastService.originalRecord!.nextServiceMileage != null) {
            nextDue = lastService.originalRecord!.nextServiceMileage!;
            isExt = true;
          }

          if (includeAll || currentMileage >= nextDue) {
            alerts.add(
              VehicleMaintenanceAlert(
                vehicle: vehicle,
                category: type.name,
                currentMileage: currentMileage,
                lastServiceMileage: lastService.mileage,
                nextServiceMileage: nextDue,
                kmOverdue: currentMileage - nextDue,
                isExtended: isExt,
                extensionHistory: extensionHistory,
                originalDueMileage: originalDue,
                triggerType: 'odometer',
                lastServiceDate: lastService.originalRecord?.date,
                shopName: lastService.originalRecord?.serviceProvider,
              ),
            );
          }
        }
      }
    }

    return alerts;
  }

  String _normalizeServiceType(String type) {
    final t = type.toLowerCase().trim();
    if (t == 'engine oil' ||
        t == 'engine oil change' ||
        t == 'oil filter' ||
        t == 'engine oil & filter') {
      return 'engine oil & filter';
    }
    return t;
  }

  /// Gathers all maintenance records from both the flat history list and the
  /// typed `VehicleMaintenance` fields (backwards compatibility).
  List<_HistoryEntry> _gatherHistory(VehicleEntity vehicle) {
    final result = <_HistoryEntry>[];

    // Flat history (primary source — written by AddMaintenanceRecordDialog).
    for (final r in vehicle.maintenanceHistory ?? []) {
      final type = r.serviceType;
      if (type != null && type.isNotEmpty) {
        result.add(_HistoryEntry(serviceType: type, mileage: r.mileage, originalRecord: r));
      }
    }

    // Typed fields (legacy / secondary source).
    final m = vehicle.maintenance;
    if (m != null) {
      void add(MaintenanceRecord? record, String name) {
        if (record == null) return;
        // Avoid double-counting if already present in flat history.
        final already = result.any(
          (e) =>
              e.serviceType.toLowerCase() == name.toLowerCase() &&
              e.mileage == record.mileage,
        );
        if (!already) {
          result.add(_HistoryEntry(serviceType: name, mileage: record.mileage, originalRecord: record));
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
  final MaintenanceRecord? originalRecord;
  _HistoryEntry({required this.serviceType, required this.mileage, this.originalRecord});
}
