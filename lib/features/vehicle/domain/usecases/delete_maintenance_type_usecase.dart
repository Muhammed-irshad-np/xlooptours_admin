import '../repositories/vehicle_repository.dart';

class DeleteMaintenanceTypeUseCase {
  final VehicleRepository repository;

  DeleteMaintenanceTypeUseCase(this.repository);

  Future<void> call(String id) async {
    return await repository.deleteMaintenanceType(id);
  }
}
