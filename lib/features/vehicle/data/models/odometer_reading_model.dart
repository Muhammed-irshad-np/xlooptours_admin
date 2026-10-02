import '../../domain/entities/odometer_reading_entity.dart';

class OdometerReadingModel extends OdometerReadingEntity {
  const OdometerReadingModel({
    required super.id,
    required super.vehicleId,
    required super.value,
    required super.readingAt,
    required super.recordedAt,
    required super.source,
    super.sourceRefId,
    super.enteredByUid,
    super.enteredByName,
    super.photoUrl,
    super.status,
    super.flags,
    super.note,
    super.userConfirmed,
    super.supersedesReadingId,
    super.supersededByReadingId,
    super.reviewedByUid,
    super.reviewedByName,
    super.reviewedAt,
    super.reviewNote,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'vehicleId': vehicleId,
    'value': value,
    'readingAt': readingAt.toIso8601String(),
    'recordedAt': recordedAt.toIso8601String(),
    'source': source.wireName,
    'sourceRefId': sourceRefId,
    'enteredByUid': enteredByUid,
    'enteredByName': enteredByName,
    'photoUrl': photoUrl,
    'status': status.wireName,
    'flags': flags.map((f) => f.wireName).toList(),
    'note': note,
    'userConfirmed': userConfirmed,
    'supersedesReadingId': supersedesReadingId,
    'supersededByReadingId': supersededByReadingId,
    'reviewedByUid': reviewedByUid,
    'reviewedByName': reviewedByName,
    'reviewedAt': reviewedAt?.toIso8601String(),
    'reviewNote': reviewNote,
  };

  factory OdometerReadingModel.fromJson(Map<String, dynamic> json) {
    return OdometerReadingModel(
      id: json['id'] as String? ?? '',
      vehicleId: json['vehicleId'] as String? ?? '',
      value: (json['value'] as num?)?.toInt() ?? 0,
      readingAt: _date(json['readingAt']) ?? DateTime.now(),
      recordedAt:
          _date(json['recordedAt']) ?? _date(json['readingAt']) ?? DateTime.now(),
      source: OdometerSourceX.fromWire(json['source'] as String?),
      sourceRefId: json['sourceRefId'] as String?,
      enteredByUid: json['enteredByUid'] as String?,
      enteredByName: json['enteredByName'] as String?,
      photoUrl: json['photoUrl'] as String?,
      status: OdometerReadingStatusX.fromWire(json['status'] as String?),
      flags: ((json['flags'] as List<dynamic>?) ?? const [])
          .map((f) => OdometerFlagX.fromWire(f as String?))
          .whereType<OdometerFlag>()
          .toList(),
      note: json['note'] as String?,
      userConfirmed: json['userConfirmed'] as bool? ?? false,
      supersedesReadingId: json['supersedesReadingId'] as String?,
      supersededByReadingId: json['supersededByReadingId'] as String?,
      reviewedByUid: json['reviewedByUid'] as String?,
      reviewedByName: json['reviewedByName'] as String?,
      reviewedAt: _date(json['reviewedAt']),
      reviewNote: json['reviewNote'] as String?,
    );
  }

  factory OdometerReadingModel.fromEntity(OdometerReadingEntity e) {
    return OdometerReadingModel(
      id: e.id,
      vehicleId: e.vehicleId,
      value: e.value,
      readingAt: e.readingAt,
      recordedAt: e.recordedAt,
      source: e.source,
      sourceRefId: e.sourceRefId,
      enteredByUid: e.enteredByUid,
      enteredByName: e.enteredByName,
      photoUrl: e.photoUrl,
      status: e.status,
      flags: e.flags,
      note: e.note,
      userConfirmed: e.userConfirmed,
      supersedesReadingId: e.supersedesReadingId,
      supersededByReadingId: e.supersededByReadingId,
      reviewedByUid: e.reviewedByUid,
      reviewedByName: e.reviewedByName,
      reviewedAt: e.reviewedAt,
      reviewNote: e.reviewNote,
    );
  }

  /// Tolerates both ISO strings and Firestore Timestamps, since older rows in
  /// this project were written both ways.
  static DateTime? _date(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    try {
      return (raw as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }
}
