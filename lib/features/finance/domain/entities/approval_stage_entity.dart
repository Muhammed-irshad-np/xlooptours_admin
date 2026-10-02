import 'package:equatable/equatable.dart';

/// Represents one stage in a multi-level expense approval chain.
///
/// Example chain:
///   Stage 0: Manager approves up to 5,000 SAR
///   Stage 1: Finance approves up to 50,000 SAR
///   Stage 2: Admin approves unlimited
class ApprovalStageEntity extends Equatable {
  /// Display name (e.g. "Manager Review", "Finance Director Sign-off").
  final String name;

  /// The order in the chain (0-based). Lower = first.
  final int order;

  /// Maximum amount (SAR) this stage can approve. Null = unlimited.
  final double? maxAmount;

  /// Role IDs that can approve at this stage (e.g. ['manager']).
  final List<String> approverRoles;

  /// Specific user IDs that can approve at this stage (overrides roles if non-empty).
  final List<String> approverUserIds;

  /// Specific user display names (parallel to [approverUserIds] for UI display).
  final List<String> approverUserNames;

  const ApprovalStageEntity({
    required this.name,
    required this.order,
    this.maxAmount,
    this.approverRoles = const [],
    this.approverUserIds = const [],
    this.approverUserNames = const [],
  });

  /// Whether this stage can approve the given amount.
  bool canApproveAmount(double amount) {
    if (maxAmount == null) return true;
    return amount <= maxAmount! + 1e-9;
  }

  /// Whether a user (by roleId and userId) is authorized for this stage.
  bool isUserAuthorized(String roleId, String userId) {
    if (approverUserIds.isNotEmpty && approverUserIds.contains(userId)) {
      return true;
    }
    if (approverRoles.isNotEmpty && approverRoles.contains(roleId)) {
      return true;
    }
    return false;
  }

  ApprovalStageEntity copyWith({
    String? name,
    int? order,
    double? maxAmount,
    bool clearMaxAmount = false,
    List<String>? approverRoles,
    List<String>? approverUserIds,
    List<String>? approverUserNames,
  }) {
    return ApprovalStageEntity(
      name: name ?? this.name,
      order: order ?? this.order,
      maxAmount: clearMaxAmount ? null : (maxAmount ?? this.maxAmount),
      approverRoles: approverRoles ?? this.approverRoles,
      approverUserIds: approverUserIds ?? this.approverUserIds,
      approverUserNames: approverUserNames ?? this.approverUserNames,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'order': order,
        'maxAmount': maxAmount,
        'approverRoles': approverRoles,
        'approverUserIds': approverUserIds,
        'approverUserNames': approverUserNames,
      };

  factory ApprovalStageEntity.fromJson(Map<String, dynamic> json) {
    return ApprovalStageEntity(
      name: json['name'] as String? ?? 'Approval',
      order: json['order'] as int? ?? 0,
      maxAmount: (json['maxAmount'] as num?)?.toDouble(),
      approverRoles: (json['approverRoles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      approverUserIds: (json['approverUserIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      approverUserNames: (json['approverUserNames'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  @override
  List<Object?> get props => [
        name,
        order,
        maxAmount,
        approverRoles,
        approverUserIds,
        approverUserNames,
      ];
}
