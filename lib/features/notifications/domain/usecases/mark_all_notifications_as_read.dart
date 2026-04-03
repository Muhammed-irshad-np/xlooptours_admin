import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/notification_repository.dart';

class MarkAllNotificationsAsRead implements UseCase<void, NoParams> {
  final NotificationRepository repository;

  MarkAllNotificationsAsRead(this.repository);

  @override
  Future<Either<Failure, void>> call(NoParams params) {
    return repository.markAllAsRead();
  }
}
