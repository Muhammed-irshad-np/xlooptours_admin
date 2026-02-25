import '../repositories/vehicle_repository.dart';

class DeleteVehicleUseCase {
  final VehicleRepository repository;

  DeleteVehicleUseCase(this.repository);

  Future<void> call(String id) async {
    return await repository.deleteVehicle(id);
  }
}
