import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/role_entity.dart';
import '../repositories/user_management_repository.dart';

class UpdateRole implements UseCase<void, RoleEntity> {
  final UserManagementRepository repository;

  UpdateRole(this.repository);

  @override
  Future<Either<Failure, void>> call(RoleEntity role) async {
    return await repository.updateRole(role);
  }
}
