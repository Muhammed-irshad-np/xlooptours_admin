import '../repositories/vehicle_repository.dart';

class AssignDriverToVehicleUseCase {
  final VehicleRepository repository;

  AssignDriverToVehicleUseCase(this.repository);

  Future<void> call(String? vehicleId, String driverId) async {
    return await repository.assignDriverToVehicle(vehicleId, driverId);
  }
}
