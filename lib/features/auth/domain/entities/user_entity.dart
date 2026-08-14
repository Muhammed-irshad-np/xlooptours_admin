import 'package:equatable/equatable.dart';
import '../../../../core/rbac/permission.dart';
import '../../../../core/rbac/rbac_manager.dart';
import 'app_role.dart';

class UserEntity extends Equatable {
  final String id;
  final String? email;
  final String? displayName;

  /// Normalized role id (`super_admin`, `admin`, `office_staff`, `driver`, `coordinator`, `manager`, `finance`, etc.).
  final String roleId;

  /// Human-readable role name for UI (e.g. "Super Admin").
  final String? roleName;

  /// Permission strings from the role (e.g. `manage_vehicles`).
  final List<String> permissions;

  /// Linked employee id when this login is tied to an HR employee.
  final String? employeeId;
  final String? employeeName;

  /// Profile photo from linked employee record (`employees.imageUrl`).
  final String? photoUrl;

  /// Whether the user account is active (default true).
  final bool isActive;

  const UserEntity({
    required this.id,
    this.email,
    this.displayName,
    this.roleId = 'office_staff',
    this.roleName,
    this.permissions = const [],
    this.employeeId,
    this.employeeName,
    this.photoUrl,
    this.isActive = true,
  });

  /// Super Admin + Admin only.
  bool get isAdmin => RbacManager.roleIsAdmin(roleId);

  bool get isSuperAdmin =>
      RbacManager.normalizeRoleId(roleId) == RbacManager.roleSuperAdmin;

  /// Derives [AppRole] enum for finance module compatibility.
  AppRole get role {
    final normalized = RbacManager.normalizeRoleId(roleId);
    for (final r in AppRole.values) {
      if (r.name == normalized) return r;
    }
    if (isAdmin) return AppRole.admin;
    return AppRole.viewer;
  }

  String get roleLabel {
    if (roleName != null && roleName!.trim().isNotEmpty) return roleName!;
    switch (RbacManager.normalizeRoleId(roleId)) {
      case 'super_admin':
        return 'Super Admin';
      case 'admin':
        return 'Admin';
      case 'coordinator':
        return 'Coordinator';
      case 'driver':
        return 'Driver';
      case 'finance':
        return 'Finance';
      case 'manager':
        return 'Manager';
      case 'office_staff':
        return 'Office Staff';
      default:
        return roleId.replaceAll('_', ' ');
    }
  }

  String get displayLabel {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final mail = email?.trim();
    if (mail != null && mail.isNotEmpty) return mail;
    return 'User';
  }

  /// Best display label for audit trails.
  String get actorLabel {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final mail = email?.trim();
    if (mail != null && mail.isNotEmpty) return mail;
    return id;
  }

  bool hasPermission(AppPermission permission) =>
      RbacManager.hasPermission(this, permission);

  bool get canSubmitExpense => role.canSubmitExpense;
  bool get canApproveExpense => role.canApproveExpense;
  bool get canPostMoney => role.canPostMoney;
  bool get canReverseMoney => role.canReverseMoney;
  bool get canManageFundAccounts => role.canManageFundAccounts;
  bool get canManagePettyCash => role.canManagePettyCash;
  bool get canVerifyPettyCash => role.canVerifyPettyCash;
  bool get canManageCategories => role.canManageCategories;
  bool get canViewAllFinance => role.canViewAllFinance;

  @override
  List<Object?> get props => [
        id,
        email,
        displayName,
        roleId,
        roleName,
        permissions,
        employeeId,
        employeeName,
        photoUrl,
        isActive,
      ];
}
