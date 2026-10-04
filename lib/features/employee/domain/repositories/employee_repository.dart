import 'package:image_picker/image_picker.dart';
import '../entities/employee_entity.dart';
import '../entities/employee_settings_entity.dart';

abstract class EmployeeRepository {
  Future<List<EmployeeEntity>> getAllEmployees();
  /// Returns the employee code issued to the new record.
  Future<String> insertEmployee(EmployeeEntity employee);
  Future<int> ensureEmployeeCodes();
  Future<void> updateEmployee(EmployeeEntity employee);
  Future<void> deleteEmployee(String id);
  Future<String> uploadEmployeeImage(XFile image, String employeeId);
  Future<String> uploadDocumentAttachment(
    XFile file,
    String employeeId,
    String docType,
  );
  Future<EmployeeSettingsEntity> getEmployeeSettings();
  Future<void> updateEmployeeSettings(EmployeeSettingsEntity settings);
}
