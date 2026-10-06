import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/features/vehicle/data/models/maintenance_type_model.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/maintenance_type_entity.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_entity.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_documents.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/get_vehicle_maintenance_alerts_usecase.dart';

void main() {
  late GetVehicleMaintenanceAlertsUseCase useCase;

  setUp(() {
    useCase = GetVehicleMaintenanceAlertsUseCase();
  });

  VehicleEntity createVehicle(List<MaintenanceRecord> history) {
    return VehicleEntity(
      id: 'v1',
      make: 'Toyota',
      model: 'Land Cruiser',
      year: 2022,
      color: 'White',
      plateNumber: '1234 ABC',
      type: 'SUV',
      currentOdometer: 20000,
      maintenanceHistory: history,
    );
  }

  const engineOil = MaintenanceTypeEntity(
    id: 't1',
    name: 'Engine Oil Change',
    suvIntervalKm: 5000,
    sedanIntervalKm: 5000,
  );

  const puncture = MaintenanceTypeEntity(
    id: 't2',
    name: 'Vehicle Puncture',
    suvIntervalKm: 0,
    sedanIntervalKm: 0,
    triggerType: 'none',
    notificationDays: null,
  );

  group('No Alert maintenance types', () {
    test('never produce an alert, even with includeAll', () {
      final vehicle = createVehicle([
        MaintenanceRecord(
          date: DateTime(2026, 1, 1),
          mileage: 10000,
          cost: 50,
          serviceType: 'Engine Oil Change',
        ),
        MaintenanceRecord(
          date: DateTime(2026, 1, 1),
          mileage: 10000,
          cost: 20,
          serviceType: 'Vehicle Puncture',
          nextServiceDate: DateTime(2026, 1, 2),
        ),
      ]);

      final alerts = useCase(
        vehicles: [vehicle],
        maintenanceTypes: const [engineOil, puncture],
        includeAll: true,
      );

      expect(alerts.map((a) => a.category), ['Engine Oil Change']);
    });

    test('are neither odometer nor date triggers', () {
      expect(puncture.isNoAlert, isTrue);
      expect(puncture.isOdometerTrigger, isFalse);
      expect(puncture.isDateTrigger, isFalse);
      expect(engineOil.isOdometerTrigger, isTrue);
    });

    test('keep their trigger type through JSON', () {
      final json = MaintenanceTypeModel.fromEntity(puncture).toJson();
      final restored = MaintenanceTypeModel.fromJson(json);

      expect(restored.triggerType, 'none');
      expect(restored.isNoAlert, isTrue);
    });
  });
}
