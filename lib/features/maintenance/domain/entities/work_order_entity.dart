import 'package:equatable/equatable.dart';

import 'work_order_event.dart';
import 'work_order_line.dart';
import 'work_order_status.dart';

/// A vehicle maintenance job, from the moment someone notices a problem to
/// the moment the money leaves a fund account.
///
/// This is the object the old flow was missing: `MaintenanceRecord` describes
/// work that already happened, with a `cost` that never reached finance.
/// A work order describes work through its whole life and carries the
/// accountability chain — who reported it, who authorised the spend, who did
/// it, which expense it became.
class WorkOrderEntity extends Equatable {
  // ─── Identity ──────────────────────────────────────────────

  /// Firestore document id. Same value as [workOrderNumber].
  final String id;

  /// Human reference, e.g. `WO-2026-0042`.
  final String workOrderNumber;

  final WorkOrderStatus status;
  final WorkOrderSource source;
  final WorkOrderPriority priority;

  // ─── Subject ───────────────────────────────────────────────

  final String vehicleId;

  /// Denormalised so list rows render without loading every vehicle.
  final String vehiclePlate;
  final String? vehicleName;

  /// Odometer when the fault was reported / the work order raised.
  final int? odometerAtRequest;

  /// Odometer at the time of service — what maintenance history records and
  /// what the next interval is measured from.
  final int? odometerAtService;

  // ─── The request ───────────────────────────────────────────

  /// What is wrong, in the reporter's words. Required.
  final String complaint;

  final String? reportedBy;
  final String? reportedByUserId;
  final String? reportedByRole;
  final DateTime? reportedAt;
  final List<String> reportedAttachmentUrls;

  /// Maintenance alert this came from, as `<maintenanceTypeId>` — used to
  /// suppress the alert while this work order is open.
  final String? sourceAlertTypeId;

  // ─── The plan ──────────────────────────────────────────────

  final List<WorkOrderLine> lines;

  final String? shopId;
  final String? shopName;
  final DateTime? scheduledDate;

  final String createdBy;
  final String? createdByUserId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // ─── Approval ──────────────────────────────────────────────

  final String? approvedBy;
  final String? approvedByUserId;
  final DateTime? approvedAt;

  /// The estimate as it stood at approval. Variance is measured against this,
  /// not against a later-edited estimate.
  final double? approvedAmount;

  final String? rejectionReason;

  /// Set when a work order went back for approval after running over.
  final String? varianceReason;

  // ─── Execution ─────────────────────────────────────────────

  final DateTime? startedAt;
  final String? startedBy;
  final DateTime? completedAt;
  final String? completedBy;

  final List<String> invoiceUrls;
  final String? shopInvoiceNumber;

  final String? holdReason;

  // ─── Finance link ──────────────────────────────────────────

  /// Expense created on close. Non-null means the money side is done —
  /// this is the idempotency guard against double-posting.
  final String? expenseId;
  final String? expenseReferenceNumber;

  final String? fundAccountId;
  final String? fundAccountName;

  /// 'cash' or 'stcPay', matching `ExpenseEntity.paymentMethod`.
  final String paymentMethod;

  /// The driver already paid the shop from a cash advance. Closing such a
  /// work order must settle that advance rather than post a fresh expense,
  /// or the spend is counted twice. Not yet wired — see the plan doc.
  final bool paidFromDriverAdvance;

  final String currency;

  // ─── Closure ───────────────────────────────────────────────

  final DateTime? closedAt;
  final String? closedBy;
  final String? cancellationReason;
  final String? notes;

  /// The vehicle's `status` before this work order took it off the road, so
  /// closing can put it back exactly as it was.
  final String? vehicleStatusBefore;

  // ─── Audit ─────────────────────────────────────────────────

  final List<WorkOrderEvent> timeline;

  const WorkOrderEntity({
    required this.id,
    required this.workOrderNumber,
    this.status = WorkOrderStatus.reported,
    this.source = WorkOrderSource.adhoc,
    this.priority = WorkOrderPriority.normal,
    required this.vehicleId,
    required this.vehiclePlate,
    this.vehicleName,
    this.odometerAtRequest,
    this.odometerAtService,
    required this.complaint,
    this.reportedBy,
    this.reportedByUserId,
    this.reportedByRole,
    this.reportedAt,
    this.reportedAttachmentUrls = const [],
    this.sourceAlertTypeId,
    this.lines = const [],
    this.shopId,
    this.shopName,
    this.scheduledDate,
    required this.createdBy,
    this.createdByUserId,
    required this.createdAt,
    this.updatedAt,
    this.approvedBy,
    this.approvedByUserId,
    this.approvedAt,
    this.approvedAmount,
    this.rejectionReason,
    this.varianceReason,
    this.startedAt,
    this.startedBy,
    this.completedAt,
    this.completedBy,
    this.invoiceUrls = const [],
    this.shopInvoiceNumber,
    this.holdReason,
    this.expenseId,
    this.expenseReferenceNumber,
    this.fundAccountId,
    this.fundAccountName,
    this.paymentMethod = 'cash',
    this.paidFromDriverAdvance = false,
    this.currency = 'SAR',
    this.closedAt,
    this.closedBy,
    this.cancellationReason,
    this.notes,
    this.vehicleStatusBefore,
    this.timeline = const [],
  });

