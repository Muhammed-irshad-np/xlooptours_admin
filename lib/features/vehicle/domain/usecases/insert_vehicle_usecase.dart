import '../entities/vehicle_entity.dart';
import '../repositories/vehicle_repository.dart';

class InsertVehicleUseCase {
  final VehicleRepository repository;

  InsertVehicleUseCase(this.repository);

  Future<void> call(VehicleEntity vehicle) async {
    return await repository.insertVehicle(vehicle);
  }
}
