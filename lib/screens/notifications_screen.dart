import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../features/notifications/domain/entities/notification_entity.dart';
import '../features/notifications/presentation/providers/notification_provider.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background
      appBar: AppBar(
        title: Text(
          'Activity & Notifications',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 24.sp,
            color: Colors.indigo[900],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.indigo[900]),
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.notifications.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null) {
            return Center(child: Text('Error: ${provider.errorMessage}'));
          }

          final notifications = provider.notifications;

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 60.sp,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'No notifications yet',
                    style: GoogleFonts.inter(
                      color: Colors.grey,
                      fontSize: 16.sp,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.all(24.w),
            itemCount: notifications.length,
            separatorBuilder: (c, i) => SizedBox(height: 12.h),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _buildNotificationCard(context, notification);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    NotificationEntity notification,
  ) {
    // Determine icon and color based on type
    IconData icon;
    Color color;

    switch (notification.type) {
      case NotificationType.registration:
        icon = Icons.person_add;
        color = Colors.green;
        break;
      case NotificationType.invoice:
        icon = Icons.receipt;
        color = Colors.blue;
        break;
      case NotificationType.system:
      default:
        icon = Icons.info;
        color = Colors.orange;
        break;
    }

    return Card(
      elevation: 0,
      color: notification.isRead ? Colors.white : Colors.blue.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(
          notification.title,
          style: GoogleFonts.inter(
            fontWeight: notification.isRead
                ? FontWeight.normal
                : FontWeight.bold,
            fontSize: 16.sp,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4.h),
            Text(
              notification.message,
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              timeago.format(notification.timestamp),
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        trailing: !notification.isRead
            ? IconButton(
                icon: const Icon(Icons.mark_email_read, color: Colors.blue),
                tooltip: 'Mark as read',
                onPressed: () {
                  context.read<NotificationProvider>().markAsRead(
                    notification.id,
                  );
                },
              )
            : null,
      ),
    );
  }
}
