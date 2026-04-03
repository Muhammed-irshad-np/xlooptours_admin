import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/usecases/notification_usecases.dart';
import '../../../employee/domain/usecases/get_employee_expiry_alerts_usecase.dart';
import '../../../vehicle/domain/usecases/get_vehicle_maintenance_alerts_usecase.dart';
import '../../../vehicle/domain/entities/vehicle_entity.dart';
import '../../../vehicle/domain/entities/maintenance_type_entity.dart';

class NotificationProvider extends ChangeNotifier {
  final GetNotifications _getNotifications;
  final InsertNotification _insertNotification;
  final MarkNotificationAsRead _markNotificationAsRead;
  final GetEmployeeExpiryAlertsUseCase _getEmployeeExpiryAlerts;
  final GetVehicleMaintenanceAlertsUseCase _getVehicleMaintenanceAlerts;

  List<NotificationEntity> _dbNotifications = [];
  List<NotificationEntity> _computedNotifications = [];
  List<NotificationEntity> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<List<NotificationEntity>>? _subscription;

  NotificationProvider({
    required GetNotifications getNotifications,
    required InsertNotification insertNotification,
    required MarkNotificationAsRead markNotificationAsRead,
    required GetEmployeeExpiryAlertsUseCase getEmployeeExpiryAlerts,
    required GetVehicleMaintenanceAlertsUseCase getVehicleMaintenanceAlerts,
  }) : _getNotifications = getNotifications,
       _insertNotification = insertNotification,
       _markNotificationAsRead = markNotificationAsRead,
       _getEmployeeExpiryAlerts = getEmployeeExpiryAlerts,
       _getVehicleMaintenanceAlerts = getVehicleMaintenanceAlerts {
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
      final expiryNotifications = expiryAlerts
          .map(
            (alert) => NotificationEntity(
              id: 'expiry_${alert.employeeId}_${alert.documentType.replaceAll(' ', '_')}',
              title: '${alert.documentType} Expiring Soon',
              message:
                  '${alert.employeeName}\'s ${alert.documentType} is expiring on '
                  '${alert.expiryDate.toLocal().toString().split(' ')[0]} '
                  '(${alert.daysUntilExpiry} days left).',
              timestamp: DateTime.now(),
              isRead: false,
              type: NotificationType.expiry,
              relatedId: alert.employeeId,
            ),
          )
          .toList();

      _computedNotifications.addAll(expiryNotifications);

      // ── Vehicle maintenance alerts ──────────────────────────────────────────
      final maintenanceAlerts = _getVehicleMaintenanceAlerts(
        vehicles: vehicles,
        maintenanceTypes: maintenanceTypes,
      );
      final maintenanceNotifications = maintenanceAlerts
          .map(
            (alert) => NotificationEntity(
              id: 'maintenance_${alert.vehicle.id}_${alert.category.replaceAll(' ', '_')}',
              title: '⚠️ ${alert.category} Overdue',
              message:
                  '${alert.vehicle.make} ${alert.vehicle.model} '
                  '(${alert.vehicle.plateNumber}): last serviced at '
                  '${alert.lastServiceMileage} km, due at ${alert.nextServiceMileage} km — '
                  '${alert.kmOverdue} km overdue (current: ${alert.currentMileage} km)',
              timestamp: DateTime.now(),
              isRead: false,
              type: NotificationType.expiry, // shows in Action Items section
              relatedId: alert.vehicle.id,
            ),
          )
          .toList();

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
