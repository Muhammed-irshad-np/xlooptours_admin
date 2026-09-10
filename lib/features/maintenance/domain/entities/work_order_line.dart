import 'package:equatable/equatable.dart';

/// One serviceable item on a work order.
///
/// A single workshop visit routinely covers engine oil **and** air filter
/// **and** brake pads. Each line closes out as its own `MaintenanceRecord`
/// so `GetVehicleMaintenanceAlertsUseCase` — which groups history by service
/// type — resets the right interval for each.
///
/// [maintenanceTypeId] is the master-data id (or one of the
/// `kCarWashTypeId` / `kOtherTypeId` sentinels), so matching never depends on
/// the fragile name normalisation the alert engine falls back to.
class WorkOrderLine extends Equatable {
  final String id;

  final String maintenanceTypeId;

  /// Snapshot of the type name at the time the line was created, so renaming
  /// master data never rewrites history.
  final String maintenanceTypeName;

  /// Set when [maintenanceTypeId] is the "other" sentinel.
  final String? customTypeName;

  final double estimatedCost;
  final double? actualCost;
  final double? partsCost;
  final double? laborCost;
  final String? partsReplaced;
  final String? notes;

  /// Whether this particular item was actually carried out. An unticked line
  /// contributes nothing to history or to the posted expense.
  final bool completed;

  // ─── Follow-up, mirroring MaintenanceRecord ───────────────

  final bool followUpRequired;
  final String? followUpReason;
  final DateTime? followUpDate;
  final int? followUpKm;

  /// For date-triggered maintenance types: when the next service is due.
  final DateTime? targetDueDate;
  final int? notificationDays;

  const WorkOrderLine({
    required this.id,
    required this.maintenanceTypeId,
    required this.maintenanceTypeName,
    this.customTypeName,
    this.estimatedCost = 0,
    this.actualCost,
    this.partsCost,
    this.laborCost,
    this.partsReplaced,
    this.notes,
    this.completed = true,
    this.followUpRequired = false,
    this.followUpReason,
    this.followUpDate,
    this.followUpKm,
    this.targetDueDate,
    this.notificationDays,
  });

  /// The name to write into maintenance history.
  String get effectiveTypeName {
    final custom = customTypeName?.trim() ?? '';
    return custom.isNotEmpty ? custom : maintenanceTypeName;
  }

  /// Actual cost when known, otherwise the estimate.
  double get effectiveCost => actualCost ?? estimatedCost;

  /// How far the actual ran over the estimate. Negative means under.
  double get variance => (actualCost ?? estimatedCost) - estimatedCost;

  WorkOrderLine copyWith({
    String? id,
    String? maintenanceTypeId,
    String? maintenanceTypeName,
    String? customTypeName,
    double? estimatedCost,
    double? actualCost,
    double? partsCost,
    double? laborCost,
    String? partsReplaced,
    String? notes,
    bool? completed,
    bool? followUpRequired,
    String? followUpReason,
    DateTime? followUpDate,
    int? followUpKm,
    DateTime? targetDueDate,
    int? notificationDays,
    bool clearActualCost = false,
    bool clearFollowUp = false,
  }) {
    return WorkOrderLine(
      id: id ?? this.id,
      maintenanceTypeId: maintenanceTypeId ?? this.maintenanceTypeId,
      maintenanceTypeName: maintenanceTypeName ?? this.maintenanceTypeName,
      customTypeName: customTypeName ?? this.customTypeName,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      actualCost: clearActualCost ? null : (actualCost ?? this.actualCost),
      partsCost: partsCost ?? this.partsCost,
      laborCost: laborCost ?? this.laborCost,
      partsReplaced: partsReplaced ?? this.partsReplaced,
      notes: notes ?? this.notes,
      completed: completed ?? this.completed,
      followUpRequired:
          clearFollowUp ? false : (followUpRequired ?? this.followUpRequired),
      followUpReason:
          clearFollowUp ? null : (followUpReason ?? this.followUpReason),
      followUpDate: clearFollowUp ? null : (followUpDate ?? this.followUpDate),
      followUpKm: clearFollowUp ? null : (followUpKm ?? this.followUpKm),
      targetDueDate: targetDueDate ?? this.targetDueDate,
      notificationDays: notificationDays ?? this.notificationDays,
    );
  }

  @override
  List<Object?> get props => [
        id,
        maintenanceTypeId,
        maintenanceTypeName,
        customTypeName,
        estimatedCost,
        actualCost,
        partsCost,
        laborCost,
        partsReplaced,
        notes,
        completed,
        followUpRequired,
        followUpReason,
        followUpDate,
        followUpKm,
        targetDueDate,
        notificationDays,
      ];
}
