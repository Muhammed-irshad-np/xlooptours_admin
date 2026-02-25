import '../entities/employee_entity.dart';
import '../repositories/employee_repository.dart';

class GetAllEmployeesUseCase {
  final EmployeeRepository repository;

  GetAllEmployeesUseCase(this.repository);

  Future<List<EmployeeEntity>> call() async {
    return await repository.getAllEmployees();
  }
}
