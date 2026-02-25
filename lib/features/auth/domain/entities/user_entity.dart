import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String? email;
  final String? displayName;

  const UserEntity({required this.id, this.email, this.displayName});

  @override
  List<Object?> get props => [id, email, displayName];
}
