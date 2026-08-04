import 'package:flutter/foundation.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/managed_user_entity.dart';
import '../../domain/entities/role_entity.dart';
import '../../domain/usecases/change_user_login_email.dart';
import '../../domain/usecases/change_user_password.dart';
import '../../domain/usecases/create_role.dart';
import '../../domain/usecases/create_user.dart';
import '../../domain/usecases/delete_role.dart';
import '../../domain/usecases/get_all_roles.dart';
import '../../domain/usecases/get_all_users.dart';
import '../../domain/usecases/seed_default_roles.dart';
import '../../domain/usecases/toggle_user_status.dart';
import '../../domain/usecases/update_role.dart';
import '../../domain/usecases/update_user.dart';

class UserManagementProvider extends ChangeNotifier {
  final GetAllUsers _getAllUsers;
  final CreateUser _createUser;
  final UpdateUser _updateUser;
  final ToggleUserStatus _toggleUserStatus;
  final ChangeUserPassword _changeUserPassword;
  final ChangeUserLoginEmail _changeUserLoginEmail;
  final GetAllRoles _getAllRoles;
  final CreateRole _createRole;
  final UpdateRole _updateRole;
  final DeleteRole _deleteRole;
  final SeedDefaultRoles _seedDefaultRoles;

  UserManagementProvider({
    required GetAllUsers getAllUsers,
    required CreateUser createUser,
    required UpdateUser updateUser,
    required ToggleUserStatus toggleUserStatus,
    required ChangeUserPassword changeUserPassword,
    required ChangeUserLoginEmail changeUserLoginEmail,
    required GetAllRoles getAllRoles,
    required CreateRole createRole,
    required UpdateRole updateRole,
    required DeleteRole deleteRole,
    required SeedDefaultRoles seedDefaultRoles,
  })  : _getAllUsers = getAllUsers,
        _createUser = createUser,
        _updateUser = updateUser,
        _toggleUserStatus = toggleUserStatus,
        _changeUserPassword = changeUserPassword,
        _changeUserLoginEmail = changeUserLoginEmail,
        _getAllRoles = getAllRoles,
        _createRole = createRole,
        _updateRole = updateRole,
        _deleteRole = deleteRole,
        _seedDefaultRoles = seedDefaultRoles;

  List<ManagedUserEntity> _users = [];
  List<RoleEntity> _roles = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ManagedUserEntity> get users => _users;
  List<RoleEntity> get roles => _roles;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadInitialData() async {
    _setLoading(true);
    _errorMessage = null;

    final rolesResult = await _getAllRoles(NoParams());
    rolesResult.fold(
      (failure) => _errorMessage = failure.message,
      (roles) => _roles = List<RoleEntity>.from(roles),
    );

    final usersResult = await _getAllUsers(NoParams());
    usersResult.fold(
      (failure) => _errorMessage = failure.message,
      (users) => _users = List<ManagedUserEntity>.from(users),
    );

    _setLoading(false);
  }

  Future<bool> createNewUser({
    required String email,
    required String password,
    required String displayName,
    required String roleId,
    String? employeeId,
    String? employeeName,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    final result = await _createUser(CreateUserParams(
      email: email,
      password: password,
      displayName: displayName,
      roleId: roleId,
      employeeId: employeeId,
      employeeName: employeeName,
    ));

    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        _setLoading(false);
        return false;
      },
      (newUser) {
        _users.insert(0, newUser);
        _setLoading(false);
        return true;
      },
    );
  }

  Future<bool> editUser(ManagedUserEntity user) async {
    _setLoading(true);
    _errorMessage = null;

    final result = await _updateUser(user);

    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        _setLoading(false);
        return false;
      },
      (_) {
        final index = _users.indexWhere((u) => u.uid == user.uid);
        if (index != -1) {
          _users[index] = user;
        }
        _setLoading(false);
        return true;
      },
    );
  }

  Future<bool> toggleStatus(String uid, bool isActive) async {
    final result = await _toggleUserStatus(ToggleUserStatusParams(uid: uid, isActive: isActive));

    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (_) {
        final index = _users.indexWhere((u) => u.uid == uid);
        if (index != -1) {
          final old = _users[index];
          _users[index] = ManagedUserEntity(
            uid: old.uid,
            email: old.email,
            displayName: old.displayName,
            roleId: old.roleId,
            roleName: old.roleName,
            isActive: isActive,
            createdAt: old.createdAt,
            createdBy: old.createdBy,
            employeeId: old.employeeId,
            employeeName: old.employeeName,
            photoUrl: old.photoUrl,
            lastLoginAt: old.lastLoginAt,
            lastActiveAt: old.lastActiveAt,
            loginCount: old.loginCount,
          );
          notifyListeners();
        }
        return true;
      },
    );
  }

  Future<bool> changePassword({
    required String uid,
    required String newPassword,
  }) async {
    _errorMessage = null;
    final result = await _changeUserPassword(
      ChangeUserPasswordParams(uid: uid, newPassword: newPassword),
    );

    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (_) => true,
    );
  }

  /// Changes login email in Firebase Auth + User Management (Admin / Super Admin).
  Future<bool> changeLoginEmail({
    required String uid,
    required String newEmail,
  }) async {
    _errorMessage = null;
    final email = newEmail.trim().toLowerCase();
    final result = await _changeUserLoginEmail(
      ChangeUserLoginEmailParams(uid: uid, newEmail: email),
    );

    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (_) {
        final index = _users.indexWhere((u) => u.uid == uid);
        if (index != -1) {
          final old = _users[index];
          _users[index] = ManagedUserEntity(
            uid: old.uid,
            email: email,
            displayName: old.displayName,
            roleId: old.roleId,
            roleName: old.roleName,
            isActive: old.isActive,
            createdAt: old.createdAt,
            createdBy: old.createdBy,
            employeeId: old.employeeId,
            employeeName: old.employeeName,
            photoUrl: old.photoUrl,
            lastLoginAt: old.lastLoginAt,
            lastActiveAt: old.lastActiveAt,
            loginCount: old.loginCount,
          );
          notifyListeners();
        }
        return true;
      },
    );
  }

  Future<bool> createNewRole(RoleEntity role) async {
    _setLoading(true);
    _errorMessage = null;

    final result = await _createRole(role);

    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        _setLoading(false);
        return false;
      },
      (newRole) {
        _roles.add(newRole);
        _setLoading(false);
        return true;
      },
    );
  }

  Future<bool> editRole(RoleEntity role) async {
    _setLoading(true);
    _errorMessage = null;

    final result = await _updateRole(role);

    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        _setLoading(false);
        return false;
      },
      (_) {
        final index = _roles.indexWhere((r) => r.id == role.id);
        if (index != -1) {
          _roles[index] = role;
        }
        _setLoading(false);
        return true;
      },
    );
  }

  Future<bool> removeRole(String roleId) async {
    _setLoading(true);
    _errorMessage = null;

    final result = await _deleteRole(roleId);

    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        _setLoading(false);
        return false;
      },
      (_) {
        _roles.removeWhere((r) => r.id == roleId);
        _setLoading(false);
        return true;
      },
    );
  }

  Future<void> seedRoles() async {
    await _seedDefaultRoles(NoParams());
    await loadInitialData();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
