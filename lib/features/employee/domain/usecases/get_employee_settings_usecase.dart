import '../entities/employee_settings_entity.dart';
import '../repositories/employee_repository.dart';

class GetEmployeeSettingsUseCase {
  final EmployeeRepository repository;

  GetEmployeeSettingsUseCase(this.repository);

  Future<EmployeeSettingsEntity> call() async {
    return await repository.getEmployeeSettings();
  }
}
