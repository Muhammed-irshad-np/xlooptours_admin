import '../entities/maintenance_type_entity.dart';
import '../repositories/vehicle_repository.dart';

class InsertMaintenanceTypeUseCase {
  final VehicleRepository repository;

  InsertMaintenanceTypeUseCase(this.repository);

  Future<void> call(MaintenanceTypeEntity type) async {
    return await repository.insertMaintenanceType(type);
  }
}
