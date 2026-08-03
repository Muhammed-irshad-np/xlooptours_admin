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

  const ManagedUserEntity({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.roleId,
    required this.roleName,
    this.isActive = true,
    this.createdAt,
    this.createdBy,
  });

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
      ];
}
