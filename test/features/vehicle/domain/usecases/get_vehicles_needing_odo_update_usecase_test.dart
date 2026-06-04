import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_entity.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/get_vehicles_needing_odo_update_usecase.dart';

void main() {
  late GetVehiclesNeedingOdometerUpdateUseCase useCase;

  setUp(() {
    useCase = GetVehiclesNeedingOdometerUpdateUseCase();
  });

  VehicleEntity createVehicle({
    required String id,
    DateTime? lastUpdateDate,
    DateTime? purchaseDate,
  }) {
    return VehicleEntity(
      id: id,
      make: 'Toyota',
      model: 'Corolla',
      year: 2020,
      color: 'White',
      plateNumber: '1234 ABC',
      type: 'Sedan',
      lastOdometerUpdateDate: lastUpdateDate,
      purchaseDate: purchaseDate,
    );
  }

  group('GetVehiclesNeedingOdometerUpdateUseCase - Trigger and Missed Count Logic', () {
    test('should identify vehicles that have never been updated as needing update', () {
      final vehicle = createVehicle(id: '1', lastUpdateDate: null);
      final result = useCase([vehicle]);
      expect(result.length, 1);
      expect(result.first.id, '1');
    });

    test('should identify vehicles updated before the most recent Thursday as needing update', () {
      final now = DateTime.now();
      final mostRecentThursday = GetVehiclesNeedingOdometerUpdateUseCase.getMostRecentThursday(now);
      
      // Updated 1 day before the most recent Thursday
      final lastUpdate = mostRecentThursday.subtract(const Duration(days: 1));
      final vehicle = createVehicle(id: '1', lastUpdateDate: lastUpdate);
      
      final result = useCase([vehicle]);
      expect(result.length, 1);
    });

    test('should NOT identify vehicles updated on or after the most recent Thursday as needing update', () {
      final now = DateTime.now();
      final mostRecentThursday = GetVehiclesNeedingOdometerUpdateUseCase.getMostRecentThursday(now);
      
      // Updated exactly on the most recent Thursday at 12:00 PM
      final lastUpdate = DateTime(
        mostRecentThursday.year,
        mostRecentThursday.month,
        mostRecentThursday.day,
        12,
        0,
      );
      final vehicle = createVehicle(id: '1', lastUpdateDate: lastUpdate);
      
      final result = useCase([vehicle]);
      expect(result.isEmpty, true);
    });

    test('should calculate missed updates count correctly', () {
      final now = DateTime.now();
      final mostRecentThursday = GetVehiclesNeedingOdometerUpdateUseCase.getMostRecentThursday(now);

      // Case A: Updated on or after the most recent Thursday -> 0 missed
      final v1 = createVehicle(
        id: 'v1', 
        lastUpdateDate: mostRecentThursday.add(const Duration(hours: 2)),
      );
      expect(useCase.getMissedUpdatesCount(v1), 0);

      // Case B: Updated before the most recent Thursday but after the one prior -> 0 missed (only currently due)
      final v2 = createVehicle(
        id: 'v2', 
        lastUpdateDate: mostRecentThursday.subtract(const Duration(days: 2)),
      );
      expect(useCase.getMissedUpdatesCount(v2), 0);

      // Case C: Last updated 2 Thursdays ago -> 1 missed update
      final v3 = createVehicle(
        id: 'v3', 
        lastUpdateDate: mostRecentThursday.subtract(const Duration(days: 8)),
      );
      expect(useCase.getMissedUpdatesCount(v3), 1);

      // Case D: Last updated 3 Thursdays ago -> 2 missed updates
      final v4 = createVehicle(
        id: 'v4', 
        lastUpdateDate: mostRecentThursday.subtract(const Duration(days: 15)),
      );
      expect(useCase.getMissedUpdatesCount(v4), 2);
    });
  });
}
