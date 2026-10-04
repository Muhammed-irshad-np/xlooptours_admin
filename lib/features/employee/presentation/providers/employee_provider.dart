import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/employee_entity.dart';
import '../../domain/usecases/assign_missing_employee_codes_usecase.dart';
import '../../domain/usecases/delete_employee_usecase.dart';
import '../../domain/usecases/get_all_employees_usecase.dart';
import '../../domain/usecases/insert_employee_usecase.dart';
import '../../domain/usecases/update_employee_usecase.dart';
import '../../domain/usecases/upload_document_attachment_usecase.dart';
import '../../domain/usecases/upload_employee_image_usecase.dart';
import '../../domain/usecases/get_employee_settings_usecase.dart';
import '../../domain/usecases/update_employee_settings_usecase.dart';
import '../../domain/entities/employee_settings_entity.dart';
import '../../domain/entities/employee_role_entity.dart';
import '../../domain/usecases/get_employee_roles_usecase.dart';
import '../../domain/usecases/save_employee_role_usecase.dart';
import '../../domain/usecases/delete_employee_role_usecase.dart';

class EmployeeProvider with ChangeNotifier {
  final GetAllEmployeesUseCase getAllEmployeesUseCase;
  final InsertEmployeeUseCase insertEmployeeUseCase;
  final AssignMissingEmployeeCodesUseCase assignMissingEmployeeCodesUseCase;
  final UpdateEmployeeUseCase updateEmployeeUseCase;
  final DeleteEmployeeUseCase deleteEmployeeUseCase;
  final UploadEmployeeImageUseCase uploadEmployeeImageUseCase;
  final UploadDocumentAttachmentUseCase uploadDocumentAttachmentUseCase;
  final GetEmployeeSettingsUseCase getEmployeeSettingsUseCase;
  final UpdateEmployeeSettingsUseCase updateEmployeeSettingsUseCase;
  final GetEmployeeRolesUseCase getEmployeeRolesUseCase;
  final SaveEmployeeRoleUseCase saveEmployeeRoleUseCase;
  final DeleteEmployeeRoleUseCase deleteEmployeeRoleUseCase;

  EmployeeProvider({
    required this.getAllEmployeesUseCase,
    required this.insertEmployeeUseCase,
    required this.assignMissingEmployeeCodesUseCase,
    required this.updateEmployeeUseCase,
    required this.deleteEmployeeUseCase,
    required this.uploadEmployeeImageUseCase,
    required this.uploadDocumentAttachmentUseCase,
    required this.getEmployeeSettingsUseCase,
    required this.updateEmployeeSettingsUseCase,
    required this.getEmployeeRolesUseCase,
    required this.saveEmployeeRoleUseCase,
    required this.deleteEmployeeRoleUseCase,
  });

  List<EmployeeEntity> _employees = [];
  EmployeeSettingsEntity? _settings;
  List<EmployeeRoleEntity> _roles = [];
  bool _isLoading = false;
  String? _error;

  List<EmployeeEntity> get employees => _employees;
  EmployeeSettingsEntity? get settings => _settings;
  List<EmployeeRoleEntity> get roles => _roles;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchAllEmployees() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      var fetchedEmployees = await getAllEmployeesUseCase();
      if (fetchedEmployees.any((e) => e.employeeCode == null)) {
        fetchedEmployees = await _backfillEmployeeCodes(fetchedEmployees);
      }
      _employees = List<EmployeeEntity>.from(fetchedEmployees);
    } catch (e) {
      _error = e.toString();
      debugPrint('Error fetching employees: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Gives a code to employees saved before codes existed (or by an older app
  /// build). A failure here must not hide the list, so it falls back to
  /// [current] and is retried on the next fetch.
  Future<List<EmployeeEntity>> _backfillEmployeeCodes(
    List<EmployeeEntity> current,
  ) async {
    try {
      final assigned = await assignMissingEmployeeCodesUseCase();
      return assigned > 0 ? await getAllEmployeesUseCase() : current;
    } catch (e) {
      debugPrint('Error assigning employee codes: $e');
      return current;
    }
  }

  /// Returns the saved employee, carrying its newly issued employee code.
  Future<EmployeeEntity> addEmployee(EmployeeEntity employee) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final code = await insertEmployeeUseCase(employee);
      final saved = employee.copyWith(employeeCode: code);
      _employees.add(saved);
      _employees.sort((a, b) => a.fullName.compareTo(b.fullName));
      return saved;
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

  // ======================
  // Settings Methods
  // ======================

  Future<void> fetchEmployeeSettings() async {
    _isLoading = true;
    notifyListeners();
    try {
      _settings = await getEmployeeSettingsUseCase();
      _error = null;
    } catch (e) {
      _error = 'Failed to fetch settings: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateEmployeeSettings(EmployeeSettingsEntity settings) async {
    _isLoading = true;
    notifyListeners();
    try {
      await updateEmployeeSettingsUseCase(settings);
      _settings = settings;
      _error = null;
    } catch (e) {
      _error = 'Failed to update settings: $e';
      debugPrint(_error);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ======================
  // Role Master Methods
  // ======================

  /// Built-in roles first, in their fixed order, then the custom ones.
  Future<void> fetchEmployeeRoles() async {
    try {
      final custom = await getEmployeeRolesUseCase();
      _roles = [
        ...EmployeeRoleEntity.defaults,
        ...custom.where((r) => !r.isBuiltIn),
      ];
    } catch (e) {
      debugPrint('Error fetching employee roles: $e');
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> saveEmployeeRole(EmployeeRoleEntity role) async {
    final index = _roles.indexWhere((r) => r.id == role.id);
    final previousName = index == -1 ? null : _roles[index].name;
    await saveEmployeeRoleUseCase(role, previousName: previousName);

    if (index == -1) {
      _roles.add(role);
    } else {
      _roles[index] = role;
    }
    final custom = _roles.where((r) => !r.isBuiltIn).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    _roles = [...EmployeeRoleEntity.defaults, ...custom];
    if (previousName != null && previousName != role.name) {
      _employees = _employees
          .map(
            (e) =>
                e.position == previousName ? e.copyWith(position: role.name) : e,
          )
          .toList();
    }
    notifyListeners();
  }

  Future<void> deleteEmployeeRole(String id) async {
    await deleteEmployeeRoleUseCase(id);
    _roles.removeWhere((r) => r.id == id);
    notifyListeners();
  }
}
