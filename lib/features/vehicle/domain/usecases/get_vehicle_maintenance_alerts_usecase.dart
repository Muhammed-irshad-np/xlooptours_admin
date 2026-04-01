import '../entities/vehicle_entity.dart';
import '../entities/vehicle_documents.dart';

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
  List<VehicleMaintenanceAlert> call(List<VehicleEntity> vehicles) {
    final alerts = <VehicleMaintenanceAlert>[];

    for (final vehicle in vehicles) {
      final maintenance = vehicle.maintenance;
      if (maintenance == null) continue;

      final currentMileage = vehicle.currentOdometer ?? 0;

      _checkRecord(alerts, vehicle, 'Engine Oil', maintenance.engineOil, currentMileage);
      _checkRecord(alerts, vehicle, 'Gear Oil', maintenance.gearOil, currentMileage);
      _checkRecord(alerts, vehicle, 'Housing Oil', maintenance.housingOil, currentMileage);
      _checkRecord(alerts, vehicle, 'Tyre Change', maintenance.tyreChange, currentMileage);
      _checkRecord(alerts, vehicle, 'Battery Change', maintenance.batteryChange, currentMileage);
      _checkRecord(alerts, vehicle, 'Brake Pads', maintenance.brakePads, currentMileage);
      _checkRecord(alerts, vehicle, 'Air Filter', maintenance.airFilter, currentMileage);
      _checkRecord(alerts, vehicle, 'AC Service', maintenance.acService, currentMileage);
      _checkRecord(alerts, vehicle, 'Wheel Alignment', maintenance.wheelAlignment, currentMileage);
      _checkRecord(alerts, vehicle, 'Spark Plugs', maintenance.sparkPlugs, currentMileage);
      _checkRecord(alerts, vehicle, 'Coolant Flush', maintenance.coolantFlush, currentMileage);
      _checkRecord(alerts, vehicle, 'Wiper Blades', maintenance.wiperBlades, currentMileage);
      _checkRecord(alerts, vehicle, 'Timing Belt', maintenance.timingBelt, currentMileage);
      _checkRecord(alerts, vehicle, 'Transmission Fluid', maintenance.transmissionFluid, currentMileage);
      _checkRecord(alerts, vehicle, 'Brake Fluid', maintenance.brakeFluid, currentMileage);
      _checkRecord(alerts, vehicle, 'Fuel Filter', maintenance.fuelFilter, currentMileage);
    }

    return alerts;
  }

  void _checkRecord(
    List<VehicleMaintenanceAlert> alerts,
    VehicleEntity vehicle,
    String category,
    MaintenanceRecord? record,
    int currentMileage,
  ) {
    if (record != null && record.nextServiceMileage != null) {
      if (currentMileage >= record.nextServiceMileage!) {
        alerts.add(VehicleMaintenanceAlert(
          vehicle: vehicle,
          category: category,
          currentMileage: currentMileage,
          nextServiceMileage: record.nextServiceMileage!,
        ));
      }
    }
  }
}
