import 'package:equatable/equatable.dart';

/// Locks money posts for a fund account on a calendar day after petty cash verify.
class DayLockEntity extends Equatable {
  final String id;
  final String fundAccountId;
  /// Date-only key yyyy-MM-dd
  final String dayKey;
  final DateTime day;
  final String lockedBy;
  final String? lockedByUserId;
  final DateTime lockedAt;
  final String? sessionId;
  final String? reason;

  const DayLockEntity({
    required this.id,
    required this.fundAccountId,
    required this.dayKey,
    required this.day,
    required this.lockedBy,
    this.lockedByUserId,
    required this.lockedAt,
    this.sessionId,
    this.reason,
  });

  static String dayKeyFrom(DateTime d) {
    final local = DateTime(d.year, d.month, d.day);
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static String lockId(String fundAccountId, DateTime d) =>
      '${fundAccountId}_${dayKeyFrom(d)}';

  @override
  List<Object?> get props =>
      [id, fundAccountId, dayKey, day, lockedBy, lockedByUserId, lockedAt, sessionId, reason];
}
