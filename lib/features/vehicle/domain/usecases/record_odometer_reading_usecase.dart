import 'package:uuid/uuid.dart';

import '../entities/odometer_policy.dart';
import '../entities/odometer_reading_entity.dart';
import '../entities/odometer_validation.dart';
import '../entities/vehicle_entity.dart';
import '../repositories/odometer_repository.dart';
import '../repositories/vehicle_repository.dart';
import 'validate_odometer_reading_usecase.dart';

/// Thrown when a reading is physically impossible and the caller asked to be
/// stopped rather than to quarantine it.
class OdometerReadingRejected implements Exception {
  final OdometerValidationResult validation;
  const OdometerReadingRejected(this.validation);

  @override
  String toString() => 'OdometerReadingRejected: ${validation.title}';
}

class RecordOdometerReadingResult {
  final OdometerReadingEntity reading;
  final OdometerValidationResult validation;

  /// The vehicle after its derived `currentOdometer` was refreshed, or null
  /// when the reading did not move it (quarantined, or older than the latest).
  final VehicleEntity? updatedVehicle;

  const RecordOdometerReadingResult({
    required this.reading,
    required this.validation,
    this.updatedVehicle,
  });

  bool get wasAccepted => reading.status == OdometerReadingStatus.accepted;
  bool get needsReview => reading.needsReview;
}

/// The one and only way an odometer value enters the system.
///
/// Before this existed, five screens each wrote `currentOdometer` with their
/// own rules (or none). Everything now routes here, so validation, evidence,
/// attribution and the audit trail cannot be bypassed by adding a sixth screen.
class RecordOdometerReadingUseCase {
  final OdometerRepository odometerRepository;
  final VehicleRepository vehicleRepository;
  final ValidateOdometerReadingUseCase validator;
  final OdometerPolicy policy;
  final Uuid _uuid;

  RecordOdometerReadingUseCase({
    required this.odometerRepository,
    required this.vehicleRepository,
    required this.validator,
    this.policy = OdometerPolicy.defaults,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  /// Records [value] against [vehicle].
  ///
  /// [throwOnBlock] controls what happens to an impossible value. Interactive
  /// screens pass true so the entrant is stopped and offered a correction.
  /// Background captures (a mileage typed onto an expense) pass false: the
  /// reading is quarantined instead of discarded, because a contradiction is
  /// worth reviewing and a silently dropped number is not.
  Future<RecordOdometerReadingResult> call({
    required VehicleEntity vehicle,
    required int value,
    required OdometerSource source,
    DateTime? readingAt,
    String? sourceRefId,
    String? enteredByUid,
    String? enteredByName,
    String? photoUrl,
    String? note,
    bool userConfirmed = false,
    double fuelSpendInWindow = 0,
    double? fleetDailyMedian,
    List<OdometerReadingEntity>? history,
    bool throwOnBlock = true,
  }) async {
    final at = readingAt ?? DateTime.now();

    var readings = history ?? await odometerRepository.getReadings(vehicle.id);

    // Legacy vehicles carry a `currentOdometer` that predates this log. Seed it
    // as a real reading so the first validated entry has something to check
    // against, instead of sailing through as "no history".
    readings = await _seedIfEmpty(vehicle, readings);

    final validation = validator.call(
      proposedValue: value,
      readingAt: at,
      history: readings,
      fleetDailyMedian: fleetDailyMedian,
      fuelSpendInWindow: fuelSpendInWindow,
      source: source,
    );

    if (validation.severity == OdometerSeverity.block && throwOnBlock) {
      throw OdometerReadingRejected(validation);
    }

    // A blocked value from a non-interactive source is still evidence. Keep it,
    // flagged, for a human to adjudicate.
    final status = validation.severity == OdometerSeverity.block
        ? OdometerReadingStatus.quarantined
        : validation.resultingStatus;

    final reading = OdometerReadingEntity(
      id: _uuid.v4(),
      vehicleId: vehicle.id,
      value: value,
      readingAt: at,
      recordedAt: DateTime.now(),
      source: source,
      sourceRefId: sourceRefId,
      enteredByUid: enteredByUid,
      enteredByName: enteredByName,
      photoUrl: photoUrl,
      status: status,
      flags: validation.flags,
      note: note,
      userConfirmed: userConfirmed,
    );

    await odometerRepository.insertReading(reading);

    final updated = await _refreshVehicleOdometer(
      vehicle,
      [...readings, reading],
    );

    return RecordOdometerReadingResult(
      reading: reading,
      validation: validation,
      updatedVehicle: updated,
    );
  }

  /// Writes the vehicle's pre-existing `currentOdometer` into the log as an
  /// `initial` reading, so the series has an anchor. Returns the history to use.
  Future<List<OdometerReadingEntity>> _seedIfEmpty(
    VehicleEntity vehicle,
    List<OdometerReadingEntity> readings,
  ) async {
    if (readings.isNotEmpty) return readings;

    final seedValue = vehicle.currentOdometer ?? vehicle.purchaseOdometer;
    if (seedValue == null || seedValue <= 0) return readings;

    final seed = OdometerReadingEntity(
      id: _uuid.v4(),
      vehicleId: vehicle.id,
      value: seedValue,
      readingAt:
          vehicle.lastOdometerUpdateDate ??
          vehicle.purchaseDate ??
          DateTime.now().subtract(const Duration(days: 7)),
      recordedAt: DateTime.now(),
      source: OdometerSource.initial,
      note: 'Seeded from the vehicle record when the reading log was created.',
      status: OdometerReadingStatus.accepted,
    );

    await odometerRepository.insertReading(seed);
    return [seed];
  }

  /// Recomputes the derived `currentOdometer` cache from accepted readings.
  ///
  /// `currentOdometer` is no longer authoritative — it is a cache of the latest
  /// accepted reading, so a quarantined entry cannot move it and a correction
  /// can always restore the truth.
  Future<VehicleEntity?> _refreshVehicleOdometer(
    VehicleEntity vehicle,
    List<OdometerReadingEntity> readings,
  ) async {
    final accepted = readings.where((r) => r.isUsable).toList()
      ..sort((a, b) => a.readingAt.compareTo(b.readingAt));
    if (accepted.isEmpty) return null;

    final latest = accepted.last;
    if (vehicle.currentOdometer == latest.value &&
        vehicle.lastOdometerUpdateDate == latest.readingAt) {
      return null;
    }

    final updated = vehicle.copyWith(
      currentOdometer: latest.value,
      lastOdometerUpdateDate: latest.readingAt,
    );
    await vehicleRepository.updateVehicle(updated);
    return updated;
  }
}
