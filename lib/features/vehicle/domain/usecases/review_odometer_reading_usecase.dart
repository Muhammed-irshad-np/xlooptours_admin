import 'package:uuid/uuid.dart';

import '../entities/odometer_reading_entity.dart';
import '../entities/vehicle_entity.dart';
import '../repositories/odometer_repository.dart';
import '../repositories/vehicle_repository.dart';

/// Settles a quarantined reading, or corrects an accepted one.
///
/// Nothing is ever edited in place. Accepting flips a status; rejecting flips a
/// status; correcting appends a new reading that *supersedes* the bad one. The
/// original observation, who entered it and when, survives in every case — the
/// series is the audit trail, and downstream maths is recomputed from it rather
/// than patched.
class ReviewOdometerReadingUseCase {
  final OdometerRepository odometerRepository;
  final VehicleRepository vehicleRepository;
  final Uuid _uuid;

  ReviewOdometerReadingUseCase({
    required this.odometerRepository,
    required this.vehicleRepository,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  /// Marks a quarantined reading as trustworthy after all.
  Future<VehicleEntity?> accept({
    required VehicleEntity vehicle,
    required OdometerReadingEntity reading,
    String? reviewerUid,
    String? reviewerName,
    String? note,
  }) async {
    final updated = reading.copyWith(
      status: OdometerReadingStatus.accepted,
      reviewedByUid: reviewerUid,
      reviewedByName: reviewerName,
      reviewedAt: DateTime.now(),
      reviewNote: note,
    );
    await odometerRepository.updateReadingReview(updated);
    return _refresh(vehicle);
  }

  /// Marks a reading as wrong. It stops counting immediately, and the vehicle's
  /// odometer falls back to the last remaining accepted reading.
  Future<VehicleEntity?> reject({
    required VehicleEntity vehicle,
    required OdometerReadingEntity reading,
    String? reviewerUid,
    String? reviewerName,
    String? note,
  }) async {
    final updated = reading.copyWith(
      status: OdometerReadingStatus.rejected,
      reviewedByUid: reviewerUid,
      reviewedByName: reviewerName,
      reviewedAt: DateTime.now(),
      reviewNote: note,
    );
    await odometerRepository.updateReadingReview(updated);
    return _refresh(vehicle);
  }

  /// Replaces a bad reading with the true value.
  ///
  /// The original is marked superseded and linked forward to the correction, so
  /// "what did we think the odometer was on the 12th, and who said so" stays
  /// answerable.
  Future<VehicleEntity?> correct({
    required VehicleEntity vehicle,
    required OdometerReadingEntity original,
    required int correctedValue,
    String? reviewerUid,
    String? reviewerName,
    String? note,
  }) async {
    final correction = OdometerReadingEntity(
      id: _uuid.v4(),
      vehicleId: vehicle.id,
      value: correctedValue,
      readingAt: original.readingAt,
      recordedAt: DateTime.now(),
      source: OdometerSource.correction,
      sourceRefId: original.id,
      enteredByUid: reviewerUid,
      enteredByName: reviewerName,
      status: OdometerReadingStatus.accepted,
      note: note,
      userConfirmed: true,
      supersedesReadingId: original.id,
    );
    await odometerRepository.insertReading(correction);

    await odometerRepository.updateReadingReview(
      original.copyWith(
        status: OdometerReadingStatus.superseded,
        supersededByReadingId: correction.id,
        reviewedByUid: reviewerUid,
        reviewedByName: reviewerName,
        reviewedAt: DateTime.now(),
        reviewNote: note,
      ),
    );

    return _refresh(vehicle);
  }

  /// Handles a genuinely replaced or rolled-over cluster.
  ///
  /// The only legitimate way an odometer goes down. Every prior reading is left
  /// intact but the new baseline starts here, so the "cannot go backwards" rule
  /// stays absolute everywhere else.
  Future<VehicleEntity?> recordClusterReplacement({
    required VehicleEntity vehicle,
    required int newValue,
    required DateTime replacedAt,
    String? reviewerUid,
    String? reviewerName,
    String? note,
  }) async {
    final existing = await odometerRepository.getReadings(vehicle.id);
    final now = DateTime.now();

    // Retire the old series: it describes a cluster that no longer exists.
    for (final r in existing.where((r) => r.isUsable)) {
      await odometerRepository.updateReadingReview(
        r.copyWith(
          status: OdometerReadingStatus.superseded,
          reviewedByUid: reviewerUid,
          reviewedByName: reviewerName,
          reviewedAt: now,
          reviewNote: 'Odometer cluster replaced on ${replacedAt.toIso8601String().split('T').first}.',
        ),
      );
    }

    final baseline = OdometerReadingEntity(
      id: _uuid.v4(),
      vehicleId: vehicle.id,
      value: newValue,
      readingAt: replacedAt,
      recordedAt: now,
      source: OdometerSource.correction,
      enteredByUid: reviewerUid,
      enteredByName: reviewerName,
      status: OdometerReadingStatus.accepted,
      note: note ?? 'New baseline after odometer cluster replacement.',
      userConfirmed: true,
    );
    await odometerRepository.insertReading(baseline);

    return _refresh(vehicle);
  }

  /// Recomputes the vehicle's derived odometer from whatever is still accepted.
  Future<VehicleEntity?> _refresh(VehicleEntity vehicle) async {
    final readings = await odometerRepository.getReadings(vehicle.id);
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
