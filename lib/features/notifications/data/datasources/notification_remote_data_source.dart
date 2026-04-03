import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/error/exceptions.dart';
import '../models/notification_model.dart';

abstract class NotificationRemoteDataSource {
  Stream<List<NotificationModel>> getNotifications();
  Future<void> insertNotification(NotificationModel notification);
  Future<void> markAsRead(String id);
  Future<void> markAllAsRead();
}

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  final FirebaseFirestore firestore;

  NotificationRemoteDataSourceImpl({required this.firestore});

  @override
  Stream<List<NotificationModel>> getNotifications() {
    return firestore
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => NotificationModel.fromJson(doc.data()))
              .toList();
        });
  }

  @override
  Future<void> insertNotification(NotificationModel notification) async {
    try {
      await firestore
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toJson());
    } catch (e) {
      throw ServerException('Failed to insert notification: $e');
    }
  }

  @override
  Future<void> markAsRead(String id) async {
    try {
      await firestore.collection('notifications').doc(id).update({
        'isRead': true,
      });
    } catch (e) {
      throw ServerException('Failed to mark notification as read: $e');
    }
  }

  @override
  Future<void> markAllAsRead() async {
    try {
      final unreadNotifications = await firestore
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      if (unreadNotifications.docs.isEmpty) return;

      final batch = firestore.batch();
      for (var doc in unreadNotifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      throw ServerException('Failed to mark all notifications as read: $e');
    }
  }
}
