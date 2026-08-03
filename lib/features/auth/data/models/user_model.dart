import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/rbac/rbac_manager.dart';
import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    super.email,
    super.displayName,
    super.roleId = 'office_staff',
    super.permissions = const [],
  });

  factory UserModel.fromFirebaseUser(
    User user, {
    String roleId = 'office_staff',
    List<String> permissions = const [],
    String? displayName,
  }) {
    return UserModel(
      id: user.uid,
      email: user.email,
      displayName: displayName ?? user.displayName,
      roleId: RbacManager.normalizeRoleId(roleId),
      permissions: permissions,
    );
  }
}
