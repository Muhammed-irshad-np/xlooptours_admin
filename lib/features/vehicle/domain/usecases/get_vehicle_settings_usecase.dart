import '../entities/vehicle_settings_entity.dart';
import '../repositories/vehicle_repository.dart';

class GetVehicleSettingsUseCase {
  final VehicleRepository repository;

  GetVehicleSettingsUseCase(this.repository);

  Future<VehicleSettingsEntity> call() async {
    return await repository.getVehicleSettings();
  }
}
