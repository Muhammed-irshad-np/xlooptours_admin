import '../entities/employee_role_entity.dart';
import '../repositories/employee_repository.dart';

class GetEmployeeRolesUseCase {
  final EmployeeRepository repository;

  GetEmployeeRolesUseCase(this.repository);

  Future<List<EmployeeRoleEntity>> call() async {
    return await repository.getEmployeeRoles();
  }
}
