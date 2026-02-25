import '../entities/vehicle_entity.dart';
import '../repositories/vehicle_repository.dart';

class GetAllVehiclesUseCase {
  final VehicleRepository repository;

  GetAllVehiclesUseCase(this.repository);

  Future<List<VehicleEntity>> call() async {
    return await repository.getAllVehicles();
  }
}
