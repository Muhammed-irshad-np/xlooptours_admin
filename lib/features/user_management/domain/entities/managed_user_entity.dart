import 'package:equatable/equatable.dart';

/// Presence based on [lastActiveAt] heartbeat while the app is open.
enum UserPresence { online, away, offline, never, deactivated }

class ManagedUserEntity extends Equatable {
  final String uid;
  final String email;
  final String displayName;
  final String roleId;
  final String roleName;
  final bool isActive;
  final DateTime? createdAt;
  final String? createdBy;
  /// Linked employee record id from `employees` collection.
  final String? employeeId;
  /// Cached employee display name for lists.
  final String? employeeName;
  /// Profile photo from linked employee (`employees.imageUrl`).
  final String? photoUrl;
  /// Last successful sign-in (session start).
  final DateTime? lastLoginAt;
  /// Last app activity heartbeat (online presence).
  final DateTime? lastActiveAt;
  /// Number of recorded login sessions.
  final int loginCount;

  const ManagedUserEntity({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.roleId,
    required this.roleName,
    this.isActive = true,
    this.createdAt,
    this.createdBy,
    this.employeeId,
    this.employeeName,
    this.photoUrl,
    this.lastLoginAt,
    this.lastActiveAt,
    this.loginCount = 0,
  });

  bool get hasEmployeeLink =>
      employeeId != null && employeeId!.trim().isNotEmpty;

  /// Online if last heartbeat within 5 minutes; Away within 30 minutes.
  UserPresence get presence {
    if (!isActive) return UserPresence.deactivated;
    final last = lastActiveAt ?? lastLoginAt;
    if (last == null) return UserPresence.never;
    final age = DateTime.now().difference(last);
    if (age <= const Duration(minutes: 5)) return UserPresence.online;
    if (age <= const Duration(minutes: 30)) return UserPresence.away;
    return UserPresence.offline;
  }

  bool get isOnlineNow => presence == UserPresence.online;

  String get presenceLabel {
    switch (presence) {
      case UserPresence.online:
        return 'Online';
      case UserPresence.away:
        return 'Away';
      case UserPresence.offline:
        return 'Offline';
      case UserPresence.never:
        return 'Never signed in';
      case UserPresence.deactivated:
        return 'Deactivated';
    }
  }

  @override
  List<Object?> get props => [
        uid,
        email,
        displayName,
        roleId,
        roleName,
        isActive,
        createdAt,
        createdBy,
        employeeId,
        employeeName,
        photoUrl,
        lastLoginAt,
        lastActiveAt,
        loginCount,
      ];
}
