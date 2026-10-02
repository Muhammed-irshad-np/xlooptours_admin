import 'dart:math' as math;

import '../entities/odometer_policy.dart';
import '../entities/odometer_reading_entity.dart';
import '../entities/odometer_validation.dart';

/// Decides whether a proposed odometer value is plausible.
///
/// The engine never judges a number on its own. It works from three things:
///   1. the rate of change since the last accepted reading,
///   2. a baseline learned from this vehicle's own history (falling back to the
///      fleet median, then to a configured default),
///   3. corroborating evidence, such as fuel spend during a window in which the
///      vehicle supposedly did not move.
///
/// Pure domain logic: no I/O, no Flutter. Everything it needs is passed in,
/// which also makes the bands trivial to unit-test.
class ValidateOdometerReadingUseCase {
  final OdometerPolicy policy;

  const ValidateOdometerReadingUseCase({
    this.policy = OdometerPolicy.defaults,
  });

  /// [history] must be this vehicle's readings, any order; only accepted ones
  /// are used. [fleetDailyMedian] is the median km/day across the fleet, used
  /// when the vehicle has too little history of its own. [fuelSpendInWindow]
  /// lets the caller report whether money was spent on fuel between the last
  /// reading and this one.
  OdometerValidationResult call({
    required int proposedValue,
    required DateTime readingAt,
    required List<OdometerReadingEntity> history,
    double? fleetDailyMedian,
    double fuelSpendInWindow = 0,
    OdometerSource source = OdometerSource.weeklyUpdate,
  }) {
    final flags = <OdometerFlag>[];

    // ── Frame-level sanity, independent of any history ─────────────────────
    if (proposedValue < 0) {
      return _block(
        title: 'Odometer cannot be negative',
        message: 'Enter the reading exactly as it appears on the cluster.',
        flags: const [OdometerFlag.belowPrevious],
      );
    }

    if (proposedValue > policy.lifetimeMaxKm) {
      return _block(
        title: 'That reading is impossible',
        message:
            '${_km(proposedValue)} km is beyond the lifetime of any road '
            'vehicle. Check for an extra digit.',
        flags: const [OdometerFlag.aboveLifetimeMax],
        suggestions: _suggestionsFor(
          proposedValue,
          lastValue: null,
          days: 1,
          band: null,
        ),
      );
    }

    final now = DateTime.now();
    if (readingAt.isAfter(now.add(const Duration(days: 1)))) {
      return _block(
        title: 'Reading is dated in the future',
        message: 'Pick the date the cluster was actually read.',
        flags: const [OdometerFlag.futureDated],
      );
    }

    // ── Establish the comparison point ─────────────────────────────────────
    final accepted = _acceptedBefore(history, readingAt);

    if (accepted.isEmpty) {
      // Nothing to compare against. Say so honestly rather than pretending the
      // value was checked — this is exactly the case where a typo sails through,
      // so the first reading on a vehicle is worth a light touch of friction.
      return OdometerValidationResult(
        severity: OdometerSeverity.info,
        title: 'First reading for this vehicle',
        message:
            'There is no earlier reading to check this against. Double-check '
            'the digits before saving — later readings are validated against '
            'this one.',
        flags: const [OdometerFlag.noHistory],
        requiresPhoto: false,
        requiresConfirmation: false,
        resultingStatus: OdometerReadingStatus.accepted,
      );
    }

    final last = accepted.last;
    final lastValue = last.value;
    final rawDays = readingAt.difference(last.readingAt).inHours / 24.0;
    final days = math.max(1, rawDays.round());
    final delta = proposedValue - lastValue;
    final dailyRate = delta / days;

    // ── Hard limit: odometers do not run backwards ─────────────────────────
    if (delta < 0) {
      return _block(
        title: 'Lower than the last reading',
        message:
            'This vehicle already read ${_km(lastValue)} km on '
            '${_date(last.readingAt)}. An odometer cannot go down. If the '
            'cluster was replaced, use Odometer replaced from the vehicle '
            'screen instead.',
        flags: const [OdometerFlag.belowPrevious],
        deltaKm: delta,
        daysElapsed: days,
        dailyRate: dailyRate,
        suggestions: _suggestionsFor(
          proposedValue,
          lastValue: lastValue,
          days: days,
          band: null,
        ),
      );
    }

    // ── Hard limit: physically impossible distance ─────────────────────────
    final hardMax = policy.hardMaxDelta(days);
    if (delta > hardMax) {
      final band = _bandFor(
        lastValue: lastValue,
        days: days,
        history: accepted,
        fleetDailyMedian: fleetDailyMedian,
      );
      return _block(
        title: 'That is ${_rate(dailyRate)} km/day',
        message:
            'Going from ${_km(lastValue)} to ${_km(proposedValue)} km in '
            '${_days(days)} means ${_km(delta)} km. The most this vehicle '
            'could physically cover is about ${_km(hardMax)} km.',
        flags: const [OdometerFlag.aboveHardCeiling],
        deltaKm: delta,
        daysElapsed: days,
        dailyRate: dailyRate,
        band: band,
        suggestions: _suggestionsFor(
          proposedValue,
          lastValue: lastValue,
          days: days,
          band: band,
        ),
      );
    }

    // ── Soft band ──────────────────────────────────────────────────────────
    final band = _bandFor(
      lastValue: lastValue,
      days: days,
      history: accepted,
      fleetDailyMedian: fleetDailyMedian,
    );

    // Identical to the previous reading. Harmless on its own, but over a long
    // gap it usually means someone re-confirmed the stale number instead of
    // walking out to the vehicle.
    if (delta == 0 && days >= policy.minDaysForLowRateCheck) {
      flags.add(OdometerFlag.duplicateValue);
    }

    // Did not move, but fuel was bought. Two records contradicting each other
    // is a stronger signal than either one alone.
    if (delta <= policy.idleDeltaKm && fuelSpendInWindow > 0) {
      flags.add(OdometerFlag.idleWithFuelSpend);
      return _warn(
        title: 'Barely moved, but fuel was purchased',
        message:
            'Only ${_km(delta)} km were added over ${_days(days)}, yet '
            '${fuelSpendInWindow.toStringAsFixed(0)} SAR of fuel was recorded '
            'for this vehicle in the same period. One of the two is wrong.',
        flags: flags,
        deltaKm: delta,
        daysElapsed: days,
        dailyRate: dailyRate,
        band: band,
        suggestions: _suggestionsFor(
          proposedValue,
          lastValue: lastValue,
          days: days,
          band: band,
        ),
      );
    }

    if (proposedValue > band.maxValue) {
      flags.add(OdometerFlag.rateHigh);
      final suggestions = _suggestionsFor(
        proposedValue,
        lastValue: lastValue,
        days: days,
        band: band,
      );
      if (suggestions.isNotEmpty) flags.add(OdometerFlag.digitSlipSuspected);

      return _warn(
        title: 'That is ${_rate(dailyRate)} km/day',
        message:
            '${_km(delta)} km in ${_days(days)}. This vehicle normally does '
            'about ${_rate(band.baselineDaily)} km/day, so a reading up to '
            '${_km(band.maxValue)} km would be expected.'
            '${suggestions.isEmpty ? '' : ' Check for ${suggestions.first.kind.label}.'}',
        flags: flags,
        deltaKm: delta,
        daysElapsed: days,
        dailyRate: dailyRate,
        band: band,
        suggestions: suggestions,
      );
    }

    if (band.minValue > lastValue && proposedValue < band.minValue) {
      flags.add(OdometerFlag.rateLow);
      final suggestions = _suggestionsFor(
        proposedValue,
        lastValue: lastValue,
        days: days,
        band: band,
      );
      if (suggestions.isNotEmpty) flags.add(OdometerFlag.digitSlipSuspected);

      return _warn(
        title: 'That is only ${_rate(dailyRate)} km/day',
        message:
            'Just ${_km(delta)} km in ${_days(days)}. This vehicle normally '
            'does about ${_rate(band.baselineDaily)} km/day. Confirm it was '
            'genuinely off the road, or check the digits.',
        flags: flags,
        deltaKm: delta,
        daysElapsed: days,
        dailyRate: dailyRate,
        band: band,
        suggestions: suggestions,
      );
    }

    // ── Inside the band ────────────────────────────────────────────────────
    return OdometerValidationResult(
      severity: OdometerSeverity.ok,
      title: '+${_km(delta)} km since ${_date(last.readingAt)}',
      message: '${_rate(dailyRate)} km/day over ${_days(days)}.',
      flags: flags,
      deltaKm: delta,
      daysElapsed: days,
      dailyRate: dailyRate,
      band: band,
      resultingStatus: OdometerReadingStatus.accepted,
    );
  }

