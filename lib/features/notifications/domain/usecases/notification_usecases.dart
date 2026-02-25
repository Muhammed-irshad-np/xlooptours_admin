import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/notification_entity.dart';
import '../repositories/notification_repository.dart';

class GetNotifications {
  final NotificationRepository repository;

  GetNotifications(this.repository);

  Stream<List<NotificationEntity>> call() {
    return repository.getNotifications();
  }
}

class InsertNotification implements UseCase<void, NotificationEntity> {
  final NotificationRepository repository;

  InsertNotification(this.repository);

  @override
  Future<Either<Failure, void>> call(NotificationEntity params) {
    return repository.insertNotification(params);
  }
}

class MarkNotificationAsRead implements UseCase<void, String> {
  final NotificationRepository repository;

  MarkNotificationAsRead(this.repository);

  @override
  Future<Either<Failure, void>> call(String params) {
    return repository.markAsRead(params);
  }
}
