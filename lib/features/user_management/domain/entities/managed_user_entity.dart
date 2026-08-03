import 'package:equatable/equatable.dart';

class ManagedUserEntity extends Equatable {
  final String uid;
  final String email;
  final String displayName;
  final String roleId;
  final String roleName;
  final bool isActive;
  final DateTime? createdAt;
  final String? createdBy;
  /// Linked employee record id from `employees` collection.
  final String? employeeId;
  /// Cached employee display name for lists.
  final String? employeeName;
  /// Profile photo from linked employee (`employees.imageUrl`).
  final String? photoUrl;

  const ManagedUserEntity({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.roleId,
    required this.roleName,
    this.isActive = true,
    this.createdAt,
    this.createdBy,
    this.employeeId,
    this.employeeName,
    this.photoUrl,
  });

  bool get hasEmployeeLink =>
      employeeId != null && employeeId!.trim().isNotEmpty;

  @override
  List<Object?> get props => [
        uid,
        email,
        displayName,
        roleId,
        roleName,
        isActive,
        createdAt,
        createdBy,
        employeeId,
        employeeName,
        photoUrl,
      ];
}
