import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String? email;
  final String? displayName;
  final bool isAdmin;

  const UserEntity({
    required this.id,
    this.email,
    this.displayName,
    this.isAdmin = false,
  });

  @override
  List<Object?> get props => [id, email, displayName, isAdmin];
}
