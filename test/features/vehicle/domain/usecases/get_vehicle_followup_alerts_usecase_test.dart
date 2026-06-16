import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_entity.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_documents.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/get_vehicle_followup_alerts_usecase.dart';

void main() {
  late GetVehicleFollowUpAlertsUseCase useCase;

  setUp(() {
    useCase = GetVehicleFollowUpAlertsUseCase();
  });

  VehicleEntity createVehicle({
    required String id,
    List<MaintenanceRecord>? maintenanceHistory,
    int? currentOdometer,
  }) {
    return VehicleEntity(
      id: id,
      make: 'Toyota',
      model: 'Corolla',
      year: 2020,
      color: 'White',
      plateNumber: '1234 ABC',
      type: 'Sedan',
      maintenanceHistory: maintenanceHistory,
      currentOdometer: currentOdometer,
    );
  }

  group('GetVehicleFollowUpAlertsUseCase', () {
    test('should return empty list when no vehicles have maintenance history', () {
      final vehicles = [
        createVehicle(id: '1', maintenanceHistory: null),
        createVehicle(id: '2', maintenanceHistory: []),
      ];

      final result = useCase(vehicles: vehicles);

      expect(result, isEmpty);
    });

    test('should NOT trigger alerts for records that do not require follow-up', () {
      final record = MaintenanceRecord(
        date: DateTime.now().subtract(const Duration(days: 10)),
        mileage: 10000,
        isFollowUpRequired: false,
      );
      final vehicles = [createVehicle(id: '1', maintenanceHistory: [record], currentOdometer: 11000)];

      final result = useCase(vehicles: vehicles);

      expect(result, isEmpty);
    });

    test('should NOT trigger alerts for records where follow-up is already completed', () {
      final record = MaintenanceRecord(
        date: DateTime.now().subtract(const Duration(days: 10)),
        mileage: 10000,
        isFollowUpRequired: true,
        isFollowUpCompleted: true,
        nextServiceMileage: 10500,
      );
      final vehicles = [createVehicle(id: '1', maintenanceHistory: [record], currentOdometer: 11000)];

      final result = useCase(vehicles: vehicles);

      expect(result, isEmpty);
    });

    test('should trigger alert if current mileage is greater than or equal to nextServiceMileage', () {
      final record = MaintenanceRecord(
        date: DateTime.now().subtract(const Duration(days: 10)),
        mileage: 10000,
        isFollowUpRequired: true,
        isFollowUpCompleted: false,
        nextServiceMileage: 10500,
      );
      final vehicles = [
        createVehicle(id: '1', maintenanceHistory: [record], currentOdometer: 10500),
      ];

      final result = useCase(vehicles: vehicles);

      expect(result.length, 1);
      expect(result.first.vehicle.id, '1');
      expect(result.first.isOverdue, true);
    });

    test('should trigger alert if current date is after or equal to nextServiceDate', () {
      final targetDate = DateTime.now().subtract(const Duration(days: 1));
      final record = MaintenanceRecord(
        date: DateTime.now().subtract(const Duration(days: 10)),
        mileage: 10000,
        isFollowUpRequired: true,
        isFollowUpCompleted: false,
        nextServiceDate: targetDate,
      );
      final vehicles = [
        createVehicle(id: '1', maintenanceHistory: [record], currentOdometer: 10100),
      ];

      final result = useCase(vehicles: vehicles);

      expect(result.length, 1);
      expect(result.first.vehicle.id, '1');
      expect(result.first.isOverdue, true);
    });

    test('should return pending alerts even if not overdue when includeAll is true', () {
      final targetDate = DateTime.now().add(const Duration(days: 10)); // Future date
      final record = MaintenanceRecord(
        date: DateTime.now().subtract(const Duration(days: 2)),
        mileage: 10000,
        isFollowUpRequired: true,
        isFollowUpCompleted: false,
        nextServiceDate: targetDate,
        nextServiceMileage: 12000,
      );
      final vehicles = [
        createVehicle(id: '1', maintenanceHistory: [record], currentOdometer: 10100),
      ];

      // With includeAll = false, it shouldn't trigger (since date/mileage are in the future)
      final resultDefault = useCase(vehicles: vehicles);
      expect(resultDefault, isEmpty);

      // With includeAll = true, it should return the alert
      final resultAll = useCase(vehicles: vehicles, includeAll: true);
      expect(resultAll.length, 1);
      expect(resultAll.first.isOverdue, false);
    });
  });
}
