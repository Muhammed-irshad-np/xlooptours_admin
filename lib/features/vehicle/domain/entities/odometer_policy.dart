import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// Every threshold the odometer plausibility engine uses, in one place.
///
/// The central idea: a single odometer number cannot be judged on its own.
/// 47,240 km is meaningless until you know it followed 45,000 km eight days
/// ago — which makes it 280 km/day. So every limit here is expressed against
/// the *rate of change*, and every band is **gap-aware**.
///
/// Gap-awareness matters because the variance of a daily average shrinks with
/// the length of the window. A vehicle can genuinely do 600 km in one day, or
/// sit idle. It cannot genuinely average 600 km/day for a month. The bands
/// therefore open up for short gaps and tighten as days accumulate, following
/// a 1/sqrt(days) tolerance.
class OdometerPolicy extends Equatable {
  // ── Hard limits: physically impossible, never saveable ────────────────────

  /// No road vehicle reaches this. Guards against a paste or a stray keypress
  /// producing an eight-digit number.
  final int lifetimeMaxKm;

  /// Ceiling for the first day of any gap. 1,500 km is roughly 15 hours at
  /// highway speed; Riyadh to Jeddah is about 950 km. A single vehicle-day
  /// above this is an error, not a long trip.
  final int hardMaxFirstDayKm;

  /// Ceiling for every additional day in the gap. Sustained 900 km/day is
  /// already beyond any realistic duty cycle, so the envelope over a long gap
  /// is generous without being useless.
  final int hardMaxSustainedDailyKm;

  // ── Soft band: suspicious, saveable but quarantined ───────────────────────

  /// Used when the vehicle has too little history of its own and the fleet has
  /// no usable median either. Tuned for tour / rental duty in KSA.
  final double fallbackDailyKm;

  /// How many completed intervals a vehicle needs before the engine trusts its
  /// own median over the fleet median.
  final int minIntervalsForOwnBaseline;

  /// Tolerance multiplier. The band is `baseline * days * (1 +/- K/sqrt(days))`.
  /// K = 2.0 approximates a two-sigma band for day-to-day usage that varies
  /// roughly as much as its own mean.
  final double toleranceK;

  /// Flat slack added to both ends, so a vehicle that normally does 20 km/day
  /// is not flagged for one 300 km airport run.
  final int slackKm;

  /// Below this gap the engine will not flag a low reading at all — a vehicle
  /// idle for a few days is ordinary, not suspicious.
  final int minDaysForLowRateCheck;

  /// A reading this close to the previous one over a long gap is treated as
  /// "did not move", which is only interesting if money was spent on fuel.
  final int idleDeltaKm;

  // ── Staleness / cadence ───────────────────────────────────────────────────

  /// After this many days without an accepted reading, `currentOdometer` is
  /// shown as stale and the band widens rather than punishing the catch-up
  /// entry that finally arrives.
  final int stalenessDays;

  // ── Evidence policy ───────────────────────────────────────────────────────

  /// Require a cluster photo when the reading falls outside the soft band.
  /// Deliberately not required on the happy path: mandatory photos on every
  /// entry train people to photograph anything, and slow the weekly round to
  /// the point it gets skipped.
  final bool requirePhotoOutOfBand;

  /// Require the entrant to re-type the value (or tick a verification box)
  /// before an out-of-band reading can be saved.
  final bool requireConfirmationOutOfBand;

  /// Save out-of-band readings as quarantined rather than refusing them.
  /// Blocking a driver in the field means the reading is simply never recorded,
  /// which is the worse failure.
  final bool quarantineOutOfBand;

  const OdometerPolicy({
    this.lifetimeMaxKm = 2000000,
    this.hardMaxFirstDayKm = 1500,
    this.hardMaxSustainedDailyKm = 900,
    this.fallbackDailyKm = 120,
    this.minIntervalsForOwnBaseline = 3,
    this.toleranceK = 2.0,
    this.slackKm = 300,
    this.minDaysForLowRateCheck = 10,
    this.idleDeltaKm = 20,
    this.stalenessDays = 21,
    this.requirePhotoOutOfBand = true,
    this.requireConfirmationOutOfBand = true,
    this.quarantineOutOfBand = true,
  });

  static const OdometerPolicy defaults = OdometerPolicy();

  /// Largest delta that is physically possible across [days].
  ///
  /// Clamped to at least one day so a same-day second reading still gets the
  /// full first-day allowance.
  int hardMaxDelta(int days) {
    final d = math.max(1, days);
    return hardMaxFirstDayKm + hardMaxSustainedDailyKm * (d - 1);
  }

  /// Upper edge of the plausible band for [days] at [baselineDaily] km/day.
  double softMaxDelta(int days, double baselineDaily) {
    final d = math.max(1, days).toDouble();
    final expected = baselineDaily * d;
    return expected * (1 + toleranceK / math.sqrt(d)) + slackKm;
  }

  /// Lower edge of the plausible band. Returns 0 for short gaps, where idling
  /// is ordinary and a low reading carries no information.
  double softMinDelta(int days, double baselineDaily) {
    if (days < minDaysForLowRateCheck) return 0;
    final d = days.toDouble();
    final expected = baselineDaily * d;
    final lower = expected * (1 - toleranceK / math.sqrt(d)) - slackKm;
    return lower < 0 ? 0 : lower;
  }

