import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/usecases/notification_usecases.dart';
import '../../domain/usecases/mark_all_notifications_as_read.dart';
import '../../../employee/domain/usecases/get_employee_expiry_alerts_usecase.dart';
import '../../../vehicle/domain/usecases/get_vehicle_maintenance_alerts_usecase.dart';
import '../../../vehicle/domain/entities/vehicle_entity.dart';
import '../../../vehicle/domain/entities/maintenance_type_entity.dart';

class NotificationProvider extends ChangeNotifier {
  final GetNotifications _getNotifications;
  final InsertNotification _insertNotification;
  final MarkNotificationAsRead _markNotificationAsRead;
  final MarkAllNotificationsAsRead _markAllNotificationsAsRead;
  final GetEmployeeExpiryAlertsUseCase _getEmployeeExpiryAlerts;
  final GetVehicleMaintenanceAlertsUseCase _getVehicleMaintenanceAlerts;
  final SharedPreferences _prefs;

  static const String _readVirtualIdsKey = 'read_virtual_notification_ids';

  List<NotificationEntity> _dbNotifications = [];
  List<NotificationEntity> _computedNotifications = [];
  List<NotificationEntity> _notifications = [];
  Set<String> _readVirtualIds = {};
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<List<NotificationEntity>>? _subscription;

  NotificationProvider({
    required GetNotifications getNotifications,
    required InsertNotification insertNotification,
    required MarkNotificationAsRead markNotificationAsRead,
    required MarkAllNotificationsAsRead markAllNotificationsAsRead,
    required GetEmployeeExpiryAlertsUseCase getEmployeeExpiryAlerts,
    required GetVehicleMaintenanceAlertsUseCase getVehicleMaintenanceAlerts,
    required SharedPreferences sharedPreferences,
  }) : _getNotifications = getNotifications,
       _insertNotification = insertNotification,
       _markNotificationAsRead = markNotificationAsRead,
       _markAllNotificationsAsRead = markAllNotificationsAsRead,
       _getEmployeeExpiryAlerts = getEmployeeExpiryAlerts,
       _getVehicleMaintenanceAlerts = getVehicleMaintenanceAlerts,
       _prefs = sharedPreferences {
    _init();
  }

  List<NotificationEntity> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void _init() {
    _setLoading(true);
    // Load read virtual IDs from SharedPreferences
    final storedIds = _prefs.getStringList(_readVirtualIdsKey);
    if (storedIds != null) {
      _readVirtualIds = Set.from(storedIds);
    }

    _subscription = _getNotifications().listen(
      (data) {
        _dbNotifications = List.from(data);
        _combineAndSort();
        _errorMessage = null;
        _setLoading(false);
      },
      onError: (error) {
        _errorMessage = error.toString();
        _setLoading(false);
      },
    );
  }

  void _combineAndSort() {
    _notifications = [..._dbNotifications, ..._computedNotifications];
    _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    notifyListeners();
  }

  /// Re-computes employee expiry + vehicle maintenance alerts and merges them
  /// into the notification list. Call this after vehicle/employee data loads.
  Future<void> refreshAlerts({
    required List<VehicleEntity> vehicles,
    required List<MaintenanceTypeEntity> maintenanceTypes,
  }) async {
    // Clear previous computed alerts
    _computedNotifications.clear();
    await _appendComputedAlerts(
      vehicles: vehicles,
      maintenanceTypes: maintenanceTypes,
    );
    _combineAndSort();
  }

  Future<void> _appendComputedAlerts({
    required List<VehicleEntity> vehicles,
    required List<MaintenanceTypeEntity> maintenanceTypes,
  }) async {
    try {
      // ── Employee expiry alerts ──────────────────────────────────────────────
      final expiryAlerts = await _getEmployeeExpiryAlerts();
      final expiryNotifications = expiryAlerts.map((alert) {
        final id = 'expiry_${alert.employeeId}_${alert.documentType.replaceAll(' ', '_')}';
        return NotificationEntity(
          id: id,
          title: '${alert.documentType} Expiring Soon',
          message: '${alert.employeeName}\'s ${alert.documentType} is expiring on '
              '${alert.expiryDate.toLocal().toString().split(' ')[0]} '
              '(${alert.daysUntilExpiry} days left).',
          timestamp: DateTime.now(),
          isRead: _readVirtualIds.contains(id),
          type: NotificationType.expiry,
          relatedId: alert.employeeId,
        );
      }).toList();

      _computedNotifications.addAll(expiryNotifications);

      // ── Vehicle maintenance alerts ──────────────────────────────────────────
      final maintenanceAlerts = _getVehicleMaintenanceAlerts(
        vehicles: vehicles,
        maintenanceTypes: maintenanceTypes,
      );
      final maintenanceNotifications = maintenanceAlerts.map((alert) {
        final id = 'maintenance_${alert.vehicle.id}_${alert.category.replaceAll(' ', '_')}';
        return NotificationEntity(
          id: id,
          title: '⚠️ ${alert.category} Overdue',
          message: '${alert.vehicle.make} ${alert.vehicle.model} '
              '(${alert.vehicle.plateNumber}): last serviced at '
              '${alert.lastServiceMileage} km, due at ${alert.nextServiceMileage} km — '
              '${alert.kmOverdue} km overdue (current: ${alert.currentMileage} km)',
          timestamp: DateTime.now(),
          isRead: _readVirtualIds.contains(id),
          type: NotificationType.expiry, // shows in Action Items section
          relatedId: alert.vehicle.id,
        );
      }).toList();

      _computedNotifications.addAll(maintenanceNotifications);
    } catch (e) {
      debugPrint('Failed to compute alerts: $e');
    }
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

  bool _isVirtualId(String id) {
    return id.startsWith('expiry_') || id.startsWith('maintenance_');
  }

  Future<bool> markAsRead(String id) async {
    if (_isVirtualId(id)) {
      _readVirtualIds.add(id);
      await _prefs.setStringList(_readVirtualIdsKey, _readVirtualIds.toList());
      
      // Update in-memory computed notifications
      final index = _computedNotifications.indexWhere((n) => n.id == id);
      if (index != -1) {
        _computedNotifications[index] = _computedNotifications[index].copyWith(isRead: true);
        _combineAndSort();
      }
      return true;
    }

    final result = await _markNotificationAsRead(id);
    return result.fold((failure) {
      _errorMessage = failure.message;
      notifyListeners();
      return false;
    }, (_) => true);
  }

  Future<bool> markAllAsRead() async {
    _setLoading(true);

    // 1. Mark all virtual notifications as read
    bool virtualChanged = false;
    for (var n in _computedNotifications) {
      if (!n.isRead) {
        _readVirtualIds.add(n.id);
        virtualChanged = true;
      }
    }

    if (virtualChanged) {
      await _prefs.setStringList(_readVirtualIdsKey, _readVirtualIds.toList());
      _computedNotifications = _computedNotifications
          .map((n) => n.copyWith(isRead: true))
          .toList();
    }

    // 2. Mark all DB notifications as read
    final result = await _markAllNotificationsAsRead(NoParams());
    
    _setLoading(false);
    
    return result.fold((failure) {
      _errorMessage = failure.message;
      notifyListeners();
      return false;
    }, (_) {
      _combineAndSort();
      return true;
    });
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
