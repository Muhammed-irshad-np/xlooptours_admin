import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/rbac/rbac_manager.dart';
import '../../domain/entities/managed_user_entity.dart';

class ManagedUserModel extends ManagedUserEntity {
  const ManagedUserModel({
    required super.uid,
    required super.email,
    required super.displayName,
    required super.roleId,
    required super.roleName,
    super.isActive = true,
    super.createdAt,
    super.createdBy,
  });

  factory ManagedUserModel.fromFirestore(
    DocumentSnapshot doc, {
    String roleName = '',
  }) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    // Canonical id is Firebase Auth uid stored as document id (or uid field).
    final uid = (data['uid'] as String?)?.isNotEmpty == true
        ? data['uid'] as String
        : doc.id;
    final roleId = RbacManager.normalizeRoleId(
      data['roleId'] as String? ??
          (data['isAdmin'] == true ? RbacManager.roleAdmin : 'office_staff'),
    );
    return ManagedUserModel(
      uid: uid,
      email: (data['email'] as String?)?.toLowerCase() ?? '',
      displayName: data['displayName'] ?? '',
      roleId: roleId,
      roleName: roleName.isNotEmpty
          ? roleName
          : (data['roleName'] ?? roleId),
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'],
    );
  }

  /// Mirror of [UserEntity.isAdmin] for this managed profile.
  bool get isAdminRole => RbacManager.roleIsAdmin(roleId);

  Map<String, dynamic> toFirestore() {
    final normalizedRole = RbacManager.normalizeRoleId(roleId);
    return {
      'uid': uid,
      'email': email.toLowerCase(),
      'displayName': displayName,
      'roleId': normalizedRole,
      // Kept in sync so legacy readers and allow-list stay correct
      'isAdmin': RbacManager.roleIsAdmin(normalizedRole),
      'isActive': isActive,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'createdBy': createdBy,
    };
  }

  Map<String, dynamic> toFirestoreUpdate() {
    final normalizedRole = RbacManager.normalizeRoleId(roleId);
    return {
      'uid': uid,
      'email': email.toLowerCase(),
      'displayName': displayName,
      'roleId': normalizedRole,
      'isAdmin': RbacManager.roleIsAdmin(normalizedRole),
      'isActive': isActive,
    };
  }
}