  // ─── Derived money ─────────────────────────────────────────

  /// Sum of line estimates.
  double get estimatedTotal =>
      lines.fold(0.0, (sum, l) => sum + l.estimatedCost);

  /// Sum of actual costs on completed lines. Lines with no actual entered
  /// fall back to their estimate so the figure is never misleadingly low.
  double get actualTotal => lines
      .where((l) => l.completed)
      .fold(0.0, (sum, l) => sum + l.effectiveCost);

  /// The number that matters right now: actual once work is done, otherwise
  /// the estimate.
  double get displayTotal =>
      status.index >= WorkOrderStatus.completed.index &&
              status != WorkOrderStatus.onHold
          ? actualTotal
          : estimatedTotal;

  /// Overrun against the approved amount. Zero when nothing was approved.
  double get variance {
    final approved = approvedAmount;
    if (approved == null) return 0;
    return actualTotal - approved;
  }

  bool get hasOverrun => variance > 0;

  int get estimatedTotalMinor => (estimatedTotal * 100).round();
  int get actualTotalMinor => (actualTotal * 100).round();

  // ─── Derived state ─────────────────────────────────────────

  /// Money has been posted — the work order is finished in every sense.
  bool get isPosted => expenseId != null && expenseId!.isNotEmpty;

  /// Work order is still live and should suppress alerts for its lines.
  bool get isOpen => status.isOpen;

  /// The vehicle is off the road because of this work order.
  bool get occupiesVehicle => status.occupiesVehicle;

  /// Maintenance type ids covered by this work order.
  List<String> get maintenanceTypeIds =>
      lines.map((l) => l.maintenanceTypeId).toList();

  /// One-line summary of the lines, e.g. "Engine Oil + Air Filter".
  String get lineSummary {
    if (lines.isEmpty) return 'No items yet';
    if (lines.length == 1) return lines.first.effectiveTypeName;
    if (lines.length == 2) {
      return '${lines[0].effectiveTypeName} + ${lines[1].effectiveTypeName}';
    }
    return '${lines.first.effectiveTypeName} + ${lines.length - 1} more';
  }

  /// Days since the work order was raised.
  int get ageInDays => DateTime.now().difference(createdAt).inDays;

  /// Latest timeline entry, if any.
  WorkOrderEvent? get lastEvent =>
      timeline.isEmpty ? null : timeline.last;

  factory WorkOrderEntity.empty() => WorkOrderEntity(
        id: '',
        workOrderNumber: '',
        vehicleId: '',
        vehiclePlate: '',
        complaint: '',
        createdBy: '',
        createdAt: DateTime.now(),
      );

