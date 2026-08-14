import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/user_management_repository.dart';

class SeedDefaultRoles implements UseCase<void, NoParams> {
  final UserManagementRepository repository;

  SeedDefaultRoles(this.repository);

  @override
  Future<Either<Failure, void>> call(NoParams params) async {
    return await repository.seedDefaultRoles();
  }
}
