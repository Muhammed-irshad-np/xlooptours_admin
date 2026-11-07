import '../entities/document_renewal_entity.dart';
import '../entities/employee_entity.dart';
import '../repositories/employee_repository.dart';

class UpdateEmployeeUseCase {
  final EmployeeRepository repository;

  UpdateEmployeeUseCase(this.repository);

  /// Saves [employee] together with any [renewals] in one write, and marks the
  /// renewals in [voidRenewalIds] as voided (used when rolling an edit back).
  Future<void> call(
    EmployeeEntity employee, {
    List<DocumentRenewalEntity> renewals = const [],
    List<String> voidRenewalIds = const [],
  }) async {
    return await repository.updateEmployee(
      employee,
      renewals: renewals,
      voidRenewalIds: voidRenewalIds,
    );
  }
}
