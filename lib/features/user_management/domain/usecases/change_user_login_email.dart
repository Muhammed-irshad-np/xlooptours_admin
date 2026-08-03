import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/user_management_repository.dart';

class ChangeUserLoginEmailParams extends Equatable {
  final String uid;
  final String newEmail;

  const ChangeUserLoginEmailParams({
    required this.uid,
    required this.newEmail,
  });

  @override
  List<Object?> get props => [uid, newEmail];
}

class ChangeUserLoginEmail
    implements UseCase<void, ChangeUserLoginEmailParams> {
  final UserManagementRepository repository;

  ChangeUserLoginEmail(this.repository);

  @override
  Future<Either<Failure, void>> call(ChangeUserLoginEmailParams params) {
    return repository.changeUserLoginEmail(
      uid: params.uid,
      newEmail: params.newEmail,
    );
  }
}
