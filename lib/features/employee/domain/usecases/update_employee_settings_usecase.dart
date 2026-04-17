import '../entities/employee_settings_entity.dart';
import '../repositories/employee_repository.dart';

class UpdateEmployeeSettingsUseCase {
  final EmployeeRepository repository;

  UpdateEmployeeSettingsUseCase(this.repository);

  Future<void> call(EmployeeSettingsEntity settings) async {
    return await repository.updateEmployeeSettings(settings);
  }
}
