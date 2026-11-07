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

  // A fixed week so the tests do not depend on what day they run.
  // 2026-11-02 is a Monday.
  final mon = DateTime(2026, 11, 2);
  final tue = DateTime(2026, 11, 3);
  final wed = DateTime(2026, 11, 4);
  final thu = DateTime(2026, 11, 5);
  final sat = DateTime(2026, 11, 7);
  final sun = DateTime(2026, 11, 8);
  final prevThu = DateTime(2026, 10, 29);
  final prevMon = DateTime(2026, 10, 26);

  group('getMostRecentCheckDay', () {
    test('a check day is its own most recent check day', () {
      expect(
        GetVehiclesNeedingOdometerUpdateUseCase.getMostRecentCheckDay(
          mon.add(const Duration(hours: 15)),
        ),
        mon,
      );
      expect(
        GetVehiclesNeedingOdometerUpdateUseCase.getMostRecentCheckDay(thu),
        thu,
      );
    });

    test('Tuesday and Wednesday fall back to Monday', () {
      expect(
        GetVehiclesNeedingOdometerUpdateUseCase.getMostRecentCheckDay(tue),
        mon,
      );
      expect(
        GetVehiclesNeedingOdometerUpdateUseCase.getMostRecentCheckDay(wed),
        mon,
      );
    });

    test('Friday to Sunday fall back to Thursday', () {
      expect(
        GetVehiclesNeedingOdometerUpdateUseCase.getMostRecentCheckDay(sat),
        thu,
      );
      expect(
        GetVehiclesNeedingOdometerUpdateUseCase.getMostRecentCheckDay(sun),
        thu,
      );
    });

    test('works across a month boundary', () {
      // 2026-12-01 is a Tuesday; the previous Monday is 2026-11-30.
      expect(
        GetVehiclesNeedingOdometerUpdateUseCase.getMostRecentCheckDay(
          DateTime(2026, 12, 1),
        ),
        DateTime(2026, 11, 30),
      );
    });
  });

  group('who needs an update', () {
    test('a vehicle never updated needs an update', () {
      final v = createVehicle(id: '1');
      expect(useCase([v], now: wed).length, 1);
    });

    test('on Monday, a reading from last Thursday is no longer enough', () {
      final v = createVehicle(id: '1', lastUpdateDate: prevThu);
      expect(useCase([v], now: mon.add(const Duration(hours: 9))).length, 1);
    });

    test('a reading on Monday clears Monday to Wednesday', () {
      final v = createVehicle(
        id: '1',
        lastUpdateDate: mon.add(const Duration(hours: 10)),
      );
      expect(useCase([v], now: mon.add(const Duration(hours: 11))), isEmpty);
      expect(useCase([v], now: tue), isEmpty);
      expect(useCase([v], now: wed.add(const Duration(hours: 23))), isEmpty);
    });

    test('a Monday reading is due again on Thursday', () {
      final v = createVehicle(
        id: '1',
        lastUpdateDate: mon.add(const Duration(hours: 10)),
      );
      expect(useCase([v], now: thu.add(const Duration(hours: 8))).length, 1);
    });

    test('a reading on Thursday clears Thursday to Sunday', () {
      final v = createVehicle(
        id: '1',
        lastUpdateDate: thu.add(const Duration(hours: 12)),
      );
      expect(useCase([v], now: sat), isEmpty);
      expect(useCase([v], now: sun.add(const Duration(hours: 23))), isEmpty);
    });

    test('a reading taken between check days clears the current one', () {
      // Read on Tuesday: Monday's check is covered, Thursday's is not.
      final v = createVehicle(id: '1', lastUpdateDate: tue);
      expect(useCase([v], now: wed), isEmpty);
      expect(useCase([v], now: thu).length, 1);
    });
  });

  group('missed count', () {
    test('only the currently due check is not counted as missed', () {
      // Last read Thursday; now Monday: Monday is due, nothing missed.
      final v = createVehicle(id: '1', lastUpdateDate: prevThu);
      expect(useCase.getMissedUpdatesCount(v, now: mon), 0);
    });

    test('reading up to date means nothing missed', () {
      final v = createVehicle(id: '1', lastUpdateDate: thu);
      expect(useCase.getMissedUpdatesCount(v, now: sat), 0);
    });

    test('skipping Monday counts one missed by Thursday', () {
      // Last read previous Thursday; Monday skipped; now Thursday.
      final v = createVehicle(id: '1', lastUpdateDate: prevThu);
      expect(useCase.getMissedUpdatesCount(v, now: thu), 1);
    });

    test('each skipped check day is counted', () {
      // Last read previous Monday. Since then: prev Thu, Mon, Thu.
      // Thursday is the one due, so two were missed.
      final v = createVehicle(id: '1', lastUpdateDate: prevMon);
      expect(useCase.getMissedUpdatesCount(v, now: sat), 2);
    });

    test('a never-read vehicle counts check days since purchase', () {
      // Purchased previous Monday: prev Thu, Mon, Thu up to Saturday.
      final v = createVehicle(id: '1', purchaseDate: prevMon);
      expect(useCase.getMissedUpdatesCount(v, now: sat), 3);
    });

    test('a never-read vehicle bought today still shows one', () {
      final v = createVehicle(id: '1', purchaseDate: wed);
      expect(useCase.getMissedUpdatesCount(v, now: wed), 1);
    });

    test('a never-read vehicle with no purchase date shows one', () {
      final v = createVehicle(id: '1');
      expect(useCase.getMissedUpdatesCount(v, now: wed), 1);
    });
  });

  test('countCheckDays counts Mondays and Thursdays after start, up to end', () {
    expect(
      GetVehiclesNeedingOdometerUpdateUseCase.countCheckDays(prevMon, sun),
      3, // prev Thu, Mon, Thu
    );
    expect(
      GetVehiclesNeedingOdometerUpdateUseCase.countCheckDays(mon, wed),
      0,
    );
    expect(
      GetVehiclesNeedingOdometerUpdateUseCase.countCheckDays(wed, thu),
      1,
    );
  });
}
