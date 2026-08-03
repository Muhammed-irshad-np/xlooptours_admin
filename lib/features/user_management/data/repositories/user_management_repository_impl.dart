import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/managed_user_entity.dart';
import '../../domain/entities/role_entity.dart';
import '../../domain/repositories/user_management_repository.dart';
import '../datasources/user_management_remote_data_source.dart';
import '../models/managed_user_model.dart';
import '../models/role_model.dart';

class UserManagementRepositoryImpl implements UserManagementRepository {
  final UserManagementRemoteDataSource remoteDataSource;

  UserManagementRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<ManagedUserEntity>>> getAllUsers() async {
    try {
      final models = await remoteDataSource.getAllUsers();
      final entities = models
          .map(
            (m) => ManagedUserEntity(
              uid: m.uid,
              email: m.email,
              displayName: m.displayName,
              roleId: m.roleId,
              roleName: m.roleName,
              isActive: m.isActive,
              createdAt: m.createdAt,
              createdBy: m.createdBy,
            ),
          )
          .toList();
      return Right(entities);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ManagedUserEntity>> createUser({
    required String email,
    required String password,
    required String displayName,
    required String roleId,
  }) async {
    try {
      final m = await remoteDataSource.createUser(
        email: email,
        password: password,
        displayName: displayName,
        roleId: roleId,
      );
      return Right(
        ManagedUserEntity(
          uid: m.uid,
          email: m.email,
          displayName: m.displayName,
          roleId: m.roleId,
          roleName: m.roleName,
          isActive: m.isActive,
          createdAt: m.createdAt,
          createdBy: m.createdBy,
        ),
      );
    } on AuthenticationException catch (e) {
      return Left(AuthenticationFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateUser(ManagedUserEntity user) async {
    try {
      final model = ManagedUserModel(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
        roleId: user.roleId,
        roleName: user.roleName,
        isActive: user.isActive,
        createdAt: user.createdAt,
        createdBy: user.createdBy,
      );
      await remoteDataSource.updateUser(model);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> toggleUserStatus(
    String uid,
    bool isActive,
  ) async {
    try {
      await remoteDataSource.toggleUserStatus(uid, isActive);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> changeUserPassword({
    required String uid,
    required String newPassword,
  }) async {
    try {
      await remoteDataSource.changeUserPassword(
        uid: uid,
        newPassword: newPassword,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<RoleEntity>>> getAllRoles() async {
    try {
      final models = await remoteDataSource.getAllRoles();
      final entities = models
          .map(
            (m) => RoleEntity(
              id: m.id,
              name: m.name,
              isSystem: m.isSystem,
              permissions: m.permissions,
              createdAt: m.createdAt,
            ),
          )
          .toList();
      return Right(entities);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, RoleEntity>> createRole(RoleEntity role) async {
    try {
      final model = RoleModel(
        id: role.id,
        name: role.name,
        isSystem: role.isSystem,
        permissions: role.permissions,
        createdAt: role.createdAt,
      );
      final created = await remoteDataSource.createRole(model);
      return Right(
        RoleEntity(
          id: created.id,
          name: created.name,
          isSystem: created.isSystem,
          permissions: created.permissions,
          createdAt: created.createdAt,
        ),
      );
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateRole(RoleEntity role) async {
    try {
      final model = RoleModel(
        id: role.id,
        name: role.name,
        isSystem: role.isSystem,
        permissions: role.permissions,
        createdAt: role.createdAt,
      );
      await remoteDataSource.updateRole(model);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteRole(String roleId) async {
    try {
      await remoteDataSource.deleteRole(roleId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> seedDefaultRoles() async {
    try {
      await remoteDataSource.seedDefaultRoles();
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
