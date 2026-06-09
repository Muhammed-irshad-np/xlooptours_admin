import 'package:equatable/equatable.dart';

enum NotificationType { registration, invoice, system, expiry, activity }

class NotificationEntity extends Equatable {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final NotificationType type;
  final String? relatedId;
  final String? userName;

  const NotificationEntity({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.type = NotificationType.system,
    this.relatedId,
    this.userName,
  });

  @override
  List<Object?> get props => [
    id,
    title,
    message,
    timestamp,
    isRead,
    type,
    relatedId,
    userName,
  ];

  NotificationEntity copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    NotificationType? type,
    String? relatedId,
    String? userName,
  }) {
    return NotificationEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      relatedId: relatedId ?? this.relatedId,
      userName: userName ?? this.userName,
    );
  }
}
