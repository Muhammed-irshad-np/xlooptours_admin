import 'package:equatable/equatable.dart';

import 'odometer_reading_entity.dart';
import 'vehicle_entity.dart';

/// Why a reading landed in the review queue.
enum OdometerReviewReason {
  /// Saved outside the plausible band and held back from the alert maths.
  quarantined,

  /// Two sources recorded incompatible readings for roughly the same moment.
  crossSourceConflict,

  /// No accepted reading for longer than the staleness window.
  stale,
}

extension OdometerReviewReasonX on OdometerReviewReason {
  String get label {
    switch (this) {
      case OdometerReviewReason.quarantined:
        return 'Outside plausible range';
      case OdometerReviewReason.crossSourceConflict:
        return 'Sources disagree';
      case OdometerReviewReason.stale:
        return 'No recent reading';
    }
  }
}

/// One row in the review queue, carrying enough context that a reviewer can
/// decide without opening five other screens.
class OdometerReviewItem extends Equatable {
  final VehicleEntity vehicle;
  final OdometerReviewReason reason;

  /// The reading under question. Null for a [OdometerReviewReason.stale] row,
  /// which is about the absence of a reading.
  final OdometerReadingEntity? reading;

  /// The last accepted reading before [reading], for comparison.
  final OdometerReadingEntity? previous;

  /// The other side of a cross-source disagreement.
  final OdometerReadingEntity? conflictsWith;

  final String explanation;

  /// Higher sorts first. Driven by how wrong the reading could be and how much
  /// downstream maintenance maths it would distort.
  final int priority;

  const OdometerReviewItem({
    required this.vehicle,
    required this.reason,
    required this.explanation,
    required this.priority,
    this.reading,
    this.previous,
    this.conflictsWith,
  });

  @override
  List<Object?> get props => [
    vehicle.id,
    reason,
    reading?.id,
    previous?.id,
    conflictsWith?.id,
    explanation,
    priority,
  ];
}
