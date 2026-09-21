import 'dart:math' as math;

import '../entities/odometer_policy.dart';
import '../entities/odometer_reading_entity.dart';
import '../entities/odometer_review_item.dart';
import '../entities/vehicle_entity.dart';

/// Builds the list of odometer readings a human needs to look at.
///
/// Three independent signals feed it:
///   1. readings quarantined at entry time because they fell outside the band,
///   2. accepted readings from different sources that contradict each other —
///      the reconciliation layer, and the reason expense and maintenance
///      mileages are worth logging at all,
///   3. vehicles with no recent reading, where the stored odometer has quietly
///      gone stale and is still driving maintenance alerts.
class GetOdometerReviewQueueUseCase {
  final OdometerPolicy policy;

  const GetOdometerReviewQueueUseCase({this.policy = OdometerPolicy.defaults});

  /// [readingsByVehicle] maps vehicle id to that vehicle's readings.
  List<OdometerReviewItem> call({
    required List<VehicleEntity> vehicles,
    required Map<String, List<OdometerReadingEntity>> readingsByVehicle,
  }) {
    final items = <OdometerReviewItem>[];
    final now = DateTime.now();

    for (final vehicle in vehicles) {
      if (!vehicle.isActive) continue;

      // Explicitly typed: an untyped `const []` fallback makes the whole list
      // infer as List<dynamic>, which the analyzer tolerates but the compiler
      // rejects at the call sites below.
      final readings = <OdometerReadingEntity>[
        ...?readingsByVehicle[vehicle.id],
      ]..sort((a, b) => a.readingAt.compareTo(b.readingAt));

      final accepted = readings.where((r) => r.isUsable).toList();

      // 1. Quarantined readings.
      for (final r in readings.where((r) => r.needsReview)) {
        final previous = _lastAcceptedBefore(accepted, r.readingAt);
        items.add(
          OdometerReviewItem(
            vehicle: vehicle,
            reason: OdometerReviewReason.quarantined,
            reading: r,
            previous: previous,
            explanation: _explainQuarantine(r, previous),
            priority: _quarantinePriority(r, previous),
          ),
        );
      }

      // 2. Cross-source contradictions among accepted readings.
      for (final conflict in _findConflicts(accepted)) {
        items.add(
          OdometerReviewItem(
            vehicle: vehicle,
            reason: OdometerReviewReason.crossSourceConflict,
            reading: conflict.later,
            conflictsWith: conflict.earlier,
            explanation:
                '${conflict.earlier.source.label} recorded '
                '${_km(conflict.earlier.value)} km on '
                '${_date(conflict.earlier.readingAt)}, but '
                '${conflict.later.source.label} recorded '
                '${_km(conflict.later.value)} km on '
                '${_date(conflict.later.readingAt)} — '
                '${_km(conflict.impliedRate.round())} km/day apart.',
            priority: math.min(90, 40 + conflict.impliedRate ~/ 20),
          ),
        );
      }

      // 3. Stale odometer still driving maintenance alerts.
      final lastAccepted = accepted.isEmpty ? null : accepted.last;
      final lastAt = lastAccepted?.readingAt ?? vehicle.lastOdometerUpdateDate;
      final daysStale = lastAt == null
          ? null
          : now.difference(lastAt).inDays;
      if (daysStale == null || daysStale > policy.stalenessDays) {
        items.add(
          OdometerReviewItem(
            vehicle: vehicle,
            reason: OdometerReviewReason.stale,
            reading: lastAccepted,
            explanation: daysStale == null
                ? 'This vehicle has never had an odometer reading recorded.'
                : 'Last reading was $daysStale days ago. Maintenance alerts '
                      'are still being calculated from it.',
            priority: daysStale == null ? 50 : math.min(80, 20 + daysStale),
          ),
        );
      }
    }

    items.sort((a, b) => b.priority.compareTo(a.priority));
    return items;
  }

  /// Two readings disagree when, taken together, they imply an impossible or
  /// wildly improbable rate — including one that runs backwards.
  List<_Conflict> _findConflicts(List<OdometerReadingEntity> accepted) {
    final out = <_Conflict>[];
    for (var i = 1; i < accepted.length; i++) {
      final earlier = accepted[i - 1];
      final later = accepted[i];

      // Different sources only: the same source repeating itself is a trend,
      // not a contradiction.
      if (earlier.source == later.source) continue;

      final days = math.max(
        0.5,
        later.readingAt.difference(earlier.readingAt).inHours / 24.0,
      );
      final delta = later.value - earlier.value;

      if (delta < 0) {
        out.add(
          _Conflict(
            earlier: earlier,
            later: later,
            impliedRate: delta.abs() / days,
          ),
        );
        continue;
      }

      final rate = delta / days;
      if (rate > policy.hardMaxDelta(days.round()) / math.max(1, days.round())) {
        out.add(_Conflict(earlier: earlier, later: later, impliedRate: rate));
      }
    }
    return out;
  }

  static OdometerReadingEntity? _lastAcceptedBefore(
    List<OdometerReadingEntity> accepted,
    DateTime at,
  ) {
    OdometerReadingEntity? found;
    for (final r in accepted) {
      if (r.readingAt.isAfter(at)) break;
      found = r;
    }
    return found;
  }

  String _explainQuarantine(
    OdometerReadingEntity r,
    OdometerReadingEntity? previous,
  ) {
    final flagText = r.flags.isEmpty
        ? 'Flagged at entry.'
        : r.flags.map((f) => f.label).join('. ');
    if (previous == null) return flagText;
    final days = math.max(
      1,
      r.readingAt.difference(previous.readingAt).inDays,
    );
    final delta = r.value - previous.value;
    return '$flagText — ${_km(previous.value)} km to ${_km(r.value)} km in '
        '$days day${days == 1 ? '' : 's'} (${_km((delta / days).round())} km/day).';
  }

  int _quarantinePriority(
    OdometerReadingEntity r,
    OdometerReadingEntity? previous,
  ) {
    var p = 60;
    if (r.flags.contains(OdometerFlag.aboveHardCeiling)) p += 30;
    if (r.flags.contains(OdometerFlag.belowPrevious)) p += 25;
    if (r.flags.contains(OdometerFlag.idleWithFuelSpend)) p += 20;
    if (r.flags.contains(OdometerFlag.digitSlipSuspected)) p += 15;
    if (r.photoUrl != null) p -= 10; // evidence attached, easier to settle
    if (r.userConfirmed) p -= 5;
    return p.clamp(0, 100);
  }

  static String _km(int v) {
    final s = v.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '${v < 0 ? '-' : ''}$buf';
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

class _Conflict {
  final OdometerReadingEntity earlier;
  final OdometerReadingEntity later;
  final double impliedRate;
  const _Conflict({
    required this.earlier,
    required this.later,
    required this.impliedRate,
  });
}
