import 'package:equatable/equatable.dart';

enum NotificationType { registration, invoice, system, expiry }

class NotificationEntity extends Equatable {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final NotificationType type;
  final String? relatedId;

  const NotificationEntity({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.type = NotificationType.system,
    this.relatedId,
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
  ];
}
