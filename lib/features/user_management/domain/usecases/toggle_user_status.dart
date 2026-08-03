import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/user_management_repository.dart';

class ToggleUserStatusParams extends Equatable {
  final String uid;
  final bool isActive;

  const ToggleUserStatusParams({required this.uid, required this.isActive});

  @override
  List<Object?> get props => [uid, isActive];
}

class ToggleUserStatus implements UseCase<void, ToggleUserStatusParams> {
  final UserManagementRepository repository;

  ToggleUserStatus(this.repository);

  @override
  Future<Either<Failure, void>> call(ToggleUserStatusParams params) async {
    return await repository.toggleUserStatus(params.uid, params.isActive);
  }
}