  WorkOrderEntity copyWith({
    String? id,
    String? workOrderNumber,
    WorkOrderStatus? status,
    WorkOrderSource? source,
    WorkOrderPriority? priority,
    String? vehicleId,
    String? vehiclePlate,
    String? vehicleName,
    int? odometerAtRequest,
    int? odometerAtService,
    String? complaint,
    String? reportedBy,
    String? reportedByUserId,
    String? reportedByRole,
    DateTime? reportedAt,
    List<String>? reportedAttachmentUrls,
    String? sourceAlertTypeId,
    List<WorkOrderLine>? lines,
    String? shopId,
    String? shopName,
    DateTime? scheduledDate,
    String? createdBy,
    String? createdByUserId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? approvedBy,
    String? approvedByUserId,
    DateTime? approvedAt,
    double? approvedAmount,
    String? rejectionReason,
    String? varianceReason,
    DateTime? startedAt,
    String? startedBy,
    DateTime? completedAt,
    String? completedBy,
    List<String>? invoiceUrls,
    String? shopInvoiceNumber,
    String? holdReason,
    String? expenseId,
    String? expenseReferenceNumber,
    String? fundAccountId,
    String? fundAccountName,
    String? paymentMethod,
    bool? paidFromDriverAdvance,
    String? currency,
    DateTime? closedAt,
    String? closedBy,
    String? cancellationReason,
    String? notes,
    String? vehicleStatusBefore,
    List<WorkOrderEvent>? timeline,
    bool clearShop = false,
    bool clearScheduledDate = false,
    bool clearRejectionReason = false,
    bool clearHoldReason = false,
    bool clearVarianceReason = false,
    bool clearApproval = false,
  }) {
    return WorkOrderEntity(
      id: id ?? this.id,
      workOrderNumber: workOrderNumber ?? this.workOrderNumber,
      status: status ?? this.status,
      source: source ?? this.source,
      priority: priority ?? this.priority,
      vehicleId: vehicleId ?? this.vehicleId,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      vehicleName: vehicleName ?? this.vehicleName,
      odometerAtRequest: odometerAtRequest ?? this.odometerAtRequest,
      odometerAtService: odometerAtService ?? this.odometerAtService,
      complaint: complaint ?? this.complaint,
      reportedBy: reportedBy ?? this.reportedBy,
      reportedByUserId: reportedByUserId ?? this.reportedByUserId,
      reportedByRole: reportedByRole ?? this.reportedByRole,
      reportedAt: reportedAt ?? this.reportedAt,
      reportedAttachmentUrls:
          reportedAttachmentUrls ?? this.reportedAttachmentUrls,
      sourceAlertTypeId: sourceAlertTypeId ?? this.sourceAlertTypeId,
      lines: lines ?? this.lines,
      shopId: clearShop ? null : (shopId ?? this.shopId),
      shopName: clearShop ? null : (shopName ?? this.shopName),
      scheduledDate:
          clearScheduledDate ? null : (scheduledDate ?? this.scheduledDate),
      createdBy: createdBy ?? this.createdBy,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      approvedBy: clearApproval ? null : (approvedBy ?? this.approvedBy),
      approvedByUserId:
          clearApproval ? null : (approvedByUserId ?? this.approvedByUserId),
      approvedAt: clearApproval ? null : (approvedAt ?? this.approvedAt),
      approvedAmount:
          clearApproval ? null : (approvedAmount ?? this.approvedAmount),
      rejectionReason: clearRejectionReason
          ? null
          : (rejectionReason ?? this.rejectionReason),
      varianceReason:
          clearVarianceReason ? null : (varianceReason ?? this.varianceReason),
      startedAt: startedAt ?? this.startedAt,
      startedBy: startedBy ?? this.startedBy,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
      invoiceUrls: invoiceUrls ?? this.invoiceUrls,
      shopInvoiceNumber: shopInvoiceNumber ?? this.shopInvoiceNumber,
      holdReason: clearHoldReason ? null : (holdReason ?? this.holdReason),
      expenseId: expenseId ?? this.expenseId,
      expenseReferenceNumber:
          expenseReferenceNumber ?? this.expenseReferenceNumber,
      fundAccountId: fundAccountId ?? this.fundAccountId,
      fundAccountName: fundAccountName ?? this.fundAccountName,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paidFromDriverAdvance:
          paidFromDriverAdvance ?? this.paidFromDriverAdvance,
      currency: currency ?? this.currency,
      closedAt: closedAt ?? this.closedAt,
      closedBy: closedBy ?? this.closedBy,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      notes: notes ?? this.notes,
      vehicleStatusBefore: vehicleStatusBefore ?? this.vehicleStatusBefore,
      timeline: timeline ?? this.timeline,
    );
  }

  /// Returns a copy with [event] appended to the timeline.
  WorkOrderEntity withEvent(WorkOrderEvent event) =>
      copyWith(timeline: [...timeline, event], updatedAt: DateTime.now());

  @override
  List<Object?> get props => [
        id,
        workOrderNumber,
        status,
        source,
        priority,
        vehicleId,
        vehiclePlate,
        vehicleName,
        odometerAtRequest,
        odometerAtService,
        complaint,
        reportedBy,
        reportedByUserId,
        reportedByRole,
        reportedAt,
        reportedAttachmentUrls,
        sourceAlertTypeId,
        lines,
        shopId,
        shopName,
        scheduledDate,
        createdBy,
        createdByUserId,
        createdAt,
        updatedAt,
        approvedBy,
        approvedByUserId,
        approvedAt,
        approvedAmount,
        rejectionReason,
        varianceReason,
        startedAt,
        startedBy,
        completedAt,
        completedBy,
        invoiceUrls,
        shopInvoiceNumber,
        holdReason,
        expenseId,
        expenseReferenceNumber,
        fundAccountId,
        fundAccountName,
        paymentMethod,
        paidFromDriverAdvance,
        currency,
        closedAt,
        closedBy,
        cancellationReason,
        notes,
        vehicleStatusBefore,
        timeline,
      ];
}
