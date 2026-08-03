import 'package:equatable/equatable.dart';
import '../../../../core/rbac/permission.dart';
import '../../../../core/rbac/rbac_manager.dart';

class UserEntity extends Equatable {
  final String id;
  final String? email;
  final String? displayName;
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

  /// Super Admin and Admin keep full admin UI access for backward compatibility.
  bool get isAdmin => roleId == 'super_admin' || roleId == 'admin';

  bool hasPermission(AppPermission permission) =>
      RbacManager.hasPermission(this, permission);

  @override
  List<Object?> get props => [id, email, displayName, roleId, permissions];
}
