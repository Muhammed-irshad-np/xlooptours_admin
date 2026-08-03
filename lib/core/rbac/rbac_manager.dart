import 'permission.dart';
import '../../features/auth/domain/entities/user_entity.dart';

/// Centralized permission checks for the app.
///
/// Super Admin: all permissions.
/// Admin: all except [AppPermission.manageRoles].
/// Other roles: only permissions loaded from their role document.
class RbacManager {
  RbacManager._();

  static bool isSuperAdmin(UserEntity? user) =>
      user?.roleId == 'super_admin';

  static bool isAdmin(UserEntity? user) => user?.isAdmin ?? false;

  static bool hasPermission(UserEntity? user, AppPermission permission) {
    if (user == null) return false;
    if (user.roleId == 'super_admin') return true;
    if (user.roleId == 'admin') {
      // Admins may not manage roles (only Super Admin).
      if (permission == AppPermission.manageRoles) return false;
      return true;
    }
    return user.permissions.contains(permission.toPermissionString());
  }

  static bool hasAnyPermission(
    UserEntity? user,
    List<AppPermission> permissions,
  ) {
    if (user == null) return false;
    if (permissions.isEmpty) return true;
    return permissions.any((p) => hasPermission(user, p));
  }

  static bool canManageUsers(UserEntity? user) =>
      hasPermission(user, AppPermission.manageUsers);

  static bool canManageRoles(UserEntity? user) =>
      hasPermission(user, AppPermission.manageRoles);

  /// Whether the user may open a top-level nav item.
  /// [requiredPermission] null means any authenticated user.
  static bool canAccessNav(UserEntity? user, AppPermission? requiredPermission) {
    if (user == null) return false;
    if (requiredPermission == null) return true;
    return hasPermission(user, requiredPermission);
  }
}
