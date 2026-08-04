import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/role_entity.dart';
import '../repositories/user_management_repository.dart';

class GetAllRoles implements UseCase<List<RoleEntity>, NoParams> {
  final UserManagementRepository repository;

  GetAllRoles(this.repository);

  @override
  Future<Either<Failure, List<RoleEntity>>> call(NoParams params) async {
    return await repository.getAllRoles();
  }
}
