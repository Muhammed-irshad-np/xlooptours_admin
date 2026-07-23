import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/app_role.dart';
import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    super.email,
    super.displayName,
    super.isAdmin = false,
    super.role = AppRole.viewer,
    super.isActive = true,
  });

  factory UserModel.fromFirebaseUser(
    User user, {
    bool isAdmin = false,
    AppRole role = AppRole.viewer,
    bool isActive = true,
  }) {
    final resolvedRole = role;
    final resolvedAdmin = isAdmin || resolvedRole.isAdminRole;
    return UserModel(
      id: user.uid,
      email: user.email,
      displayName: user.displayName,
      isAdmin: resolvedAdmin,
      role: resolvedRole,
      isActive: isActive,
    );
  }

  /// Build from Firebase user + `allowed_users` document data.
  factory UserModel.fromFirebaseUserAndWhitelist(
    User user,
    Map<String, dynamic>? whitelistData,
  ) {
    if (whitelistData == null) {
      return UserModel.fromFirebaseUser(user);
    }
    final isAdmin = whitelistData['isAdmin'] as bool? ?? false;
    final isActive = whitelistData['isActive'] as bool? ?? true;
    final role = AppRole.fromFirestore(
      role: whitelistData['role'] as String?,
      isAdmin: isAdmin,
    );
    return UserModel.fromFirebaseUser(
      user,
      isAdmin: isAdmin || role.isAdminRole,
      role: role,
      isActive: isActive,
    );
  }
}
