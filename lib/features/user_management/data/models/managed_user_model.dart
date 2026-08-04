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
    super.employeeId,
    super.employeeName,
    super.photoUrl,
    super.lastLoginAt,
    super.lastActiveAt,
    super.lastLogoutAt,
    super.sessionActive = false,
    super.loginCount = 0,
  });

  static DateTime? _asDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  factory ManagedUserModel.fromFirestore(
    DocumentSnapshot doc, {
    String roleName = '',
    String? photoUrl,
  }) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
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
      roleName: roleName.isNotEmpty ? roleName : (data['roleName'] ?? roleId),
      isActive: data['isActive'] ?? true,
      createdAt: _asDate(data['createdAt']),
      createdBy: data['createdBy'],
      employeeId: data['employeeId'] as String?,
      employeeName: data['employeeName'] as String?,
      photoUrl: photoUrl,
      lastLoginAt: _asDate(data['lastLoginAt']),
      lastActiveAt: _asDate(data['lastActiveAt']),
      lastLogoutAt: _asDate(data['lastLogoutAt']),
      // Default false: missing field means offline (do not treat old docs as online)
      sessionActive: data['sessionActive'] == true,
      loginCount: (data['loginCount'] as num?)?.toInt() ?? 0,
    );
  }

  ManagedUserModel copyWithPhoto(String? url) {
    return ManagedUserModel(
      uid: uid,
      email: email,
      displayName: displayName,
      roleId: roleId,
      roleName: roleName,
      isActive: isActive,
      createdAt: createdAt,
      createdBy: createdBy,
      employeeId: employeeId,
      employeeName: employeeName,
      photoUrl: url,
      lastLoginAt: lastLoginAt,
      lastActiveAt: lastActiveAt,
      lastLogoutAt: lastLogoutAt,
      sessionActive: sessionActive,
      loginCount: loginCount,
    );
  }

  bool get isAdminRole => RbacManager.roleIsAdmin(roleId);

  Map<String, dynamic> toFirestore() {
    final normalizedRole = RbacManager.normalizeRoleId(roleId);
    return {
      'uid': uid,
      'email': email.toLowerCase(),
      'displayName': displayName,
      'roleId': normalizedRole,
      'isAdmin': RbacManager.roleIsAdmin(normalizedRole),
      'isActive': isActive,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'employeeId': employeeId,
      'employeeName': employeeName,
    };
  }

  Map<String, dynamic> toFirestoreUpdate({bool includeEmail = false}) {
    final normalizedRole = RbacManager.normalizeRoleId(roleId);
    final map = <String, dynamic>{
      'uid': uid,
      'displayName': displayName,
      'roleId': normalizedRole,
      'isAdmin': RbacManager.roleIsAdmin(normalizedRole),
      'isActive': isActive,
      'employeeId': employeeId,
      'employeeName': employeeName,
    };
    if (includeEmail) {
      map['email'] = email.toLowerCase();
    }
    return map;
  }
}
