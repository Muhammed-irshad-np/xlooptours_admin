import 'package:equatable/equatable.dart';

/// Reusable permission configuration for a single workflow action.
///
/// Each finance action (open session, close session, verify, approve, etc.)
/// is configured with:
/// - [allowedRoles]: Role IDs that can perform this action (e.g., ['admin', 'coordinator'])
/// - [allowedUserIds]: Specific user IDs that can perform this action
/// - [allowedUserNames]: Display names parallel to [allowedUserIds] for UI
///
/// The permission check logic is: Admin/SuperAdmin always pass. Then:
///   if [allowedUserIds] is non-empty → user.id must be in the list
///   OR if [allowedRoles] is non-empty → user.roleId must be in the list
///   if both are empty → falls back to default (allow nobody except admin)
class WorkflowPermissionConfig extends Equatable {
  /// Role IDs allowed to perform this action.
  final List<String> allowedRoles;

  /// Specific user IDs allowed to perform this action.
  final List<String> allowedUserIds;

  /// Display names parallel to [allowedUserIds] for UI rendering.
  final List<String> allowedUserNames;

  const WorkflowPermissionConfig({
    this.allowedRoles = const [],
    this.allowedUserIds = const [],
    this.allowedUserNames = const [],
  });

  /// Check if a user (by normalized roleId and userId) is authorized.
  /// Admin/SuperAdmin checks should be done BEFORE calling this.
  bool isAuthorized(String roleId, String userId) {
    // If specific users are configured, check user ID
    if (allowedUserIds.isNotEmpty && allowedUserIds.contains(userId)) {
      return true;
    }
    // If roles are configured, check role
    if (allowedRoles.isNotEmpty && allowedRoles.contains(roleId)) {
      return true;
    }
    // If nothing is configured, deny (caller should check admin first)
    return false;
  }

  /// Whether any configuration has been set (roles or users).
  bool get hasConfiguration =>
      allowedRoles.isNotEmpty || allowedUserIds.isNotEmpty;

  WorkflowPermissionConfig copyWith({
    List<String>? allowedRoles,
    List<String>? allowedUserIds,
    List<String>? allowedUserNames,
  }) {
    return WorkflowPermissionConfig(
      allowedRoles: allowedRoles ?? this.allowedRoles,
      allowedUserIds: allowedUserIds ?? this.allowedUserIds,
      allowedUserNames: allowedUserNames ?? this.allowedUserNames,
    );
  }

  Map<String, dynamic> toJson() => {
        'allowedRoles': allowedRoles,
        'allowedUserIds': allowedUserIds,
        'allowedUserNames': allowedUserNames,
      };

  factory WorkflowPermissionConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const WorkflowPermissionConfig();
    return WorkflowPermissionConfig(
      allowedRoles: (json['allowedRoles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      allowedUserIds: (json['allowedUserIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      allowedUserNames: (json['allowedUserNames'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  @override
  List<Object?> get props => [allowedRoles, allowedUserIds, allowedUserNames];
}
