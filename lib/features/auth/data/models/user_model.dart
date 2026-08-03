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
    );
  }
}
