enum AppPermission {
  viewDashboard,
  manageTrips,
  manageUsers,
  manageRoles,
  manageVehicles,
  manageEmployees,
  manageInvoices,
  manageCustomers,
  manageCompanies,
  viewAnalytics,
  viewVault,
  viewActivityLogs,
  viewFeedback,
  viewMasterData,
  manageEvaluations,
}

extension AppPermissionExtension on AppPermission {
  String toPermissionString() {
    switch (this) {
      case AppPermission.viewDashboard:
        return 'view_dashboard';
      case AppPermission.manageTrips:
        return 'manage_trips';
      case AppPermission.manageUsers:
        return 'manage_users';
      case AppPermission.manageRoles:
        return 'manage_roles';
      case AppPermission.manageVehicles:
        return 'manage_vehicles';
      case AppPermission.manageEmployees:
        return 'manage_employees';
      case AppPermission.manageInvoices:
        return 'manage_invoices';
      case AppPermission.manageCustomers:
        return 'manage_customers';
      case AppPermission.manageCompanies:
        return 'manage_companies';
      case AppPermission.viewAnalytics:
        return 'view_analytics';
      case AppPermission.viewVault:
        return 'view_vault';
      case AppPermission.viewActivityLogs:
        return 'view_activity_logs';
      case AppPermission.viewFeedback:
        return 'view_feedback';
      case AppPermission.viewMasterData:
        return 'view_master_data';
      case AppPermission.manageEvaluations:
        return 'manage_evaluations';
    }
  }

  String get label {
    switch (this) {
      case AppPermission.viewDashboard:
        return 'View Dashboard';
      case AppPermission.manageTrips:
        return 'Manage Trips';
      case AppPermission.manageUsers:
        return 'Manage Users';
      case AppPermission.manageRoles:
        return 'Manage Roles & Permissions';
      case AppPermission.manageVehicles:
        return 'Manage Vehicles';
      case AppPermission.manageEmployees:
        return 'Manage Employees';
      case AppPermission.manageInvoices:
        return 'Manage Invoices';
      case AppPermission.manageCustomers:
        return 'Manage Customers';
      case AppPermission.manageCompanies:
        return 'Manage Companies';
      case AppPermission.viewAnalytics:
        return 'View Analytics';
      case AppPermission.viewVault:
        return 'View Vault';
      case AppPermission.viewActivityLogs:
        return 'View Activity Logs';
      case AppPermission.viewFeedback:
        return 'View Feedback';
      case AppPermission.viewMasterData:
        return 'View Master Data';
      case AppPermission.manageEvaluations:
        return 'Manage Driver Evaluations';
    }
  }

  static AppPermission? fromString(String permStr) {
    for (final perm in AppPermission.values) {
      if (perm.toPermissionString() == permStr) return perm;
    }
    return null;
  }
}
