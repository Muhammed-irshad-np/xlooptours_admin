import 'package:cloud_firestore/cloud_firestore.dart';
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
    return ManagedUserModel(
      uid: uid,
      email: (data['email'] as String?)?.toLowerCase() ?? '',
      displayName: data['displayName'] ?? '',
      roleId: data['roleId'] ?? 'office_staff',
      roleName: roleName.isNotEmpty
          ? roleName
          : (data['roleName'] ?? data['roleId'] ?? ''),
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email.toLowerCase(),
      'displayName': displayName,
      'roleId': roleId,
      'isActive': isActive,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'createdBy': createdBy,
    };
  }

  Map<String, dynamic> toFirestoreUpdate() {
    return {
      'uid': uid,
      'email': email.toLowerCase(),
      'displayName': displayName,
      'roleId': roleId,
      'isActive': isActive,
    };
  }
}
