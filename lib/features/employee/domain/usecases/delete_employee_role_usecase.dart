import '../repositories/employee_repository.dart';

class DeleteEmployeeRoleUseCase {
  final EmployeeRepository repository;

  DeleteEmployeeRoleUseCase(this.repository);

  Future<void> call(String id) async {
    return await repository.deleteEmployeeRole(id);
  }
}
