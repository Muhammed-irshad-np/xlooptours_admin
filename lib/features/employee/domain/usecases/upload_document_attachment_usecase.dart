import 'package:image_picker/image_picker.dart';
import '../../domain/repositories/employee_repository.dart';

/// UseCase: Upload a scanned document attachment for an employee.
class UploadDocumentAttachmentUseCase {
  final EmployeeRepository repository;
  UploadDocumentAttachmentUseCase(this.repository);

  Future<String> call(XFile file, String employeeId, String docType) {
    return repository.uploadDocumentAttachment(file, employeeId, docType);
  }
}
