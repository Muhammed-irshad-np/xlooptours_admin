import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/odometer_policy.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/odometer_reading_entity.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/odometer_validation.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/validate_odometer_reading_usecase.dart';

void main() {
  const policy = OdometerPolicy.defaults;
  const validator = ValidateOdometerReadingUseCase(policy: policy);

  // Anchored well in the past so every fixture reading is a real observation
  // rather than a future-dated one, which the engine refuses outright.
  final today = DateTime.now();
  final anchor =
      DateTime(today.year, today.month, today.day).subtract(const Duration(days: 60));

  OdometerReadingEntity reading(
    int value,
    DateTime at, {
    OdometerReadingStatus status = OdometerReadingStatus.accepted,
    OdometerSource source = OdometerSource.weeklyUpdate,
  }) {
    return OdometerReadingEntity(
      id: 'r-$value-${at.millisecondsSinceEpoch}',
      vehicleId: 'v1',
      value: value,
      readingAt: at,
      recordedAt: at,
      source: source,
      status: status,
    );
  }

  /// A vehicle with a steady ~150 km/day habit over four weekly readings.
  List<OdometerReadingEntity> steadyHistory() => [
    reading(40000, anchor),
    reading(41050, anchor.add(const Duration(days: 7))),
    reading(42100, anchor.add(const Duration(days: 14))),
    reading(43150, anchor.add(const Duration(days: 21))),
  ];

  group('policy bands', () {
    test('hard ceiling grows with the gap but stays an envelope', () {
      expect(policy.hardMaxDelta(1), 1500);
      expect(policy.hardMaxDelta(7), 1500 + 900 * 6);
      expect(policy.hardMaxDelta(30), 1500 + 900 * 29);
      // Sustained rate over a long gap stays near the sustained ceiling.
      expect(policy.hardMaxDelta(30) / 30, closeTo(920, 1));
    });

    test('soft band tightens as the gap lengthens', () {
      const baseline = 120.0;
      final oneDay = policy.softMaxDelta(1, baseline);
      final sevenDay = policy.softMaxDelta(7, baseline) / 7;
      final thirtyDay = policy.softMaxDelta(30, baseline) / 30;

      expect(oneDay, closeTo(660, 1));
      expect(sevenDay, closeTo(253, 2));
      expect(thirtyDay, closeTo(174, 2));

      // The permitted daily rate must shrink monotonically with the gap.
      expect(sevenDay, lessThan(oneDay));
      expect(thirtyDay, lessThan(sevenDay));
    });

    test('no low-rate check on short gaps: an idle vehicle is normal', () {
      expect(policy.softMinDelta(1, 120), 0);
      expect(policy.softMinDelta(7, 120), 0);
      expect(policy.softMinDelta(30, 120), closeTo(1986, 5));
    });
  });

  group('hard blocks', () {
    test('a reading below the previous one is refused', () {
      final result = validator.call(
        proposedValue: 42000,
        readingAt: anchor.add(const Duration(days: 28)),
        history: steadyHistory(),
      );
      expect(result.severity, OdometerSeverity.block);
      expect(result.flags, contains(OdometerFlag.belowPrevious));
      expect(result.canSave, isFalse);
    });

    test('a physically impossible jump is refused', () {
      final result = validator.call(
        proposedValue: 90000,
        readingAt: anchor.add(const Duration(days: 28)),
        history: steadyHistory(),
      );
      expect(result.severity, OdometerSeverity.block);
      expect(result.flags, contains(OdometerFlag.aboveHardCeiling));
    });

    test('a future-dated reading is refused', () {
      final result = validator.call(
        proposedValue: 44000,
        readingAt: DateTime.now().add(const Duration(days: 5)),
        history: steadyHistory(),
      );
      expect(result.severity, OdometerSeverity.block);
      expect(result.flags, contains(OdometerFlag.futureDated));
    });

    test('a lifetime-implausible value is refused even with no history', () {
      final result = validator.call(
        proposedValue: 9000000,
        readingAt: anchor,
        history: const [],
      );
      expect(result.severity, OdometerSeverity.block);
      expect(result.flags, contains(OdometerFlag.aboveLifetimeMax));
    });
  });

  group('the reported failure: an extra digit', () {
    test('43150 -> 441500 is caught and the right value is suggested', () {
      // The user meant 44,150 but typed an extra 0, giving 441,500.
      final result = validator.call(
        proposedValue: 441500,
        readingAt: anchor.add(const Duration(days: 28)),
        history: steadyHistory(),
      );

      expect(result.severity, OdometerSeverity.block);
      expect(result.hasSuggestions, isTrue);
      expect(
        result.suggestions.map((s) => s.value),
        contains(44150),
        reason: 'dropping the stray digit lands back inside the plausible band',
      );
    });

    test('a 10x slip inside the hard ceiling is still warned and corrected', () {
      // 43,500 typed as 435,000 would breach the hard ceiling, so use a case
      // that only breaches the soft band: 4,350 typed instead of 43,500.
      final result = validator.call(
        proposedValue: 435000,
        readingAt: anchor.add(const Duration(days: 28)),
        history: steadyHistory(),
      );
      expect(result.severity, OdometerSeverity.block);
      expect(result.suggestions.map((s) => s.value), contains(43500));
    });

    test('suggestions never point backwards or outside the band', () {
      final result = validator.call(
        proposedValue: 441500,
        readingAt: anchor.add(const Duration(days: 28)),
        history: steadyHistory(),
      );
      for (final s in result.suggestions) {
        expect(s.value, greaterThan(43150));
      }
    });
  });

  group('soft band behaviour', () {
    test('an ordinary weekly reading passes with no friction', () {
      final result = validator.call(
        proposedValue: 44200,
        readingAt: anchor.add(const Duration(days: 28)),
        history: steadyHistory(),
      );
      expect(result.severity, OdometerSeverity.ok);
      expect(result.dailyRate, closeTo(150, 1));
      expect(result.requiresPhoto, isFalse);
      expect(result.requiresConfirmation, isFalse);
      expect(result.resultingStatus, OdometerReadingStatus.accepted);
    });

    test('an unusually high but possible week warns and quarantines', () {
      // 3,000 km in a week = 428 km/day against a 150 km/day habit.
      final result = validator.call(
        proposedValue: 46150,
        readingAt: anchor.add(const Duration(days: 28)),
        history: steadyHistory(),
      );
      expect(result.severity, OdometerSeverity.warn);
      expect(result.flags, contains(OdometerFlag.rateHigh));
      expect(result.requiresPhoto, isTrue);
      expect(result.requiresConfirmation, isTrue);
      expect(result.resultingStatus, OdometerReadingStatus.quarantined);
      expect(result.canSave, isTrue, reason: 'never block a field entry');
    });

    test('a long quiet gap warns on the low side', () {
      final result = validator.call(
        proposedValue: 43300,
        readingAt: anchor.add(const Duration(days: 51)),
        history: steadyHistory(),
      );
      expect(result.severity, OdometerSeverity.warn);
      expect(result.flags, contains(OdometerFlag.rateLow));
    });

    test('a single big trip day is allowed without friction', () {
      final history = steadyHistory();
      final result = validator.call(
        proposedValue: 43700,
        readingAt: anchor.add(const Duration(days: 22)),
        history: history,
      );
      expect(
        result.severity,
        OdometerSeverity.ok,
        reason: '550 km in one day is a real Riyadh-Jeddah leg',
      );
    });
  });

  group('cross-source corroboration', () {
    test('no movement despite fuel spend is flagged', () {
      final result = validator.call(
        proposedValue: 43155,
        readingAt: anchor.add(const Duration(days: 28)),
        history: steadyHistory(),
        fuelSpendInWindow: 420,
      );
      expect(result.severity, OdometerSeverity.warn);
      expect(result.flags, contains(OdometerFlag.idleWithFuelSpend));
    });
  });

  group('baselines', () {
    test('the vehicle own median is preferred once history is thick enough', () {
      final result = validator.call(
        proposedValue: 44200,
        readingAt: anchor.add(const Duration(days: 28)),
        history: steadyHistory(),
        fleetDailyMedian: 20,
      );
      expect(result.band!.baselineIsOwn, isTrue);
      expect(result.band!.baselineDaily, closeTo(150, 1));
    });

    test('the fleet median carries a vehicle with thin history', () {
      final result = validator.call(
        proposedValue: 40500,
        readingAt: anchor.add(const Duration(days: 7)),
        history: [reading(40000, anchor)],
        fleetDailyMedian: 90,
      );
      expect(result.band!.baselineIsOwn, isFalse);
      expect(result.band!.baselineDaily, 90);
    });

    test('the first ever reading says so instead of pretending to check', () {
      final result = validator.call(
        proposedValue: 40000,
        readingAt: anchor,
        history: const [],
      );
      expect(result.severity, OdometerSeverity.info);
      expect(result.flags, contains(OdometerFlag.noHistory));
      expect(result.canSave, isTrue);
    });

    test('quarantined history is ignored when validating', () {
      final history = [
        reading(40000, anchor),
        reading(
          900000,
          anchor.add(const Duration(days: 3)),
          status: OdometerReadingStatus.quarantined,
        ),
      ];
      final result = validator.call(
        proposedValue: 40800,
        readingAt: anchor.add(const Duration(days: 7)),
        history: history,
      );
      expect(result.severity, OdometerSeverity.ok);
      expect(result.deltaKm, 800);
    });
  });
}
