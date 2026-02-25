import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class GetCurrentUser {
  final AuthRepository repository;

  GetCurrentUser(this.repository);

  UserEntity? call() {
    return repository.currentUser;
  }
}

class GetAuthStateChanges {
  final AuthRepository repository;

  GetAuthStateChanges(this.repository);

  Stream<UserEntity?> call() {
    return repository.authStateChanges;
  }
}
