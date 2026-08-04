import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/user_management_repository.dart';

class DeleteRole implements UseCase<void, String> {
  final UserManagementRepository repository;

  DeleteRole(this.repository);

  @override
  Future<Either<Failure, void>> call(String roleId) async {
    return await repository.deleteRole(roleId);
  }
}
