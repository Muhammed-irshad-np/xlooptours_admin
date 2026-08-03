import 'package:equatable/equatable.dart';
import '../../../../core/rbac/permission.dart';
import '../../../../core/rbac/rbac_manager.dart';

class UserEntity extends Equatable {
  final String id;
  final String? email;
  final String? displayName;
  /// Normalized role id (`super_admin`, `admin`, `office_staff`, …).
  final String roleId;
  /// Permission strings from the role (e.g. `manage_vehicles`).
  final List<String> permissions;

  const UserEntity({
    required this.id,
    this.email,
    this.displayName,
    this.roleId = 'office_staff',
    this.permissions = const [],
  });

  /// Super Admin + Admin only.
  ///
  /// All existing UI gates (`user?.isAdmin ?? false`) use this getter.
  /// Newly created users with roleId `super_admin` or `admin` get full admin
  /// UI without changing each screen.
  bool get isAdmin => RbacManager.roleIsAdmin(roleId);

  bool get isSuperAdmin =>
      RbacManager.normalizeRoleId(roleId) == RbacManager.roleSuperAdmin;

  bool hasPermission(AppPermission permission) =>
      RbacManager.hasPermission(this, permission);

  @override
  List<Object?> get props => [id, email, displayName, roleId, permissions];
}
