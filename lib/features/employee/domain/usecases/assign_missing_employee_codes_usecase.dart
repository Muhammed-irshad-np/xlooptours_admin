import '../repositories/employee_repository.dart';

class AssignMissingEmployeeCodesUseCase {
  final EmployeeRepository repository;

  AssignMissingEmployeeCodesUseCase(this.repository);

  Future<int> call() async {
    return await repository.assignMissingEmployeeCodes();
  }
}
