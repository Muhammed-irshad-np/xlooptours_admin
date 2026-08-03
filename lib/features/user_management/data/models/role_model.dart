import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/rbac/permission.dart';
import '../../domain/entities/role_entity.dart';

class RoleModel extends RoleEntity {
  const RoleModel({
    required super.id,
    required super.name,
    super.isSystem = false,
    required super.permissions,
    super.createdAt,
  });

  factory RoleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawPerms = (data['permissions'] as List<dynamic>?)?.cast<String>() ?? [];
    
    final permissions = rawPerms
        .map((p) => AppPermissionExtension.fromString(p))
        .whereType<AppPermission>()
        .toList();

    return RoleModel(
      id: doc.id,
      name: data['name'] ?? doc.id,
      isSystem: data['isSystem'] ?? false,
      permissions: permissions,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'isSystem': isSystem,
      'permissions': permissions.map((p) => p.toPermissionString()).toList(),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
