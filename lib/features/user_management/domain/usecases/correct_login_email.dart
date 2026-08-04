import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/user_management_repository.dart';

class CorrectLoginEmailParams extends Equatable {
  final String uid;
  final String loginEmail;

  const CorrectLoginEmailParams({
    required this.uid,
    required this.loginEmail,
  });

  @override
  List<Object?> get props => [uid, loginEmail];
}

class CorrectLoginEmail implements UseCase<void, CorrectLoginEmailParams> {
  final UserManagementRepository repository;

  CorrectLoginEmail(this.repository);

  @override
  Future<Either<Failure, void>> call(CorrectLoginEmailParams params) {
    return repository.correctLoginEmail(
      uid: params.uid,
      loginEmail: params.loginEmail,
    );
  }
}
