import '../entities/vehicle_entity.dart';
import '../entities/vehicle_documents.dart';
import '../entities/maintenance_type_entity.dart';

class VehicleMaintenanceAlert {
  final VehicleEntity vehicle;
  final String category;
  final int currentMileage;
  final int nextServiceMileage;

  VehicleMaintenanceAlert({
    required this.vehicle,
    required this.category,
    required this.currentMileage,
    required this.nextServiceMileage,
  });
}

class GetVehicleMaintenanceAlertsUseCase {
  List<VehicleMaintenanceAlert> call({
    required List<VehicleEntity> vehicles,
    required List<MaintenanceTypeEntity> maintenanceTypes,
  }) {
    final alerts = <VehicleMaintenanceAlert>[];

    for (final vehicle in vehicles) {
      final maintenance = vehicle.maintenance;
      if (maintenance == null) continue;

      final currentMileage = vehicle.currentOdometer ?? 0;

      _checkRecord(
        alerts,
        vehicle,
        'Engine Oil',
        'engine_oil',
        maintenance.engineOil,
        currentMileage,
        maintenanceTypes,
      );
      _checkRecord(
        alerts,
        vehicle,
        'Gear Oil',
        'gear_oil',
        maintenance.gearOil,
        currentMileage,
        maintenanceTypes,
      );
      _checkRecord(
        alerts,
        vehicle,
        'Housing Oil',
        'housing_oil',
        maintenance.housingOil,
        currentMileage,
        maintenanceTypes,
      );
      _checkRecord(
        alerts,
        vehicle,
        'Tyre Change',
        'tyre_change',
        maintenance.tyreChange,
        currentMileage,
        maintenanceTypes,
      );
      _checkRecord(
        alerts,
        vehicle,
        'Battery Change',
        'battery_change',
        maintenance.batteryChange,
        currentMileage,
        maintenanceTypes,
      );
      _checkRecord(
        alerts,
        vehicle,
        'Brake Pads',
        'brake_pads',
        maintenance.brakePads,
        currentMileage,
        maintenanceTypes,
      );
      _checkRecord(
        alerts,
        vehicle,
        'Air Filter',
        'air_filter',
        maintenance.airFilter,
        currentMileage,
        maintenanceTypes,
      );
      _checkRecord(
        alerts,
        vehicle,
        'AC Service',
        'ac_service',
        maintenance.acService,
        currentMileage,
        maintenanceTypes,
      );
      _checkRecord(
        alerts,
        vehicle,
        'Wheel Alignment',
        'wheel_alignment',
        maintenance.wheelAlignment,
        currentMileage,
        maintenanceTypes,
      );
      _checkRecord(
        alerts,
        vehicle,
        'Spark Plugs',
        'spark_plugs',
        maintenance.sparkPlugs,
        currentMileage,
        maintenanceTypes,
      );
      _checkRecord(
        alerts,
        vehicle,
        'Coolant Flush',
        'coolant_flush',
        maintenance.coolantFlush,
        currentMileage,
        maintenanceTypes,
      );
      _checkRecord(
        alerts,
        vehicle,
        'Wiper Blades',
        'wiper_blades',
        maintenance.wiperBlades,
        currentMileage,
        maintenanceTypes,
      );
      _checkRecord(
        alerts,
        vehicle,
        'Timing Belt',
        'timing_belt',
        maintenance.timingBelt,
        currentMileage,
        maintenanceTypes,
      );
      _checkRecord(
        alerts,
        vehicle,
        'Transmission Fluid',
        'transmission_fluid',
        maintenance.transmissionFluid,
        currentMileage,
        maintenanceTypes,
      );
      _checkRecord(
        alerts,
        vehicle,
        'Brake Fluid',
        'brake_fluid',
        maintenance.brakeFluid,
        currentMileage,
        maintenanceTypes,
      );
      _checkRecord(
        alerts,
        vehicle,
        'Fuel Filter',
        'fuel_filter',
        maintenance.fuelFilter,
        currentMileage,
        maintenanceTypes,
      );
    }

    return alerts;
  }

  void _checkRecord(
    List<VehicleMaintenanceAlert> alerts,
    VehicleEntity vehicle,
    String category,
    String typeId,
    MaintenanceRecord? record,
    int currentMileage,
    List<MaintenanceTypeEntity> maintenanceTypes,
  ) {
    if (record != null) {
      final typeIndex = maintenanceTypes.indexWhere((t) => t.id == typeId);
      final interval = typeIndex >= 0
          ? maintenanceTypes[typeIndex].defaultIntervalKm
          : 0;

      final nextServiceMileage =
          record.nextServiceMileage ??
          (interval > 0 ? record.mileage + interval : null);

      if (nextServiceMileage != null && currentMileage >= nextServiceMileage) {
        alerts.add(
          VehicleMaintenanceAlert(
            vehicle: vehicle,
            category: category,
            currentMileage: currentMileage,
            nextServiceMileage: nextServiceMileage,
          ),
        );
      }
    }
  }
}