  // ── Baseline learning ────────────────────────────────────────────────────

  /// Median km/day from a vehicle's own accepted readings.
  ///
  /// Median rather than mean, because one bad historical reading would drag a
  /// mean badly and the whole point here is resilience to bad readings.
  static double? ownDailyMedian(List<OdometerReadingEntity> accepted) {
    if (accepted.length < 2) return null;
    final rates = <double>[];
    for (var i = 1; i < accepted.length; i++) {
      final prev = accepted[i - 1];
      final curr = accepted[i];
      final days = curr.readingAt.difference(prev.readingAt).inHours / 24.0;
      if (days < 0.5) continue;
      final delta = curr.value - prev.value;
      if (delta < 0) continue;
      rates.add(delta / days);
    }
    return _median(rates);
  }

  OdometerBand _bandFor({
    required int lastValue,
    required int days,
    required List<OdometerReadingEntity> history,
    double? fleetDailyMedian,
  }) {
    final own = ownDailyMedian(history);
    final intervals = history.length - 1;

    double baseline;
    bool isOwn;
    if (own != null && own > 0 && intervals >= policy.minIntervalsForOwnBaseline) {
      baseline = own;
      isOwn = true;
    } else if (fleetDailyMedian != null && fleetDailyMedian > 0) {
      baseline = fleetDailyMedian;
      isOwn = false;
    } else if (own != null && own > 0) {
      // Thin history is still better than a blind constant.
      baseline = own;
      isOwn = true;
    } else {
      baseline = policy.fallbackDailyKm;
      isOwn = false;
    }

    final maxDelta = policy.softMaxDelta(days, baseline);
    final minDelta = policy.softMinDelta(days, baseline);

    return OdometerBand(
      minValue: lastValue + minDelta.floor(),
      maxValue: lastValue + maxDelta.ceil(),
      baselineDaily: baseline,
      days: days,
      baselineIsOwn: isOwn,
    );
  }

