import 'package:image_picker/image_picker.dart';
import '../../domain/entities/employee_entity.dart';
import '../../domain/repositories/employee_repository.dart';
import '../datasources/employee_remote_data_source.dart';
import '../models/employee_model.dart';

class EmployeeRepositoryImpl implements EmployeeRepository {
  final EmployeeRemoteDataSource remoteDataSource;

  EmployeeRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<EmployeeEntity>> getAllEmployees() async {
    return await remoteDataSource.getAllEmployees();
  }

  @override
  Future<void> insertEmployee(EmployeeEntity employee) async {
    final employeeModel = EmployeeModel.fromEntity(employee);
    await remoteDataSource.insertEmployee(employeeModel);
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
}
