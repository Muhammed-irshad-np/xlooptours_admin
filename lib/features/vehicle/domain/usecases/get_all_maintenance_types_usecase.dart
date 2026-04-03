import '../entities/maintenance_type_entity.dart';
import '../repositories/vehicle_repository.dart';

class GetAllMaintenanceTypesUseCase {
  final VehicleRepository repository;

  GetAllMaintenanceTypesUseCase(this.repository);

  Future<List<MaintenanceTypeEntity>> call() async {
    return await repository.getAllMaintenanceTypes();
  }
}
