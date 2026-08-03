import 'permission.dart';
import '../../features/auth/domain/entities/user_entity.dart';

/// Centralized permission / admin checks for the app.
///
/// **Admin flag (backward compatible with all existing `user.isAdmin` checks):**
/// - `super_admin` and `admin` roles → [isAdmin] == true
/// - everyone else → false
///
/// **Permissions** control which modules appear; micro UI still uses [isAdmin].
class RbacManager {
  RbacManager._();

  static const String roleSuperAdmin = 'super_admin';
  static const String roleAdmin = 'admin';

  /// Normalize Firestore / form role ids (trim + lowercase).
  static String normalizeRoleId(String? roleId) {
    final id = roleId?.trim().toLowerCase() ?? '';
    if (id.isEmpty) return 'office_staff';
    // Common aliases people might type or store
    if (id == 'superadmin' || id == 'super-admin') return roleSuperAdmin;
    if (id == 'administrator') return roleAdmin;
    return id;
  }

  /// True for Super Admin and Admin roles only.
  /// Used by [UserEntity.isAdmin] so every existing `user?.isAdmin` check works
  /// for newly created admin/super_admin users without touching each screen.
  static bool roleIsAdmin(String? roleId) {
    final id = normalizeRoleId(roleId);
    return id == roleSuperAdmin || id == roleAdmin;
  }

  static bool isSuperAdmin(UserEntity? user) =>
      normalizeRoleId(user?.roleId) == roleSuperAdmin;

  static bool isAdmin(UserEntity? user) => user?.isAdmin ?? false;

  static bool hasPermission(UserEntity? user, AppPermission permission) {
    if (user == null) return false;
    final roleId = normalizeRoleId(user.roleId);
    if (roleId == roleSuperAdmin) return true;
    if (roleId == roleAdmin) {
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
  static bool canAccessNav(
    UserEntity? user,
    AppPermission? requiredPermission,
  ) {
    if (user == null) return false;
    // Full admins always see every module (matches isAdmin UX).
    if (isAdmin(user)) return true;
    if (requiredPermission == null) return true;
    return hasPermission(user, requiredPermission);
  }
}
