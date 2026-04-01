import '../entities/vehicle_entity.dart';

class GetVehiclesNeedingOdometerUpdateUseCase {
  List<VehicleEntity> call(List<VehicleEntity> vehicles) {
    final now = DateTime.now();
    return vehicles.where((vehicle) {
      if (vehicle.lastOdometerUpdateDate == null) return true;
      final difference = now.difference(vehicle.lastOdometerUpdateDate!);
      return difference.inDays >= 7;
    }).toList();
  }
}
