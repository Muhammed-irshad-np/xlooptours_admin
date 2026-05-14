import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    super.email,
    super.displayName,
    super.isAdmin = false,
  });

  factory UserModel.fromFirebaseUser(User user, {bool isAdmin = false}) {
    return UserModel(
      id: user.uid,
      email: user.email,
      displayName: user.displayName,
      isAdmin: isAdmin,
    );
  }
}
