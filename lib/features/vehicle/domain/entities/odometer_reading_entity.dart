import 'package:equatable/equatable.dart';

/// Where a reading came from.
///
/// Several parts of the app capture an odometer value (the weekly dashboard
/// prompt, maintenance records, follow-up completions, fuel/vehicle expenses).
/// They all land in this one append-only log so the readings can corroborate —
/// or contradict — one another.
enum OdometerSource {
  /// The weekly Thursday prompt on the dashboard. The most trusted source:
  /// someone stood at the vehicle and read the cluster.
  weeklyUpdate,

  /// Captured while logging a maintenance record.
  maintenance,

  /// Captured while completing a follow-up service.
  followUp,

  /// Transcribed onto a fuel / vehicle expense, often after the fact.
  expense,

  /// Typed into the vehicle master form.
  vehicleForm,

  /// The purchase odometer, seeded when the vehicle was created.
  initial,

  /// An admin correcting an earlier bad reading.
  correction,
}

extension OdometerSourceX on OdometerSource {
  String get wireName => name;

  String get label {
    switch (this) {
      case OdometerSource.weeklyUpdate:
        return 'Weekly update';
      case OdometerSource.maintenance:
        return 'Maintenance record';
      case OdometerSource.followUp:
        return 'Follow-up service';
      case OdometerSource.expense:
        return 'Expense entry';
      case OdometerSource.vehicleForm:
        return 'Vehicle form';
      case OdometerSource.initial:
        return 'Purchase odometer';
      case OdometerSource.correction:
        return 'Admin correction';
    }
  }

  /// Sources where a human read the cluster directly, rather than transcribing
  /// a number off a receipt days later. Primary sources win a contradiction.
  bool get isPrimary =>
      this == OdometerSource.weeklyUpdate ||
      this == OdometerSource.correction ||
      this == OdometerSource.initial;

  static OdometerSource fromWire(String? value) {
    return OdometerSource.values.firstWhere(
      (s) => s.name == value,
      orElse: () => OdometerSource.weeklyUpdate,
    );
  }
}

/// Lifecycle of a single reading in the append-only log.
enum OdometerReadingStatus {
  /// Trusted. Feeds `currentOdometer` and the maintenance alert maths.
  accepted,

  /// Saved and visible, but outside the plausible band. Deliberately excluded
  /// from maintenance alerts until a reviewer accepts or rejects it, so one
  /// fat-fingered entry cannot silently trigger — or suppress — a service.
  quarantined,

  /// A reviewer confirmed this reading is wrong. Kept for audit, never used.
  rejected,

  /// Replaced by a later correction. Kept for audit, never used.
  superseded,
}

extension OdometerReadingStatusX on OdometerReadingStatus {
  String get wireName => name;

  String get label {
    switch (this) {
      case OdometerReadingStatus.accepted:
        return 'Accepted';
      case OdometerReadingStatus.quarantined:
        return 'Needs review';
      case OdometerReadingStatus.rejected:
        return 'Rejected';
      case OdometerReadingStatus.superseded:
        return 'Superseded';
    }
  }

  /// Only accepted readings are allowed to move `currentOdometer` or drive
  /// maintenance alerts.
  bool get countsTowardsCurrent => this == OdometerReadingStatus.accepted;

  static OdometerReadingStatus fromWire(String? value) {
    return OdometerReadingStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => OdometerReadingStatus.accepted,
    );
  }
}

/// Machine-readable reasons a reading was flagged. Stored on the reading so the
/// review queue can explain itself months later without re-running validation.
enum OdometerFlag {
  belowPrevious,
  aboveHardCeiling,
  aboveLifetimeMax,
  rateHigh,
  rateLow,
  idleWithFuelSpend,
  digitSlipSuspected,
  futureDated,
  duplicateValue,
  contradictsOtherSource,
  noHistory,
}

extension OdometerFlagX on OdometerFlag {
  String get wireName => name;

  String get label {
    switch (this) {
      case OdometerFlag.belowPrevious:
        return 'Lower than the previous reading';
      case OdometerFlag.aboveHardCeiling:
        return 'Physically impossible distance';
      case OdometerFlag.aboveLifetimeMax:
        return 'Beyond any vehicle lifetime';
      case OdometerFlag.rateHigh:
        return 'Daily rate far above this vehicle usual';
      case OdometerFlag.rateLow:
        return 'Daily rate far below this vehicle usual';
      case OdometerFlag.idleWithFuelSpend:
        return 'Barely moved despite fuel spend';
      case OdometerFlag.digitSlipSuspected:
        return 'Looks like a mistyped digit';
      case OdometerFlag.futureDated:
        return 'Reading dated in the future';
      case OdometerFlag.duplicateValue:
        return 'Identical to the previous reading';
      case OdometerFlag.contradictsOtherSource:
        return 'Conflicts with another recorded source';
      case OdometerFlag.noHistory:
        return 'No history to validate against';
    }
  }

