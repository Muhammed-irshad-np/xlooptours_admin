import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/managed_user_entity.dart';
import '../repositories/user_management_repository.dart';

class GetAllUsers implements UseCase<List<ManagedUserEntity>, NoParams> {
  final UserManagementRepository repository;

  GetAllUsers(this.repository);

  @override
  Future<Either<Failure, List<ManagedUserEntity>>> call(NoParams params) async {
    return await repository.getAllUsers();
  }
}
