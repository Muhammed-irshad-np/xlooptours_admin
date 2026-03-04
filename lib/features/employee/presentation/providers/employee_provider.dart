import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/employee_entity.dart';
import '../../domain/usecases/delete_employee_usecase.dart';
import '../../domain/usecases/get_all_employees_usecase.dart';
import '../../domain/usecases/insert_employee_usecase.dart';
import '../../domain/usecases/update_employee_usecase.dart';
import '../../domain/usecases/upload_document_attachment_usecase.dart';
import '../../domain/usecases/upload_employee_image_usecase.dart';

class EmployeeProvider with ChangeNotifier {
  final GetAllEmployeesUseCase getAllEmployeesUseCase;
  final InsertEmployeeUseCase insertEmployeeUseCase;
  final UpdateEmployeeUseCase updateEmployeeUseCase;
  final DeleteEmployeeUseCase deleteEmployeeUseCase;
  final UploadEmployeeImageUseCase uploadEmployeeImageUseCase;
  final UploadDocumentAttachmentUseCase uploadDocumentAttachmentUseCase;

  EmployeeProvider({
    required this.getAllEmployeesUseCase,
    required this.insertEmployeeUseCase,
    required this.updateEmployeeUseCase,
    required this.deleteEmployeeUseCase,
    required this.uploadEmployeeImageUseCase,
    required this.uploadDocumentAttachmentUseCase,
  });

  List<EmployeeEntity> _employees = [];
  bool _isLoading = false;
  String? _error;

  List<EmployeeEntity> get employees => _employees;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchAllEmployees() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final fetchedEmployees = await getAllEmployeesUseCase();
      _employees = List<EmployeeEntity>.from(fetchedEmployees);
    } catch (e) {
      _error = e.toString();
      debugPrint('Error fetching employees: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addEmployee(EmployeeEntity employee) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await insertEmployeeUseCase(employee);
      _employees.add(employee);
      _employees.sort((a, b) => a.fullName.compareTo(b.fullName));
    } catch (e) {
      _error = e.toString();
      debugPrint('Error adding employee: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateEmployee(EmployeeEntity employee) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await updateEmployeeUseCase(employee);
      final index = _employees.indexWhere((e) => e.id == employee.id);
      if (index != -1) {
        _employees[index] = employee;
        _employees.sort((a, b) => a.fullName.compareTo(b.fullName));
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error updating employee: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteEmployee(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await deleteEmployeeUseCase(id);
      _employees.removeWhere((e) => e.id == id);
    } catch (e) {
      _error = e.toString();
      debugPrint('Error deleting employee: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> uploadEmployeeImage(XFile image, String employeeId) async {
    try {
      return await uploadEmployeeImageUseCase(image, employeeId);
    } catch (e) {
      debugPrint('Error uploading employee image in provider: $e');
      rethrow;
    }
  }

  /// Upload a document scan for a specific doc type (iqama, passport, etc.)
  Future<String> uploadDocumentAttachment(
    XFile file,
    String employeeId,
    String docType,
  ) async {
    try {
      return await uploadDocumentAttachmentUseCase(file, employeeId, docType);
    } catch (e) {
      debugPrint('Error uploading document attachment in provider: $e');
      rethrow;
    }
  }
}
