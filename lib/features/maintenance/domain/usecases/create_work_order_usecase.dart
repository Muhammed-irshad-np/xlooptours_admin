import 'package:xloop_invoice/features/auth/domain/entities/user_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/finance_policy_entity.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_entity.dart';

import '../entities/work_order_entity.dart';
import '../entities/work_order_event.dart';
import '../entities/work_order_line.dart';
import '../entities/work_order_status.dart';
import '../repositories/work_order_repository.dart';
import '../services/work_order_transition_service.dart';

/// Creates a work order from any of the three entry paths.
///
/// The entry status is decided by [WorkOrderTransitionService.entryStatusFor]:
/// a bare fault report lands in `reported`, a costed job goes to
/// `pendingApproval`, and a job under the policy's auto-approve threshold
/// skips straight to `approved` so routine servicing needs no ceremony.
class CreateWorkOrderUseCase {
  final WorkOrderRepository repository;
  final WorkOrderTransitionService transitions;

  CreateWorkOrderUseCase(this.repository, this.transitions);

  Future<WorkOrderEntity> call({
    required VehicleEntity vehicle,
    required String complaint,
    required UserEntity actor,
    required FinancePolicyEntity policy,
    WorkOrderSource source = WorkOrderSource.adhoc,
    WorkOrderPriority priority = WorkOrderPriority.normal,
    List<WorkOrderLine> lines = const [],
    String? shopId,
    String? shopName,
    DateTime? scheduledDate,
    int? odometerAtRequest,
    List<String> reportedAttachmentUrls = const [],
    String? sourceAlertTypeId,
    String? fundAccountId,
    String? fundAccountName,
    String paymentMethod = 'cash',
    String? notes,
  }) async {
    final number = await repository.generateWorkOrderNumber();
    final now = DateTime.now();

    final estimatedTotal = lines.fold(0.0, (s, l) => s + l.estimatedCost);
    final status = transitions.entryStatusFor(
      source: source,
      estimatedTotal: estimatedTotal,
      hasLines: lines.isNotEmpty,
      policy: policy,
    );

    final actorName = actor.actorLabel;
    final events = <WorkOrderEvent>[
      WorkOrderEvent(
        at: now,
        actor: actorName,
        actorUserId: actor.id,
        actorRole: actor.roleId,
        action: source == WorkOrderSource.reported ? 'reported' : 'issued',
        toStatus: status,
        note: source == WorkOrderSource.alert
            ? 'Created from maintenance alert'
            : null,
      ),
    ];

    // An auto-approved work order records that fact explicitly — the audit
    // trail should never have a silent gap where an approval would be.
    if (status == WorkOrderStatus.approved) {
      events.add(
        WorkOrderEvent(
          at: now,
          actor: 'System',
          action: 'autoApproved',
          fromStatus: WorkOrderStatus.pendingApproval,
          toStatus: WorkOrderStatus.approved,
          note: 'Estimate ${estimatedTotal.toStringAsFixed(2)} is under the '
              'auto-approve limit of '
              '${policy.workOrderAutoApproveBelow.toStringAsFixed(2)}',
        ),
      );
    }

    final workOrder = WorkOrderEntity(
      id: number,
      workOrderNumber: number,
      status: status,
      source: source,
      priority: priority,
      vehicleId: vehicle.id,
      vehiclePlate: vehicle.plateNumber,
      vehicleName: '${vehicle.make} ${vehicle.model} ${vehicle.year}'.trim(),
      odometerAtRequest: odometerAtRequest ?? vehicle.currentOdometer,
      complaint: complaint.trim(),
      reportedBy: actorName,
      reportedByUserId: actor.id,
      reportedByRole: actor.roleId,
      reportedAt: now,
      reportedAttachmentUrls: reportedAttachmentUrls,
      sourceAlertTypeId: sourceAlertTypeId,
      lines: lines,
      shopId: shopId,
      shopName: shopName,
      scheduledDate: scheduledDate,
      createdBy: actorName,
      createdByUserId: actor.id,
      createdAt: now,
      // Auto-approved work orders freeze their approved amount immediately,
      // so variance on close is measured against what was actually waved
      // through rather than a later-edited estimate.
      approvedBy: status == WorkOrderStatus.approved ? 'System (auto)' : null,
      approvedAt: status == WorkOrderStatus.approved ? now : null,
      approvedAmount:
          status == WorkOrderStatus.approved ? estimatedTotal : null,
      fundAccountId: fundAccountId,
      fundAccountName: fundAccountName,
      paymentMethod: paymentMethod,
      notes: notes,
      timeline: events,
    );

    await repository.insertWorkOrder(workOrder);
    return workOrder;
  }
}

/// Saves edits to a work order's details (lines, shop, costs, schedule).
///
/// Deliberately does not touch status — status moves belong to the workflow
/// use cases so every transition lands in the timeline.
class UpdateWorkOrderUseCase {
  final WorkOrderRepository repository;

  UpdateWorkOrderUseCase(this.repository);

  Future<WorkOrderEntity> call({
    required WorkOrderEntity workOrder,
    required UserEntity actor,
    String? note,
  }) async {
    final updated = workOrder.withEvent(
      WorkOrderEvent(
        at: DateTime.now(),
        actor: actor.actorLabel,
        actorUserId: actor.id,
        actorRole: actor.roleId,
        action: 'edited',
        note: note,
      ),
    );
    await repository.updateWorkOrder(updated);
    return updated;
  }
}
