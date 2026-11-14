import '../repositories/employee_repository.dart';

class EnsureEmployeeCodesUseCase {
  final EmployeeRepository repository;

  EnsureEmployeeCodesUseCase(this.repository);

  Future<int> call() async {
    return await repository.ensureEmployeeCodes();
  }
}
