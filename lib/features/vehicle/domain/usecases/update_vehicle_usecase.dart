import '../entities/vehicle_entity.dart';
import '../repositories/vehicle_repository.dart';

class UpdateVehicleUseCase {
  final VehicleRepository repository;

  UpdateVehicleUseCase(this.repository);

  Future<void> call(VehicleEntity vehicle) async {
    return await repository.updateVehicle(vehicle);
  }
}
