import 'package:equatable/equatable.dart';
import '../../../../core/rbac/permission.dart';

class RoleEntity extends Equatable {
  final String id;
  final String name;
  final bool isSystem;
  final List<AppPermission> permissions;
  final DateTime? createdAt;

  const RoleEntity({
    required this.id,
    required this.name,
    this.isSystem = false,
    required this.permissions,
    this.createdAt,
  });

  bool hasPermission(AppPermission permission) {
    if (id == 'super_admin') return true;
    if (id == 'admin') {
      if (permission == AppPermission.manageRoles) return false;
      return true;
    }
    return permissions.contains(permission);
  }

  @override
  List<Object?> get props => [id, name, isSystem, permissions, createdAt];
}
