import '../entities/vehicle_entity.dart';
import '../entities/vehicle_documents.dart';
import '../repositories/vehicle_repository.dart';

class ExtendVehicleMaintenanceUseCase {
  final VehicleRepository repository;

  ExtendVehicleMaintenanceUseCase(this.repository);

  Future<void> call({
    required VehicleEntity vehicle,
    required String category,
    required int extensionKm,
    required String reason,
    String? performedBy,
    int? baseOdometer,
  }) async {
    final currentOdometer = vehicle.currentOdometer ?? 0;
    final List<MaintenanceRecord> updatedHistory = List.from(vehicle.maintenanceHistory ?? []);

    // 1. Find and update the latest actual MaintenanceRecord in history for this category
    MaintenanceRecord? latestRecord;
    int latestIndex = -1;

    for (int i = 0; i < updatedHistory.length; i++) {
      final record = updatedHistory[i];
      if (record.serviceType != null && _isMatchingCategory(record.serviceType!, category)) {
        // We want to avoid matching previous extension logs (e.g., serviceType starts with "Extension:")
        if (record.serviceType!.startsWith('Extension:')) continue;

        if (latestRecord == null || record.mileage > latestRecord.mileage) {
          latestRecord = record;
          latestIndex = i;
        }
      }
    }

    final resolvedBaseOdometer = baseOdometer ?? (latestRecord?.nextServiceMileage ?? currentOdometer);
    final newAlertThreshold = resolvedBaseOdometer + extensionKm;

    MaintenanceRecord updatedRecord;
    if (latestRecord != null) {
      updatedRecord = latestRecord.copyWith(
        isExtended: true,
        extendedMileage: extensionKm,
        extensionReason: reason,
        nextServiceMileage: newAlertThreshold,
        performedBy: performedBy,
      );
      updatedHistory[latestIndex] = updatedRecord;
    } else {
      // Fallback: If no history record exists, create one starting from 0 or purchase odometer
      updatedRecord = MaintenanceRecord(
        date: DateTime.now(),
        mileage: vehicle.purchaseOdometer ?? 0,
        serviceType: category,
        isExtended: true,
        extendedMileage: extensionKm,
        extensionReason: reason,
        nextServiceMileage: newAlertThreshold,
        performedBy: performedBy,
      );
      updatedHistory.add(updatedRecord);
    }

    // 2. Add an audit log entry to the history list
    final auditRecord = MaintenanceRecord(
      date: DateTime.now(),
      mileage: currentOdometer,
      serviceType: 'Extension: $category',
      notes: 'Alert extended by $extensionKm km. New due mileage: $newAlertThreshold km. Reason: $reason',
      cost: 0.0,
      performedBy: performedBy,
    );
    updatedHistory.add(auditRecord);

    // 3. Also update the active typed field in vehicle.maintenance
    final existingMaintenance = vehicle.maintenance ?? const VehicleMaintenance();
    final updatedMaintenance = _applyExtensionToTypedField(
      existingMaintenance,
      category,
      updatedRecord,
    );

    // 4. Save to repository
    final updatedVehicle = vehicle.copyWith(
      maintenanceHistory: updatedHistory,
      maintenance: updatedMaintenance,
    );

    await repository.updateVehicle(updatedVehicle);
  }

  bool _isMatchingCategory(String serviceType, String category) {
    final s = serviceType.toLowerCase().trim();
    final c = category.toLowerCase().trim();
    if (s == c) return true;
    
    // Normalize engine oil variants
    final engineOilKeywords = ['engine oil', 'engine oil change', 'oil filter', 'engine oil & filter', 'engine_oil'];
    if (engineOilKeywords.contains(s) && engineOilKeywords.contains(c)) {
      return true;
    }
    
    // Normalize space vs underscore differences
    return s.replaceAll(' ', '_') == c.replaceAll(' ', '_');
  }

  VehicleMaintenance _applyExtensionToTypedField(
    VehicleMaintenance m,
    String category,
    MaintenanceRecord updatedRecord,
  ) {
    final norm = category.toLowerCase().trim();
    if (norm == 'engine oil' || norm == 'engine oil change' || norm == 'engine_oil' || norm.contains('engine oil') || norm == 'engine oil & filter') {
      return m.copyWith(engineOil: updatedRecord);
    }
    if (norm == 'gear oil' || norm == 'gear_oil') {
      return m.copyWith(gearOil: updatedRecord);
    }
    if (norm == 'housing oil' || norm == 'housing_oil') {
      return m.copyWith(housingOil: updatedRecord);
    }
    if (norm == 'tyre change' || norm == 'tyre_change') {
      return m.copyWith(tyreChange: updatedRecord);
    }
    if (norm == 'battery change' || norm == 'battery_change') {
      return m.copyWith(batteryChange: updatedRecord);
    }
    if (norm == 'brake pads' || norm == 'brake_pads') {
      return m.copyWith(brakePads: updatedRecord);
    }
    if (norm == 'air filter' || norm == 'air_filter') {
      return m.copyWith(airFilter: updatedRecord);
    }
    if (norm == 'ac service' || norm == 'ac_service') {
      return m.copyWith(acService: updatedRecord);
    }
    if (norm == 'wheel alignment' || norm == 'wheel_alignment') {
      return m.copyWith(wheelAlignment: updatedRecord);
    }
    if (norm == 'spark plugs' || norm == 'spark_plugs') {
      return m.copyWith(sparkPlugs: updatedRecord);
    }
    if (norm == 'coolant flush' || norm == 'coolant_flush') {
      return m.copyWith(coolantFlush: updatedRecord);
    }
    if (norm == 'wiper blades' || norm == 'wiper_blades') {
      return m.copyWith(wiperBlades: updatedRecord);
    }
    if (norm == 'timing belt' || norm == 'timing_belt') {
      return m.copyWith(timingBelt: updatedRecord);
    }
    if (norm == 'transmission fluid' || norm == 'transmission_fluid') {
      return m.copyWith(transmissionFluid: updatedRecord);
    }
    if (norm == 'brake fluid' || norm == 'brake_fluid') {
      return m.copyWith(brakeFluid: updatedRecord);
    }
    if (norm == 'fuel filter' || norm == 'fuel_filter') {
      return m.copyWith(fuelFilter: updatedRecord);
    }
    return m;
  }
}
