import 'package:image_picker/image_picker.dart';
import '../entities/employee_entity.dart';

abstract class EmployeeRepository {
  Future<List<EmployeeEntity>> getAllEmployees();
  Future<void> insertEmployee(EmployeeEntity employee);
  Future<void> updateEmployee(EmployeeEntity employee);
  Future<void> deleteEmployee(String id);
  Future<String> uploadEmployeeImage(XFile image, String employeeId);
}
