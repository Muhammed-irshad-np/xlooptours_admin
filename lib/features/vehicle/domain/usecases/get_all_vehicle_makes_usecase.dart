import '../entities/vehicle_make_entity.dart';
import '../repositories/vehicle_repository.dart';

class GetAllVehicleMakesUseCase {
  final VehicleRepository repository;

  GetAllVehicleMakesUseCase(this.repository);

  Future<List<VehicleMakeEntity>> call() async {
    return await repository.getAllVehicleMakes();
  }
}