  OdometerPolicy copyWith({
    int? lifetimeMaxKm,
    int? hardMaxFirstDayKm,
    int? hardMaxSustainedDailyKm,
    double? fallbackDailyKm,
    int? minIntervalsForOwnBaseline,
    double? toleranceK,
    int? slackKm,
    int? minDaysForLowRateCheck,
    int? idleDeltaKm,
    int? stalenessDays,
    bool? requirePhotoOutOfBand,
    bool? requireConfirmationOutOfBand,
    bool? quarantineOutOfBand,
  }) {
    return OdometerPolicy(
      lifetimeMaxKm: lifetimeMaxKm ?? this.lifetimeMaxKm,
      hardMaxFirstDayKm: hardMaxFirstDayKm ?? this.hardMaxFirstDayKm,
      hardMaxSustainedDailyKm:
          hardMaxSustainedDailyKm ?? this.hardMaxSustainedDailyKm,
      fallbackDailyKm: fallbackDailyKm ?? this.fallbackDailyKm,
      minIntervalsForOwnBaseline:
          minIntervalsForOwnBaseline ?? this.minIntervalsForOwnBaseline,
      toleranceK: toleranceK ?? this.toleranceK,
      slackKm: slackKm ?? this.slackKm,
      minDaysForLowRateCheck:
          minDaysForLowRateCheck ?? this.minDaysForLowRateCheck,
      idleDeltaKm: idleDeltaKm ?? this.idleDeltaKm,
      stalenessDays: stalenessDays ?? this.stalenessDays,
      requirePhotoOutOfBand:
          requirePhotoOutOfBand ?? this.requirePhotoOutOfBand,
      requireConfirmationOutOfBand:
          requireConfirmationOutOfBand ?? this.requireConfirmationOutOfBand,
      quarantineOutOfBand: quarantineOutOfBand ?? this.quarantineOutOfBand,
    );
  }

  Map<String, dynamic> toJson() => {
    'lifetimeMaxKm': lifetimeMaxKm,
    'hardMaxFirstDayKm': hardMaxFirstDayKm,
    'hardMaxSustainedDailyKm': hardMaxSustainedDailyKm,
    'fallbackDailyKm': fallbackDailyKm,
    'minIntervalsForOwnBaseline': minIntervalsForOwnBaseline,
    'toleranceK': toleranceK,
    'slackKm': slackKm,
    'minDaysForLowRateCheck': minDaysForLowRateCheck,
    'idleDeltaKm': idleDeltaKm,
    'stalenessDays': stalenessDays,
    'requirePhotoOutOfBand': requirePhotoOutOfBand,
    'requireConfirmationOutOfBand': requireConfirmationOutOfBand,
    'quarantineOutOfBand': quarantineOutOfBand,
  };

  factory OdometerPolicy.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const OdometerPolicy();
    const d = OdometerPolicy();
    return OdometerPolicy(
      lifetimeMaxKm: (json['lifetimeMaxKm'] as num?)?.toInt() ?? d.lifetimeMaxKm,
      hardMaxFirstDayKm:
          (json['hardMaxFirstDayKm'] as num?)?.toInt() ?? d.hardMaxFirstDayKm,
      hardMaxSustainedDailyKm:
          (json['hardMaxSustainedDailyKm'] as num?)?.toInt() ??
          d.hardMaxSustainedDailyKm,
      fallbackDailyKm:
          (json['fallbackDailyKm'] as num?)?.toDouble() ?? d.fallbackDailyKm,
      minIntervalsForOwnBaseline:
          (json['minIntervalsForOwnBaseline'] as num?)?.toInt() ??
          d.minIntervalsForOwnBaseline,
      toleranceK: (json['toleranceK'] as num?)?.toDouble() ?? d.toleranceK,
      slackKm: (json['slackKm'] as num?)?.toInt() ?? d.slackKm,
      minDaysForLowRateCheck:
          (json['minDaysForLowRateCheck'] as num?)?.toInt() ??
          d.minDaysForLowRateCheck,
      idleDeltaKm: (json['idleDeltaKm'] as num?)?.toInt() ?? d.idleDeltaKm,
      stalenessDays:
          (json['stalenessDays'] as num?)?.toInt() ?? d.stalenessDays,
      requirePhotoOutOfBand:
          json['requirePhotoOutOfBand'] as bool? ?? d.requirePhotoOutOfBand,
      requireConfirmationOutOfBand:
          json['requireConfirmationOutOfBand'] as bool? ??
          d.requireConfirmationOutOfBand,
      quarantineOutOfBand:
          json['quarantineOutOfBand'] as bool? ?? d.quarantineOutOfBand,
    );
  }

  @override
  List<Object?> get props => [
    lifetimeMaxKm,
    hardMaxFirstDayKm,
    hardMaxSustainedDailyKm,
    fallbackDailyKm,
    minIntervalsForOwnBaseline,
    toleranceK,
    slackKm,
    minDaysForLowRateCheck,
    idleDeltaKm,
    stalenessDays,
    requirePhotoOutOfBand,
    requireConfirmationOutOfBand,
    quarantineOutOfBand,
  ];
}
