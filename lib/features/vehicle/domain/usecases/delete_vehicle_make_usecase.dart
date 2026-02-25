import '../repositories/vehicle_repository.dart';

class DeleteVehicleMakeUseCase {
  final VehicleRepository repository;

  DeleteVehicleMakeUseCase(this.repository);

  Future<void> call(String id) async {
    return await repository.deleteVehicleMake(id);
  }
}
