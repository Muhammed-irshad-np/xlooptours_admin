import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/managed_user_entity.dart';
import '../repositories/user_management_repository.dart';

class CreateUserParams extends Equatable {
  final String email;
  final String password;
  final String displayName;
  final String roleId;
  final String? employeeId;
  final String? employeeName;

  const CreateUserParams({
    required this.email,
    required this.password,
    required this.displayName,
    required this.roleId,
    this.employeeId,
    this.employeeName,
  });

  @override
  List<Object?> get props =>
      [email, password, displayName, roleId, employeeId, employeeName];
}

class CreateUser implements UseCase<ManagedUserEntity, CreateUserParams> {
  final UserManagementRepository repository;

  CreateUser(this.repository);

  @override
  Future<Either<Failure, ManagedUserEntity>> call(CreateUserParams params) async {
    return await repository.createUser(
      email: params.email,
      password: params.password,
      displayName: params.displayName,
      roleId: params.roleId,
      employeeId: params.employeeId,
      employeeName: params.employeeName,
    );
  }
}