  // ── Digit-slip detection ─────────────────────────────────────────────────

  /// Generates the values the entrant plausibly meant.
  ///
  /// This is the part that catches the reported failure: a value that is 10x
  /// or 1/10th of the right one, or that has a digit dropped or swapped. A
  /// candidate only survives if it lands inside the plausible band, which is
  /// what makes the suggestion trustworthy rather than noise.
  List<OdometerSuggestion> _suggestionsFor(
    int value, {
    required int? lastValue,
    required int days,
    required OdometerBand? band,
  }) {
    final candidates = <int, OdometerSuggestionKind>{};

    void add(int v, OdometerSuggestionKind kind) {
      if (v <= 0 || v == value) return;
      candidates.putIfAbsent(v, () => kind);
    }

    final digits = value.toString();

    // One digit too many: 450000 typed for 45000.
    if (value % 10 == 0) add(value ~/ 10, OdometerSuggestionKind.extraDigit);

    // One digit missing: 4500 typed for 45000.
    add(value * 10, OdometerSuggestionKind.missingDigit);

    // A digit dropped somewhere in the middle.
    if (digits.length > 1) {
      for (var i = 0; i < digits.length; i++) {
        final trimmed = digits.substring(0, i) + digits.substring(i + 1);
        final parsed = int.tryParse(trimmed);
        if (parsed != null) add(parsed, OdometerSuggestionKind.droppedDigit);
      }
    }

    // Two adjacent digits swapped.
    for (var i = 0; i < digits.length - 1; i++) {
      final chars = digits.split('');
      final tmp = chars[i];
      chars[i] = chars[i + 1];
      chars[i + 1] = tmp;
      final parsed = int.tryParse(chars.join());
      if (parsed != null) add(parsed, OdometerSuggestionKind.transposedDigits);
    }

    final out = <OdometerSuggestion>[];
    for (final entry in candidates.entries) {
      final candidate = entry.key;

      // Must still be a forward-moving, in-band reading to be worth offering.
      if (lastValue != null && candidate < lastValue) continue;
      if (candidate > policy.lifetimeMaxKm) continue;
      if (band != null && !band.contains(candidate)) continue;
      if (band == null && lastValue != null) {
        if (candidate - lastValue > policy.hardMaxDelta(days)) continue;
      }

      final rate = lastValue == null
          ? 0.0
          : (candidate - lastValue) / math.max(1, days);
      out.add(
        OdometerSuggestion(value: candidate, kind: entry.value, dailyRate: rate),
      );
    }

    // Closest to the entered value first — that is the likeliest slip.
    out.sort(
      (a, b) => (a.value - value).abs().compareTo((b.value - value).abs()),
    );
    return out.take(3).toList();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Accepted readings at or before [at], oldest first.
  static List<OdometerReadingEntity> _acceptedBefore(
    List<OdometerReadingEntity> history,
    DateTime at,
  ) {
    final list = history
        .where((r) => r.isUsable && !r.readingAt.isAfter(at))
        .toList()
      ..sort((a, b) => a.readingAt.compareTo(b.readingAt));
    return list;
  }

  static double? _median(List<double> values) {
    if (values.isEmpty) return null;
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }

  OdometerValidationResult _block({
    required String title,
    required String message,
    List<OdometerFlag> flags = const [],
    List<OdometerSuggestion> suggestions = const [],
    int? deltaKm,
    int? daysElapsed,
    double? dailyRate,
    OdometerBand? band,
  }) {
    return OdometerValidationResult(
      severity: OdometerSeverity.block,
      title: title,
      message: message,
      flags: flags,
      suggestions: suggestions,
      deltaKm: deltaKm,
      daysElapsed: daysElapsed,
      dailyRate: dailyRate,
      band: band,
      resultingStatus: OdometerReadingStatus.rejected,
    );
  }

  OdometerValidationResult _warn({
    required String title,
    required String message,
    required List<OdometerFlag> flags,
    required List<OdometerSuggestion> suggestions,
    int? deltaKm,
    int? daysElapsed,
    double? dailyRate,
    OdometerBand? band,
  }) {
    return OdometerValidationResult(
      severity: OdometerSeverity.warn,
      title: title,
      message: message,
      flags: flags,
      suggestions: suggestions,
      deltaKm: deltaKm,
      daysElapsed: daysElapsed,
      dailyRate: dailyRate,
      band: band,
      requiresPhoto: policy.requirePhotoOutOfBand,
      requiresConfirmation: policy.requireConfirmationOutOfBand,
      resultingStatus: policy.quarantineOutOfBand
          ? OdometerReadingStatus.quarantined
          : OdometerReadingStatus.accepted,
    );
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

  static String _rate(double v) => v.round().toString();

  static String _days(int d) => d == 1 ? '1 day' : '$d days';

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}
