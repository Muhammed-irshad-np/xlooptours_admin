import 'package:image_picker/image_picker.dart';
import '../../domain/entities/employee_entity.dart';
import '../../domain/entities/employee_role_entity.dart';
import '../../domain/entities/employee_settings_entity.dart';
import '../../domain/repositories/employee_repository.dart';
import '../datasources/employee_remote_data_source.dart';
import '../models/employee_model.dart';
import '../models/employee_role_model.dart';
import '../models/employee_settings_model.dart';

class EmployeeRepositoryImpl implements EmployeeRepository {
  final EmployeeRemoteDataSource remoteDataSource;

  EmployeeRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<EmployeeEntity>> getAllEmployees() async {
    return await remoteDataSource.getAllEmployees();
  }

  @override
  Future<String> insertEmployee(EmployeeEntity employee) async {
    final employeeModel = EmployeeModel.fromEntity(employee);
    return await remoteDataSource.insertEmployee(employeeModel);
  }

  @override
  Future<int> assignMissingEmployeeCodes() async {
    return await remoteDataSource.assignMissingEmployeeCodes();
  }

  @override
  Future<void> updateEmployee(EmployeeEntity employee) async {
    final employeeModel = EmployeeModel.fromEntity(employee);
    await remoteDataSource.updateEmployee(employeeModel);
  }

  @override
  Future<void> deleteEmployee(String id) async {
    await remoteDataSource.deleteEmployee(id);
  }

  @override
  Future<String> uploadEmployeeImage(XFile image, String employeeId) async {
    return await remoteDataSource.uploadEmployeeImage(image, employeeId);
  }

  @override
  Future<String> uploadDocumentAttachment(
    XFile file,
    String employeeId,
    String docType,
  ) async {
    return await remoteDataSource.uploadDocumentAttachment(
      file,
      employeeId,
      docType,
    );
  }

  @override
  Future<EmployeeSettingsEntity> getEmployeeSettings() async {
    return await remoteDataSource.getEmployeeSettings();
  }

  @override
  Future<void> updateEmployeeSettings(EmployeeSettingsEntity settings) async {
    final model = EmployeeSettingsModel.fromEntity(settings);
    await remoteDataSource.updateEmployeeSettings(model);
  }

  @override
  Future<List<EmployeeRoleEntity>> getEmployeeRoles() async {
    return await remoteDataSource.getEmployeeRoles();
  }

  @override
  Future<void> saveEmployeeRole(
    EmployeeRoleEntity role, {
    String? previousName,
  }) async {
    await remoteDataSource.saveEmployeeRole(
      EmployeeRoleModel.fromEntity(role),
      previousName: previousName,
    );
  }

  @override
  Future<void> deleteEmployeeRole(String id) async {
    await remoteDataSource.deleteEmployeeRole(id);
  }
}
