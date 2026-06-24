import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/notifications/domain/entities/notification_entity.dart';
import '../../features/notifications/presentation/providers/notification_provider.dart';

class ActivityLogger {
  /// Logs an activity by creating an activity notification.
  /// Needs [BuildContext] to access [AuthProvider] and [NotificationProvider].
  static Future<void> log(
    BuildContext context, {
    required String title,
    required String message,
    String? relatedId,
  }) async {
    if (!context.mounted) return;

    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    final userName = user?.displayName ?? user?.email ?? 'Unknown User';

    final notification = NotificationEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      timestamp: DateTime.now(),
      type: NotificationType.activity,
      relatedId: relatedId,
      userName: userName,
    );

    await context.read<NotificationProvider>().insertNotification(notification);
  }
}
