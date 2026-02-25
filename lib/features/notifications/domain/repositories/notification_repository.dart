import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/notification_entity.dart';

abstract class NotificationRepository {
  Stream<List<NotificationEntity>> getNotifications();

  Future<Either<Failure, void>> insertNotification(
    NotificationEntity notification,
  );

  Future<Either<Failure, void>> markAsRead(String id);
}
