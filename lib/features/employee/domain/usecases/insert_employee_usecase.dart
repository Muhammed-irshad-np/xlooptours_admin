import '../entities/employee_entity.dart';
import '../repositories/employee_repository.dart';

class InsertEmployeeUseCase {
  final EmployeeRepository repository;

  InsertEmployeeUseCase(this.repository);

  /// Returns the employee code issued to the new record.
  Future<String> call(EmployeeEntity employee) async {
    return await repository.insertEmployee(employee);
  }
}
