import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/user_management_repository.dart';

class ChangeUserPasswordParams extends Equatable {
  final String uid;
  final String newPassword;

  const ChangeUserPasswordParams({
    required this.uid,
    required this.newPassword,
  });

  @override
  List<Object?> get props => [uid, newPassword];
}

class ChangeUserPassword
    implements UseCase<void, ChangeUserPasswordParams> {
  final UserManagementRepository repository;

  ChangeUserPassword(this.repository);

  @override
  Future<Either<Failure, void>> call(ChangeUserPasswordParams params) {
    return repository.changeUserPassword(
      uid: params.uid,
      newPassword: params.newPassword,
    );
  }
}
