import 'package:equatable/equatable.dart';

import 'odometer_reading_entity.dart';

/// How bad a proposed reading looks.
enum OdometerSeverity {
  /// Inside the plausible band. Saves with one tap.
  ok,

  /// Worth mentioning but not worth friction (e.g. the vehicle has no history
  /// yet, so nothing could be checked).
  info,

  /// Outside the plausible band. Saveable, but the entrant must confirm, a
  /// photo is required, and the reading lands quarantined for review.
  warn,

  /// Physically impossible. Cannot be saved at all.
  block,
}

extension OdometerSeverityX on OdometerSeverity {
  bool get canSave => this != OdometerSeverity.block;
  bool get isSuspicious =>
      this == OdometerSeverity.warn || this == OdometerSeverity.block;
}

/// How a suggested correction was derived, so the UI can explain itself.
enum OdometerSuggestionKind {
  /// One digit too many — the value is 10x what it should be.
  extraDigit,

  /// One digit missing — the value is 1/10th of what it should be.
  missingDigit,

  /// A digit was dropped somewhere in the middle.
  droppedDigit,

  /// Two adjacent digits were swapped.
  transposedDigits,

  /// The previous reading, offered when someone clearly meant "no change".
  previousValue,
}

extension OdometerSuggestionKindX on OdometerSuggestionKind {
  String get label {
    switch (this) {
      case OdometerSuggestionKind.extraDigit:
        return 'one digit too many';
      case OdometerSuggestionKind.missingDigit:
        return 'a missing digit';
      case OdometerSuggestionKind.droppedDigit:
        return 'a dropped digit';
      case OdometerSuggestionKind.transposedDigits:
        return 'two swapped digits';
      case OdometerSuggestionKind.previousValue:
        return 'the previous reading';
    }
  }
}

/// A plausible value the entrant probably meant, offered as a one-tap fix.
class OdometerSuggestion extends Equatable {
  final int value;
  final OdometerSuggestionKind kind;

  /// Implied km/day if this suggestion were accepted. Shown next to the
  /// suggestion so the entrant can judge it rather than trust it blindly.
  final double dailyRate;

  const OdometerSuggestion({
    required this.value,
    required this.kind,
    required this.dailyRate,
  });

  @override
  List<Object?> get props => [value, kind, dailyRate];
}

/// The plausible band for a proposed reading, in absolute odometer values.
class OdometerBand extends Equatable {
  final int minValue;
  final int maxValue;
  final double baselineDaily;
  final int days;

  /// True when [baselineDaily] came from this vehicle's own history rather
  /// than the fleet median or the configured fallback.
  final bool baselineIsOwn;

  const OdometerBand({
    required this.minValue,
    required this.maxValue,
    required this.baselineDaily,
    required this.days,
    required this.baselineIsOwn,
  });

  bool contains(int value) => value >= minValue && value <= maxValue;

  @override
  List<Object?> get props => [
    minValue,
    maxValue,
    baselineDaily,
    days,
    baselineIsOwn,
  ];
}

/// The verdict on a proposed reading.
class OdometerValidationResult extends Equatable {
  final OdometerSeverity severity;

  /// Short headline for the UI, e.g. "That is 1,550 km/day".
  final String title;

  /// One or two sentences explaining what looks wrong and why.
  final String message;

  final List<OdometerFlag> flags;
  final List<OdometerSuggestion> suggestions;

  /// Kilometres added since the previous accepted reading. Null when there is
  /// no previous reading to compare against.
  final int? deltaKm;

  /// Whole days between the previous accepted reading and this one.
  final int? daysElapsed;

  /// Implied km/day. Null when there is no previous reading.
  final double? dailyRate;

  /// The plausible band, when one could be computed.
  final OdometerBand? band;

  final bool requiresPhoto;
  final bool requiresConfirmation;

  /// Status the reading should be written with if the entrant proceeds.
  final OdometerReadingStatus resultingStatus;

  const OdometerValidationResult({
    required this.severity,
    required this.title,
    required this.message,
    this.flags = const [],
    this.suggestions = const [],
    this.deltaKm,
    this.daysElapsed,
    this.dailyRate,
    this.band,
    this.requiresPhoto = false,
    this.requiresConfirmation = false,
    this.resultingStatus = OdometerReadingStatus.accepted,
  });

  bool get canSave => severity.canSave;
  bool get hasSuggestions => suggestions.isNotEmpty;

  @override
  List<Object?> get props => [
    severity,
    title,
    message,
    flags,
    suggestions,
    deltaKm,
    daysElapsed,
    dailyRate,
    band,
    requiresPhoto,
    requiresConfirmation,
    resultingStatus,
  ];
}
