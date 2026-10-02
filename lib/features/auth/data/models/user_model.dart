import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/rbac/rbac_manager.dart';
import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    super.email,
    super.displayName,
    super.roleId = 'office_staff',
    super.roleName,
    super.permissions = const [],
    super.employeeId,
    super.employeeName,
    super.photoUrl,
    super.isActive = true,
  });

  factory UserModel.fromFirebaseUser(
    User user, {
    String roleId = 'office_staff',
    String? roleName,
    List<String> permissions = const [],
    String? displayName,
    String? employeeId,
    String? employeeName,
    String? photoUrl,
    bool isActive = true,
  }) {
    return UserModel(
      id: user.uid,
      email: user.email,
      displayName: displayName ?? user.displayName,
      roleId: RbacManager.normalizeRoleId(roleId),
      roleName: roleName,
      permissions: permissions,
      employeeId: employeeId,
      employeeName: employeeName,
      photoUrl: photoUrl,
      isActive: isActive,
    );
  }

  /// Backward-compatible whitelist builder (for legacy docs if any).
  factory UserModel.fromFirebaseUserAndWhitelist(
    User user,
    Map<String, dynamic>? whitelistData,
  ) {
    if (whitelistData == null) {
      return UserModel.fromFirebaseUser(user);
    }
    final isAdmin = whitelistData['isAdmin'] as bool? ?? false;
    final isActive = (whitelistData['isActive'] as bool?) ??
        (whitelistData['active'] as bool?) ??
        true;
    final rawRole = whitelistData['role'] as String? ??
        whitelistData['roleId'] as String? ??
        (isAdmin ? 'admin' : 'office_staff');

    return UserModel.fromFirebaseUser(
      user,
      roleId: rawRole,
      displayName: whitelistData['displayName'] as String?,
      isActive: isActive,
    );
  }
}
