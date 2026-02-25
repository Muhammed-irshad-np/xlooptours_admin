import '../entities/employee_entity.dart';
import '../repositories/employee_repository.dart';

class UpdateEmployeeUseCase {
  final EmployeeRepository repository;

  UpdateEmployeeUseCase(this.repository);

  Future<void> call(EmployeeEntity employee) async {
    return await repository.updateEmployee(employee);
  }
}
