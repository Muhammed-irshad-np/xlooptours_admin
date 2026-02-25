import '../entities/vehicle_make_entity.dart';
import '../repositories/vehicle_repository.dart';

class InsertVehicleMakeUseCase {
  final VehicleRepository repository;

  InsertVehicleMakeUseCase(this.repository);

  Future<void> call(VehicleMakeEntity make) async {
    return await repository.insertVehicleMake(make);
  }
}
