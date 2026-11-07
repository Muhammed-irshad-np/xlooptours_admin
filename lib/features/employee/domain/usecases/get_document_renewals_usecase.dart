import '../entities/document_renewal_entity.dart';
import '../repositories/employee_repository.dart';

class GetDocumentRenewalsUseCase {
  final EmployeeRepository repository;

  GetDocumentRenewalsUseCase(this.repository);

  /// Renewal history for one employee, newest first, voided entries removed.
  Future<List<DocumentRenewalEntity>> call(String employeeId) async {
    return await repository.getDocumentRenewals(employeeId);
  }
}
