import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/document_renewal_entity.dart';
import '../../domain/entities/employee_entity.dart';
import '../../domain/usecases/ensure_employee_codes_usecase.dart';
import '../../domain/usecases/delete_employee_usecase.dart';
import '../../domain/usecases/get_all_employees_usecase.dart';
import '../../domain/usecases/get_document_renewals_usecase.dart';
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
  final EnsureEmployeeCodesUseCase ensureEmployeeCodesUseCase;
  final UpdateEmployeeUseCase updateEmployeeUseCase;
  final DeleteEmployeeUseCase deleteEmployeeUseCase;
  final UploadEmployeeImageUseCase uploadEmployeeImageUseCase;
  final UploadDocumentAttachmentUseCase uploadDocumentAttachmentUseCase;
  final GetEmployeeSettingsUseCase getEmployeeSettingsUseCase;
  final UpdateEmployeeSettingsUseCase updateEmployeeSettingsUseCase;
  final GetEmployeeRolesUseCase getEmployeeRolesUseCase;
  final SaveEmployeeRoleUseCase saveEmployeeRoleUseCase;
  final DeleteEmployeeRoleUseCase deleteEmployeeRoleUseCase;
  final GetDocumentRenewalsUseCase getDocumentRenewalsUseCase;

  EmployeeProvider({
    required this.getAllEmployeesUseCase,
    required this.insertEmployeeUseCase,
    required this.ensureEmployeeCodesUseCase,
    required this.updateEmployeeUseCase,
    required this.deleteEmployeeUseCase,
    required this.uploadEmployeeImageUseCase,
    required this.uploadDocumentAttachmentUseCase,
    required this.getEmployeeSettingsUseCase,
    required this.updateEmployeeSettingsUseCase,
    required this.getEmployeeRolesUseCase,
    required this.saveEmployeeRoleUseCase,
    required this.deleteEmployeeRoleUseCase,
    required this.getDocumentRenewalsUseCase,
  });

  List<EmployeeEntity> _employees = [];
  EmployeeSettingsEntity? _settings;
  List<EmployeeRoleEntity> _roles = [];

  /// Renewal history per employee id, loaded on demand by the details screen.
  final Map<String, List<DocumentRenewalEntity>> _renewals = {};
  bool _isLoading = false;
  String? _error;

  /// Whether employee codes have been checked this session. A renumber (see
  /// ensureEmployeeCodes) can be due even when every employee has a code.
  bool _codesChecked = false;

  List<EmployeeEntity> get employees => _employees;
  EmployeeSettingsEntity? get settings => _settings;
  List<EmployeeRoleEntity> get roles => _roles;

  /// Null until [fetchDocumentRenewals] has run for [employeeId].
  List<DocumentRenewalEntity>? renewalsFor(String employeeId) =>
      _renewals[employeeId];
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchAllEmployees() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      var fetchedEmployees = await getAllEmployeesUseCase();
      if (!_codesChecked ||
          fetchedEmployees.any((e) => e.employeeCode == null)) {
        fetchedEmployees = await _ensureEmployeeCodes(fetchedEmployees);
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

  /// Codes employees saved before codes existed (or by an older app build)
  /// and applies any pending renumber. A failure here must not hide the list,
  /// so it falls back to [current] and is retried on the next fetch.
  Future<List<EmployeeEntity>> _ensureEmployeeCodes(
    List<EmployeeEntity> current,
  ) async {
    try {
      final assigned = await ensureEmployeeCodesUseCase();
      _codesChecked = true;
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

  /// Saves [employee] and records a renewal for every document whose expiry
  /// moved compared with the copy on file. Returns the renewals recorded, so a
  /// caller that has to roll the save back can pass them to
  /// [revertEmployeeUpdate].
  Future<List<DocumentRenewalEntity>> updateEmployee(
    EmployeeEntity employee, {
    String? renewedBy,
    String? renewalSource,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final index = _employees.indexWhere((e) => e.id == employee.id);
      final renewals = index == -1
          ? <DocumentRenewalEntity>[]
          : DocumentRenewalEntity.detect(
              _employees[index],
              employee,
              renewedAt: DateTime.now(),
              newId: () => const Uuid().v4(),
              renewedBy: renewedBy,
              source: renewalSource,
            );

      await updateEmployeeUseCase(employee, renewals: renewals);
      if (index != -1) {
        _employees[index] = employee;
        _employees.sort((a, b) => a.fullName.compareTo(b.fullName));
      }
      final cached = _renewals[employee.id];
      if (cached != null && renewals.isNotEmpty) {
        _renewals[employee.id] = [...renewals, ...cached];
      }
      return renewals;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error updating employee: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Puts [original] back and voids the [renewals] the undone save recorded,
  /// without recording the reversal itself as a renewal.
  Future<void> revertEmployeeUpdate(
    EmployeeEntity original,
    List<DocumentRenewalEntity> renewals,
  ) async {
    final ids = renewals.map((r) => r.id).toList();
    await updateEmployeeUseCase(original, voidRenewalIds: ids);
    final index = _employees.indexWhere((e) => e.id == original.id);
    if (index != -1) _employees[index] = original;
    final cached = _renewals[original.id];
    if (cached != null) {
      _renewals[original.id] =
          cached.where((r) => !ids.contains(r.id)).toList();
    }
    notifyListeners();
  }

  Future<void> fetchDocumentRenewals(String employeeId) async {
    try {
      _renewals[employeeId] = await getDocumentRenewalsUseCase(employeeId);
    } catch (e) {
      debugPrint('Error fetching document renewals: $e');
      rethrow;
    } finally {
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
