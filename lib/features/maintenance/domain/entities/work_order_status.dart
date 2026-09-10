/// Lifecycle of a vehicle maintenance work order.
///
/// ```
/// reported ─▶ pendingApproval ─▶ approved ─▶ inProgress ─▶ completed ─▶ closed
///    │             │                            │
///    └─▶ rejected  └─▶ rejected                 └─▶ onHold ─▶ inProgress
///        cancelled (from any state before completed)
/// ```
///
/// `reported` is stage 0 of the same document, not a separate collection:
/// one physical job is one story with one timeline.
enum WorkOrderStatus {
  /// A fault was reported (typically by the fleet manager or a driver) but
  /// nobody has costed it yet.
  reported,

  /// Costed and waiting for someone to authorise the spend.
  pendingApproval,

  /// Spend authorised; work has not started.
  approved,

  /// Vehicle is at the workshop right now.
  inProgress,

  /// Work is finished and the shop invoice is in; not yet posted to finance.
  completed,

  /// Expense posted to finance and maintenance history written back. Terminal.
  closed,

  /// Paused mid-job (waiting for parts, shop delay).
  onHold,

  /// Approval refused. Terminal unless re-issued.
  rejected,

  /// Abandoned before completion. Terminal.
  cancelled;

  String get displayName {
    switch (this) {
      case WorkOrderStatus.reported:
        return 'Reported';
      case WorkOrderStatus.pendingApproval:
        return 'Pending Approval';
      case WorkOrderStatus.approved:
        return 'Approved';
      case WorkOrderStatus.inProgress:
        return 'In Progress';
      case WorkOrderStatus.completed:
        return 'Completed';
      case WorkOrderStatus.closed:
        return 'Closed';
      case WorkOrderStatus.onHold:
        return 'On Hold';
      case WorkOrderStatus.rejected:
        return 'Rejected';
      case WorkOrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Short label for dense list rows.
  String get shortLabel {
    switch (this) {
      case WorkOrderStatus.pendingApproval:
        return 'Approval';
      case WorkOrderStatus.inProgress:
        return 'At Shop';
      default:
        return displayName;
    }
  }

  /// No further transitions are possible.
  bool get isTerminal =>
      this == WorkOrderStatus.closed ||
      this == WorkOrderStatus.rejected ||
      this == WorkOrderStatus.cancelled;

  /// The vehicle is physically unavailable while in this state.
  bool get occupiesVehicle =>
      this == WorkOrderStatus.inProgress || this == WorkOrderStatus.onHold;

  /// Still live — counts against the vehicle for alert suppression.
  bool get isOpen => !isTerminal;

  /// Details (lines, shop, costs) may still be edited.
  bool get canEditDetails =>
      this == WorkOrderStatus.reported ||
      this == WorkOrderStatus.pendingApproval ||
      this == WorkOrderStatus.approved ||
      this == WorkOrderStatus.inProgress ||
      this == WorkOrderStatus.onHold;

  bool get canBeCancelled =>
      !isTerminal && this != WorkOrderStatus.completed;

  static WorkOrderStatus fromName(String? name) {
    if (name == null) return WorkOrderStatus.reported;
    return WorkOrderStatus.values.firstWhere(
      (s) => s.name == name,
      orElse: () => WorkOrderStatus.reported,
    );
  }
}

/// How urgent the job is. `vehicleDown` means the car cannot be driven.
enum WorkOrderPriority {
  low,
  normal,
  high,
  vehicleDown;

  String get displayName {
    switch (this) {
      case WorkOrderPriority.low:
        return 'Low';
      case WorkOrderPriority.normal:
        return 'Normal';
      case WorkOrderPriority.high:
        return 'High';
      case WorkOrderPriority.vehicleDown:
        return 'Vehicle Down';
    }
  }

  bool get isUrgent =>
      this == WorkOrderPriority.high || this == WorkOrderPriority.vehicleDown;

  /// Sort weight — higher sorts first.
  int get weight => WorkOrderPriority.values.indexOf(this);

  static WorkOrderPriority fromName(String? name) {
    if (name == null) return WorkOrderPriority.normal;
    return WorkOrderPriority.values.firstWhere(
      (p) => p.name == name,
      orElse: () => WorkOrderPriority.normal,
    );
  }
}

/// Where the work order came from — drives the entry status and the UI copy.
enum WorkOrderSource {
  /// Raised by the fleet manager or a driver as a fault report.
  reported,

  /// Created from a due/overdue maintenance alert.
  alert,

  /// Created directly by a coordinator (scheduled service, accident repair).
  adhoc;

  String get displayName {
    switch (this) {
      case WorkOrderSource.reported:
        return 'Reported';
      case WorkOrderSource.alert:
        return 'Maintenance Alert';
      case WorkOrderSource.adhoc:
        return 'Manual';
    }
  }

  static WorkOrderSource fromName(String? name) {
    if (name == null) return WorkOrderSource.adhoc;
    return WorkOrderSource.values.firstWhere(
      (s) => s.name == name,
      orElse: () => WorkOrderSource.adhoc,
    );
  }
}
