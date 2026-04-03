import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/usecases/notification_usecases.dart';
import '../../../employee/domain/usecases/get_employee_expiry_alerts_usecase.dart';
import '../../../vehicle/domain/usecases/get_vehicle_maintenance_alerts_usecase.dart';
import '../../../vehicle/presentation/providers/vehicle_provider.dart';
import 'package:get_it/get_it.dart';

class NotificationProvider extends ChangeNotifier {
  final GetNotifications _getNotifications;
  final InsertNotification _insertNotification;
  final MarkNotificationAsRead _markNotificationAsRead;
  final GetEmployeeExpiryAlertsUseCase _getEmployeeExpiryAlerts;
  final GetVehicleMaintenanceAlertsUseCase _getVehicleMaintenanceAlerts;

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
      (data) async {
        _notifications = List.from(data);

        try {
          final expiryAlerts = await _getEmployeeExpiryAlerts();
          final expiryNotifications = expiryAlerts
              .map(
                (alert) => NotificationEntity(
                  id: 'expiry_${alert.employeeId}_${alert.documentType.replaceAll(' ', '_')}',
                  title: '${alert.documentType} Expiring Soon',
                  message:
                      '${alert.employeeName}\'s ${alert.documentType} is expiring on ${alert.expiryDate.toLocal().toString().split(' ')[0]} (${alert.daysUntilExpiry} days left).',
                  timestamp:
                      DateTime.now(), // Use current time or a fixed time so it sorts properly, or maybe alert.expiryDate? Let's use current time so it shows at the top.
                  isRead: false,
                  type: NotificationType.expiry,
                  relatedId: alert.employeeId,
                ),
              )
              .toList();

          _notifications.addAll(expiryNotifications);

          // Add Vehicle Maintenance Alerts
          final vehicleProvider = GetIt.instance<VehicleProvider>();
          final maintenanceAlerts = _getVehicleMaintenanceAlerts(
            vehicles: vehicleProvider.vehicles,
            maintenanceTypes: vehicleProvider.maintenanceTypes,
          );
          final maintenanceNotifications = maintenanceAlerts
              .map(
                (alert) => NotificationEntity(
                  id: 'maintenance_${alert.vehicle.id}_${alert.category.replaceAll(' ', '_')}',
                  title: 'Maintenance Due: ${alert.category}',
                  message:
                      '${alert.vehicle.make} ${alert.vehicle.model} (${alert.vehicle.plateNumber}) needs ${alert.category}. Current: ${alert.currentMileage}km, Due: ${alert.nextServiceMileage}km',
                  timestamp: DateTime.now(),
                  isRead: false,
                  type: NotificationType
                      .expiry, // Reusing expiry type for now as it shows in Action Items
                  relatedId: alert.vehicle.id,
                ),
              )
              .toList();

          _notifications.addAll(maintenanceNotifications);
          _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        } catch (e) {
          debugPrint('Failed to fetch expiry alerts: $e');
        }

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
