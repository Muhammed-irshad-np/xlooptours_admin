import '../entities/vehicle_make_entity.dart';
import '../repositories/vehicle_repository.dart';

class UpdateVehicleMakeUseCase {
  final VehicleRepository repository;

  UpdateVehicleMakeUseCase(this.repository);

  Future<void> call(VehicleMakeEntity make) async {
    return await repository.updateVehicleMake(make);
  }
}
