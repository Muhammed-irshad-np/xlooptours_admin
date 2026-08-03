import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/role_entity.dart';
import '../repositories/user_management_repository.dart';

class CreateRole implements UseCase<RoleEntity, RoleEntity> {
  final UserManagementRepository repository;

  CreateRole(this.repository);

  @override
  Future<Either<Failure, RoleEntity>> call(RoleEntity role) async {
    return await repository.createRole(role);
  }
}
