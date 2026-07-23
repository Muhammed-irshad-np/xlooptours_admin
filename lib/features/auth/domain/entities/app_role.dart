/// Application roles for RBAC.
///
/// Stored on `allowed_users/{email}` as `role` (string).
/// Legacy docs with only `isAdmin: true` map to [AppRole.admin].
enum AppRole {
  driver,
  coordinator,
  manager,
  finance,
  admin,
  viewer;

  String get displayName {
    switch (this) {
      case AppRole.driver:
        return 'Driver';
      case AppRole.coordinator:
        return 'Coordinator';
      case AppRole.manager:
        return 'Manager';
      case AppRole.finance:
        return 'Finance';
      case AppRole.admin:
        return 'Admin';
      case AppRole.viewer:
        return 'Viewer';
    }
  }

  /// Parse from Firestore; falls back via [isAdmin] for legacy whitelist docs.
  static AppRole fromFirestore({
    String? role,
    bool isAdmin = false,
  }) {
    if (role != null && role.isNotEmpty) {
      return AppRole.values.firstWhere(
        (r) => r.name == role.toLowerCase(),
        orElse: () => isAdmin ? AppRole.admin : AppRole.viewer,
      );
    }
    return isAdmin ? AppRole.admin : AppRole.viewer;
  }
}

/// Permission helpers derived from [AppRole].
/// Keep simple and fixed in code for Phase 1; custom matrix later if needed.
extension AppRolePermissions on AppRole {
  bool get canSubmitExpense =>
      this == AppRole.driver ||
      this == AppRole.coordinator ||
      this == AppRole.manager ||
      this == AppRole.finance ||
      this == AppRole.admin;

  bool get canApproveExpense =>
      this == AppRole.manager ||
      this == AppRole.finance ||
      this == AppRole.admin;

  bool get canPostMoney =>
      this == AppRole.finance ||
      this == AppRole.admin ||
      this == AppRole.coordinator;

  bool get canReverseMoney =>
      this == AppRole.finance || this == AppRole.admin;

  bool get canManageFundAccounts =>
      this == AppRole.finance || this == AppRole.admin;

  bool get canManagePettyCash =>
      this == AppRole.coordinator ||
      this == AppRole.finance ||
      this == AppRole.admin;

  bool get canVerifyPettyCash =>
      this == AppRole.finance ||
      this == AppRole.admin ||
      this == AppRole.manager;

  bool get canManageCategories =>
      this == AppRole.finance || this == AppRole.admin;

  bool get canViewAllFinance =>
      this == AppRole.coordinator ||
      this == AppRole.manager ||
      this == AppRole.finance ||
      this == AppRole.admin ||
      this == AppRole.viewer;

  bool get canHardDeleteMasterData => this == AppRole.admin;

  /// Backward-compatible: treat admin role as isAdmin everywhere old code checks.
  bool get isAdminRole => this == AppRole.admin;
}
