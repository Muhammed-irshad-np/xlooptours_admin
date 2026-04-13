import '../entities/vehicle_settings_entity.dart';
import '../repositories/vehicle_repository.dart';

class UpdateVehicleSettingsUseCase {
  final VehicleRepository repository;

  UpdateVehicleSettingsUseCase(this.repository);

  Future<void> call(VehicleSettingsEntity settings) async {
    return await repository.updateVehicleSettings(settings);
  }
}
