import 'package:equatable/equatable.dart';

import 'work_order_status.dart';

/// A single entry in a work order's audit trail.
///
/// Stored as a nested array on the work order document — always read
/// together with it, never queried on its own.
class WorkOrderEvent extends Equatable {
  final DateTime at;

  /// Display name of whoever acted.
  final String actor;
  final String? actorUserId;
  final String? actorRole;

  /// Short verb: 'reported', 'issued', 'approved', 'rejected', 'started',
  /// 'completed', 'closed', 'cancelled', 'held', 'resumed', 'edited'.
  final String action;

  final WorkOrderStatus? fromStatus;
  final WorkOrderStatus? toStatus;

  /// Free-text detail — rejection reason, hold reason, variance note.
  final String? note;

  const WorkOrderEvent({
    required this.at,
    required this.actor,
    this.actorUserId,
    this.actorRole,
    required this.action,
    this.fromStatus,
    this.toStatus,
    this.note,
  });

  /// Human sentence for the timeline, e.g. "Approved by Shamnad".
  String get headline {
    final verb = switch (action) {
      'reported' => 'Reported',
      'issued' => 'Sent for approval',
      'approved' => 'Approved',
      'autoApproved' => 'Auto-approved',
      'rejected' => 'Rejected',
      'started' => 'Work started',
      'completed' => 'Work completed',
      'closed' => 'Closed & expense posted',
      'cancelled' => 'Cancelled',
      'held' => 'Put on hold',
      'resumed' => 'Resumed',
      'reopened' => 'Re-sent for approval',
      'edited' => 'Details updated',
      _ => action,
    };
    return '$verb by $actor';
  }

  Map<String, dynamic> toJson() => {
        'at': at.toIso8601String(),
        'actor': actor,
        'actorUserId': actorUserId,
        'actorRole': actorRole,
        'action': action,
        'fromStatus': fromStatus?.name,
        'toStatus': toStatus?.name,
        'note': note,
      };

  factory WorkOrderEvent.fromJson(Map<String, dynamic> json) {
    return WorkOrderEvent(
      at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
      actor: json['actor'] as String? ?? 'System',
      actorUserId: json['actorUserId'] as String?,
      actorRole: json['actorRole'] as String?,
      action: json['action'] as String? ?? 'edited',
      fromStatus: json['fromStatus'] != null
          ? WorkOrderStatus.fromName(json['fromStatus'] as String?)
          : null,
      toStatus: json['toStatus'] != null
          ? WorkOrderStatus.fromName(json['toStatus'] as String?)
          : null,
      note: json['note'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        at,
        actor,
        actorUserId,
        actorRole,
        action,
        fromStatus,
        toStatus,
        note,
      ];
}
