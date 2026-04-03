import '../entities/maintenance_type_entity.dart';
import '../repositories/vehicle_repository.dart';

class UpdateMaintenanceTypeUseCase {
  final VehicleRepository repository;

  UpdateMaintenanceTypeUseCase(this.repository);

  Future<void> call(MaintenanceTypeEntity type) async {
    return await repository.updateMaintenanceType(type);
  }
}
