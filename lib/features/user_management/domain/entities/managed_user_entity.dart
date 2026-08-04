import 'package:equatable/equatable.dart';

/// Presence: online only while a live app session is open.
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
  /// Last app activity or logout time (last seen).
  final DateTime? lastActiveAt;
  /// Explicit logout timestamp when available.
  final DateTime? lastLogoutAt;
  /// True only while a client session is open; set false on logout.
  final bool sessionActive;
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
    this.lastLogoutAt,
    this.sessionActive = false,
    this.loginCount = 0,
  });

  bool get hasEmployeeLink =>
      employeeId != null && employeeId!.trim().isNotEmpty;

  /// Online only if session is open AND heartbeat is fresh.
  /// After logout, [sessionActive] is false → Offline immediately with last seen.
  UserPresence get presence {
    if (!isActive) return UserPresence.deactivated;

    final last = lastActiveAt ?? lastLoginAt;

    // Explicit logout / closed session → never show Online
    if (!sessionActive) {
      if (last == null) return UserPresence.never;
      return UserPresence.offline;
    }

    // Live session but no activity timestamp yet
    if (last == null) return UserPresence.online;

    // Live session: use heartbeat age
    final age = DateTime.now().difference(last);
    if (age <= const Duration(minutes: 5)) return UserPresence.online;
    if (age <= const Duration(minutes: 30)) return UserPresence.away;
    // Stale session (tab closed without logout)
    return UserPresence.offline;
  }

  bool get isOnlineNow => presence == UserPresence.online;

  /// Best timestamp for "last seen" in the UI.
  DateTime? get lastSeenAt {
    if (lastLogoutAt != null && lastActiveAt != null) {
      return lastLogoutAt!.isAfter(lastActiveAt!) ? lastLogoutAt : lastActiveAt;
    }
    return lastLogoutAt ?? lastActiveAt ?? lastLoginAt;
  }

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
        lastLogoutAt,
        sessionActive,
        loginCount,
      ];
}
