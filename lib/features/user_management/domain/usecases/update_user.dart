import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/managed_user_entity.dart';
import '../repositories/user_management_repository.dart';

class UpdateUser implements UseCase<void, ManagedUserEntity> {
  final UserManagementRepository repository;

  UpdateUser(this.repository);

  @override
  Future<Either<Failure, void>> call(ManagedUserEntity user) async {
    return await repository.updateUser(user);
  }
}