  static OdometerFlag? fromWire(String? value) {
    for (final f in OdometerFlag.values) {
      if (f.name == value) return f;
    }
    return null;
  }
}

/// One immutable odometer observation.
///
/// Readings are never edited or deleted. A wrong reading is *superseded* by a
/// correction, which keeps the full series intact for audit and lets downstream
/// maths be recomputed rather than guessed at.
class OdometerReadingEntity extends Equatable {
  final String id;
  final String vehicleId;

  /// Kilometres shown on the cluster.
  final int value;

  /// When the cluster was actually read. May be backdated — a driver can report
  /// Thursday's reading on Saturday, and the series must order by observation
  /// time, not by upload time.
  final DateTime readingAt;

  /// When the row hit the database. Never backdated.
  final DateTime recordedAt;

  final OdometerSource source;

  /// Id of the expense / maintenance record this reading rode in on, when any.
  final String? sourceRefId;

  final String? enteredByUid;
  final String? enteredByName;

  /// Photo of the cluster. Required by policy for out-of-band readings.
  final String? photoUrl;

  final OdometerReadingStatus status;
  final List<OdometerFlag> flags;

  /// Free text from whoever entered it.
  final String? note;

  /// True when the entrant explicitly ticked "I verified this on the cluster"
  /// after being warned. Raises confidence during review.
  final bool userConfirmed;

  /// Correction links. `supersedesReadingId` points back at the bad reading;
  /// `supersededByReadingId` points forward at the fix.
  final String? supersedesReadingId;
  final String? supersededByReadingId;

  final String? reviewedByUid;
  final String? reviewedByName;
  final DateTime? reviewedAt;
  final String? reviewNote;

  const OdometerReadingEntity({
    required this.id,
    required this.vehicleId,
    required this.value,
    required this.readingAt,
    required this.recordedAt,
    required this.source,
    this.sourceRefId,
    this.enteredByUid,
    this.enteredByName,
    this.photoUrl,
    this.status = OdometerReadingStatus.accepted,
    this.flags = const [],
    this.note,
    this.userConfirmed = false,
    this.supersedesReadingId,
    this.supersededByReadingId,
    this.reviewedByUid,
    this.reviewedByName,
    this.reviewedAt,
    this.reviewNote,
  });

  bool get isUsable => status.countsTowardsCurrent;
  bool get needsReview => status == OdometerReadingStatus.quarantined;
  bool get hasFlags => flags.isNotEmpty;

  OdometerReadingEntity copyWith({
    String? id,
    String? vehicleId,
    int? value,
    DateTime? readingAt,
    DateTime? recordedAt,
    OdometerSource? source,
    String? sourceRefId,
    String? enteredByUid,
    String? enteredByName,
    String? photoUrl,
    OdometerReadingStatus? status,
    List<OdometerFlag>? flags,
    String? note,
    bool? userConfirmed,
    String? supersedesReadingId,
    String? supersededByReadingId,
    String? reviewedByUid,
    String? reviewedByName,
    DateTime? reviewedAt,
    String? reviewNote,
  }) {
    return OdometerReadingEntity(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      value: value ?? this.value,
      readingAt: readingAt ?? this.readingAt,
      recordedAt: recordedAt ?? this.recordedAt,
      source: source ?? this.source,
      sourceRefId: sourceRefId ?? this.sourceRefId,
      enteredByUid: enteredByUid ?? this.enteredByUid,
      enteredByName: enteredByName ?? this.enteredByName,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      flags: flags ?? this.flags,
      note: note ?? this.note,
      userConfirmed: userConfirmed ?? this.userConfirmed,
      supersedesReadingId: supersedesReadingId ?? this.supersedesReadingId,
      supersededByReadingId:
          supersededByReadingId ?? this.supersededByReadingId,
      reviewedByUid: reviewedByUid ?? this.reviewedByUid,
      reviewedByName: reviewedByName ?? this.reviewedByName,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewNote: reviewNote ?? this.reviewNote,
    );
  }

  @override
  List<Object?> get props => [
    id,
    vehicleId,
    value,
    readingAt,
    recordedAt,
    source,
    sourceRefId,
    enteredByUid,
    enteredByName,
    photoUrl,
    status,
    flags,
    note,
    userConfirmed,
    supersedesReadingId,
    supersededByReadingId,
    reviewedByUid,
    reviewedByName,
    reviewedAt,
    reviewNote,
  ];
}
