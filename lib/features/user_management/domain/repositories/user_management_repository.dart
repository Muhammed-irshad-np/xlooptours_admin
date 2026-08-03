import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/managed_user_entity.dart';
import '../entities/role_entity.dart';

abstract class UserManagementRepository {
  Future<Either<Failure, List<ManagedUserEntity>>> getAllUsers();
  Future<Either<Failure, ManagedUserEntity>> createUser({
    required String email,
    required String password,
    required String displayName,
    required String roleId,
  });
  Future<Either<Failure, void>> updateUser(ManagedUserEntity user);
  Future<Either<Failure, void>> toggleUserStatus(String uid, bool isActive);

  Future<Either<Failure, List<RoleEntity>>> getAllRoles();
  Future<Either<Failure, RoleEntity>> createRole(RoleEntity role);
  Future<Either<Failure, void>> updateRole(RoleEntity role);
  Future<Either<Failure, void>> deleteRole(String roleId);
  Future<Either<Failure, void>> seedDefaultRoles();
}
