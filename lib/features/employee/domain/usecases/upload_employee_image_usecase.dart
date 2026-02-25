import 'package:image_picker/image_picker.dart';
import '../repositories/employee_repository.dart';

class UploadEmployeeImageUseCase {
  final EmployeeRepository repository;

  UploadEmployeeImageUseCase(this.repository);

  Future<String> call(XFile image, String employeeId) async {
    return await repository.uploadEmployeeImage(image, employeeId);
  }
}
