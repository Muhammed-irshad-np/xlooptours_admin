import '../entities/vehicle_entity.dart';
import '../repositories/vehicle_repository.dart';

class ModifyVehicleUseCase {
  final VehicleRepository repository;

  ModifyVehicleUseCase(this.repository);

  Future<VehicleEntity> call(
    String vehicleId,
    VehicleEntity Function(VehicleEntity latest) change,
  ) async {
    return await repository.modifyVehicle(vehicleId, change);
  }
}
