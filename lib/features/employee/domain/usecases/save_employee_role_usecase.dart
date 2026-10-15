import '../entities/employee_role_entity.dart';
import '../repositories/employee_repository.dart';

class SaveEmployeeRoleUseCase {
  final EmployeeRepository repository;

  SaveEmployeeRoleUseCase(this.repository);

  /// Creates or updates [role]. When [previousName] differs from the new
  /// name, employees holding the old name are moved to the new one.
  Future<void> call(EmployeeRoleEntity role, {String? previousName}) async {
    return await repository.saveEmployeeRole(role, previousName: previousName);
  }
}
