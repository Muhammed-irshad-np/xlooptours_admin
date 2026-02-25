import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/usecases/notification_usecases.dart';

class NotificationProvider extends ChangeNotifier {
  final GetNotifications _getNotifications;
  final InsertNotification _insertNotification;
  final MarkNotificationAsRead _markNotificationAsRead;

  List<NotificationEntity> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<List<NotificationEntity>>? _subscription;

  NotificationProvider({
    required GetNotifications getNotifications,
    required InsertNotification insertNotification,
    required MarkNotificationAsRead markNotificationAsRead,
  }) : _getNotifications = getNotifications,
       _insertNotification = insertNotification,
       _markNotificationAsRead = markNotificationAsRead {
    _init();
  }

  List<NotificationEntity> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void _init() {
    _setLoading(true);
    _subscription = _getNotifications().listen(
      (data) {
        _notifications = data;
        _errorMessage = null;
        _setLoading(false);
      },
      onError: (error) {
        _errorMessage = error.toString();
        _setLoading(false);
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<bool> insertNotification(NotificationEntity notification) async {
    final result = await _insertNotification(notification);
    return result.fold((failure) {
      _errorMessage = failure.message;
      notifyListeners();
      return false;
    }, (_) => true);
  }

  Future<bool> markAsRead(String id) async {
    final result = await _markNotificationAsRead(id);
    return result.fold((failure) {
      _errorMessage = failure.message;
      notifyListeners();
      return false;
    }, (_) => true);
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
