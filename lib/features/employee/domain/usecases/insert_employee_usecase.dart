import '../entities/employee_entity.dart';
import '../repositories/employee_repository.dart';

class InsertEmployeeUseCase {
  final EmployeeRepository repository;

  InsertEmployeeUseCase(this.repository);

  Future<void> call(EmployeeEntity employee) async {
    return await repository.insertEmployee(employee);
  }
}
