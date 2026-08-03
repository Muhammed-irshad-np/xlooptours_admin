import 'package:equatable/equatable.dart';
import '../../../../core/rbac/permission.dart';
import '../../../../core/rbac/rbac_manager.dart';

class UserEntity extends Equatable {
  final String id;
  final String? email;
  final String? displayName;
  /// Normalized role id (`super_admin`, `admin`, `office_staff`, …).
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
  });

  /// Super Admin + Admin only.
  bool get isAdmin => RbacManager.roleIsAdmin(roleId);

  bool get isSuperAdmin =>
      RbacManager.normalizeRoleId(roleId) == RbacManager.roleSuperAdmin;

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

  bool hasPermission(AppPermission permission) =>
      RbacManager.hasPermission(this, permission);

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
      ];
}
