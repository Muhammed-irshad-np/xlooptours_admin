import 'package:xloop_invoice/features/auth/domain/entities/user_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/finance_policy_entity.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_status.dart';
import 'package:xloop_invoice/features/vehicle/domain/repositories/vehicle_repository.dart';

import '../entities/work_order_entity.dart';
import '../entities/work_order_event.dart';
import '../entities/work_order_status.dart';
import '../repositories/work_order_repository.dart';
import '../services/work_order_transition_service.dart';

/// Shared plumbing for every status move: validate the precondition, stamp
/// the fields, append the timeline event, save.
///
/// Keeping this in one place is what guarantees no transition can happen
/// without an audit entry.
abstract class _WorkOrderTransition {
  final WorkOrderRepository repository;
  final WorkOrderTransitionService transitions;

  const _WorkOrderTransition(this.repository, this.transitions);

  /// Throws [StateError] with a user-facing message when [action] is blocked.
  void assertAllowed({
    required WorkOrderAction action,
    required WorkOrderEntity workOrder,
    required FinancePolicyEntity policy,
    required List<WorkOrderStatus> validFrom,
  }) {
    if (!validFrom.contains(workOrder.status)) {
      throw StateError(
        'Cannot ${action.label.toLowerCase()} a work order that is '
        '${workOrder.status.displayName.toLowerCase()}.',
      );
    }
    final blocker = transitions.blockerFor(
      action: action,
      workOrder: workOrder,
      policy: policy,
    );
    if (blocker != null) throw StateError(blocker);
  }

  WorkOrderEvent event({
    required UserEntity actor,
    required String action,
    WorkOrderStatus? from,
    WorkOrderStatus? to,
    String? note,
  }) {
    return WorkOrderEvent(
      at: DateTime.now(),
      actor: actor.actorLabel,
      actorUserId: actor.id,
      actorRole: actor.roleId,
      action: action,
      fromStatus: from,
      toStatus: to,
      note: note,
    );
  }

  Future<WorkOrderEntity> save(WorkOrderEntity workOrder) async {
    await repository.updateWorkOrder(workOrder);
    return workOrder;
  }
}

/// `reported` (or `rejected`) → `pendingApproval`, or straight to `approved`
/// when the estimate is under the auto-approve threshold.
class IssueWorkOrderUseCase extends _WorkOrderTransition {
  const IssueWorkOrderUseCase(super.repository, super.transitions);

  Future<WorkOrderEntity> call({
    required WorkOrderEntity workOrder,
    required UserEntity actor,
    required FinancePolicyEntity policy,
  }) async {
    final isReissue = workOrder.status == WorkOrderStatus.rejected;
    assertAllowed(
      action: isReissue ? WorkOrderAction.reissue : WorkOrderAction.issue,
      workOrder: workOrder,
      policy: policy,
      validFrom: const [WorkOrderStatus.reported, WorkOrderStatus.rejected],
    );

    final estimate = workOrder.estimatedTotal;
    final autoApproved = policy.workOrderSkipsApproval(estimate);
    final next = autoApproved
        ? WorkOrderStatus.approved
        : WorkOrderStatus.pendingApproval;

    var updated = workOrder
        .copyWith(
          status: next,
          updatedAt: DateTime.now(),
          clearRejectionReason: true,
          approvedBy: autoApproved ? 'System (auto)' : null,
          approvedAt: autoApproved ? DateTime.now() : null,
          approvedAmount: autoApproved ? estimate : null,
        )
        .withEvent(
          event(
            actor: actor,
            action: isReissue ? 'reissued' : 'issued',
            from: workOrder.status,
            to: next,
          ),
        );

    if (autoApproved) {
      updated = updated.withEvent(
        WorkOrderEvent(
          at: DateTime.now(),
          actor: 'System',
          action: 'autoApproved',
          fromStatus: WorkOrderStatus.pendingApproval,
          toStatus: WorkOrderStatus.approved,
          note: 'Estimate ${estimate.toStringAsFixed(2)} is under the '
              'auto-approve limit of '
              '${policy.workOrderAutoApproveBelow.toStringAsFixed(2)}',
        ),
      );
    }

    return save(updated);
  }
}

/// `pendingApproval` → `approved`. Freezes [WorkOrderEntity.approvedAmount].
class ApproveWorkOrderUseCase extends _WorkOrderTransition {
  const ApproveWorkOrderUseCase(super.repository, super.transitions);

  Future<WorkOrderEntity> call({
    required WorkOrderEntity workOrder,
    required UserEntity actor,
    required FinancePolicyEntity policy,
    String? note,
  }) async {
    assertAllowed(
      action: WorkOrderAction.approve,
      workOrder: workOrder,
      policy: policy,
      validFrom: const [WorkOrderStatus.pendingApproval],
    );

    // The amount is frozen here, not read live off the lines, so a later
    // edit to the estimate cannot silently widen what was authorised.
    final amount = workOrder.varianceReason != null
        ? workOrder.actualTotal
        : workOrder.estimatedTotal;

    final updated = workOrder
        .copyWith(
          status: WorkOrderStatus.approved,
          approvedBy: actor.actorLabel,
          approvedByUserId: actor.id,
          approvedAt: DateTime.now(),
          approvedAmount: amount,
          updatedAt: DateTime.now(),
          clearRejectionReason: true,
        )
        .withEvent(
          event(
            actor: actor,
            action: 'approved',
            from: workOrder.status,
            to: WorkOrderStatus.approved,
            note: note ?? 'Approved up to ${amount.toStringAsFixed(2)} '
                '${workOrder.currency}',
          ),
        );
    return save(updated);
  }
}

/// `pendingApproval` → `rejected`.
class RejectWorkOrderUseCase extends _WorkOrderTransition {
  const RejectWorkOrderUseCase(super.repository, super.transitions);

  Future<WorkOrderEntity> call({
    required WorkOrderEntity workOrder,
    required UserEntity actor,
    required FinancePolicyEntity policy,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw StateError('A rejection reason is required.');
    }
    assertAllowed(
      action: WorkOrderAction.reject,
      workOrder: workOrder,
      policy: policy,
      validFrom: const [WorkOrderStatus.pendingApproval],
    );

    final updated = workOrder
        .copyWith(
          status: WorkOrderStatus.rejected,
          rejectionReason: reason.trim(),
          updatedAt: DateTime.now(),
          clearApproval: true,
        )
        .withEvent(
          event(
            actor: actor,
            action: 'rejected',
            from: workOrder.status,
            to: WorkOrderStatus.rejected,
            note: reason.trim(),
          ),
        );
    return save(updated);
  }
}

/// `approved` → `inProgress`, and takes the vehicle off the road.
///
/// This is the half of the "tag the vehicle as in maintenance" requirement
/// that the fleet list reads back: the vehicle's own `status` becomes
/// [VehicleStatus.inShop], with its previous value parked on the work order
/// so closing restores exactly what was there before.
class StartWorkOrderUseCase extends _WorkOrderTransition {
  final VehicleRepository vehicleRepository;

  const StartWorkOrderUseCase(
    super.repository,
    super.transitions,
    this.vehicleRepository,
  );

  Future<WorkOrderEntity> call({
    required WorkOrderEntity workOrder,
    required UserEntity actor,
    required FinancePolicyEntity policy,
    int? odometerAtService,
  }) async {
    assertAllowed(
      action: WorkOrderAction.start,
      workOrder: workOrder,
      policy: policy,
      validFrom: const [WorkOrderStatus.approved],
    );

    final vehicle = await vehicleRepository.getVehicleById(workOrder.vehicleId);
    final statusBefore = vehicle?.status ?? VehicleStatus.active;

    if (vehicle != null && !VehicleStatus.isInShop(vehicle.status)) {
      await vehicleRepository.updateVehicle(
        vehicle.copyWith(status: VehicleStatus.inShop),
      );
    }

    final updated = workOrder
        .copyWith(
          status: WorkOrderStatus.inProgress,
          startedAt: DateTime.now(),
          startedBy: actor.actorLabel,
          odometerAtService:
              odometerAtService ?? vehicle?.currentOdometer,
          vehicleStatusBefore: statusBefore,
          updatedAt: DateTime.now(),
          clearHoldReason: true,
        )
        .withEvent(
          event(
            actor: actor,
            action: 'started',
            from: workOrder.status,
            to: WorkOrderStatus.inProgress,
            note: 'Vehicle marked ${VehicleStatus.inShop}'
                '${workOrder.shopName != null ? ' at ${workOrder.shopName}' : ''}',
          ),
        );
    return save(updated);
  }
}

/// `inProgress` → `onHold` (waiting for parts, shop delay).
///
/// The vehicle stays flagged as in-shop: it is still not available.
class HoldWorkOrderUseCase extends _WorkOrderTransition {
  const HoldWorkOrderUseCase(super.repository, super.transitions);

  Future<WorkOrderEntity> call({
    required WorkOrderEntity workOrder,
    required UserEntity actor,
    required FinancePolicyEntity policy,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw StateError('A reason for the hold is required.');
    }
    assertAllowed(
      action: WorkOrderAction.hold,
      workOrder: workOrder,
      policy: policy,
      validFrom: const [WorkOrderStatus.inProgress],
    );

    final updated = workOrder
        .copyWith(
          status: WorkOrderStatus.onHold,
          holdReason: reason.trim(),
          updatedAt: DateTime.now(),
        )
        .withEvent(
          event(
            actor: actor,
            action: 'held',
            from: workOrder.status,
            to: WorkOrderStatus.onHold,
            note: reason.trim(),
          ),
        );
    return save(updated);
  }
}

/// `onHold` → `inProgress`.
class ResumeWorkOrderUseCase extends _WorkOrderTransition {
  const ResumeWorkOrderUseCase(super.repository, super.transitions);

  Future<WorkOrderEntity> call({
    required WorkOrderEntity workOrder,
    required UserEntity actor,
    required FinancePolicyEntity policy,
  }) async {
    assertAllowed(
      action: WorkOrderAction.resume,
      workOrder: workOrder,
      policy: policy,
      validFrom: const [WorkOrderStatus.onHold],
    );

    final updated = workOrder
        .copyWith(
          status: WorkOrderStatus.inProgress,
          updatedAt: DateTime.now(),
          clearHoldReason: true,
        )
        .withEvent(
          event(
            actor: actor,
            action: 'resumed',
            from: workOrder.status,
            to: WorkOrderStatus.inProgress,
          ),
        );
    return save(updated);
  }
}

/// `inProgress` → `completed`. Work is done and the invoice is in; the money
/// has not moved yet.
///
/// When the actual cost has run past what was approved (beyond the policy's
/// tolerance) this routes back to `pendingApproval` instead — the overrun
/// needs a human before it can become an expense.
class CompleteWorkOrderUseCase extends _WorkOrderTransition {
  const CompleteWorkOrderUseCase(super.repository, super.transitions);

  Future<WorkOrderEntity> call({
    required WorkOrderEntity workOrder,
    required UserEntity actor,
    required FinancePolicyEntity policy,
  }) async {
    assertAllowed(
      action: WorkOrderAction.complete,
      workOrder: workOrder,
      policy: policy,
      validFrom: const [WorkOrderStatus.inProgress],
    );

    final approved = workOrder.approvedAmount;
    final actual = workOrder.actualTotal;
    final overran = approved != null &&
        !policy.isWorkOrderVarianceAcceptable(
          approvedAmount: approved,
          actual: actual,
        );

    if (overran) {
      final note =
          'Actual ${actual.toStringAsFixed(2)} exceeds approved '
          '${approved.toStringAsFixed(2)} by more than '
          '${policy.workOrderVarianceTolerancePct.toStringAsFixed(0)}% — '
          're-approval required.';
      final updated = workOrder
          .copyWith(
            status: WorkOrderStatus.pendingApproval,
            completedAt: DateTime.now(),
            completedBy: actor.actorLabel,
            varianceReason: note,
            updatedAt: DateTime.now(),
          )
          .withEvent(
            event(
              actor: actor,
              action: 'completed',
              from: workOrder.status,
              to: WorkOrderStatus.pendingApproval,
              note: note,
            ),
          );
      return save(updated);
    }

    final updated = workOrder
        .copyWith(
          status: WorkOrderStatus.completed,
          completedAt: DateTime.now(),
          completedBy: actor.actorLabel,
          updatedAt: DateTime.now(),
        )
        .withEvent(
          event(
            actor: actor,
            action: 'completed',
            from: workOrder.status,
            to: WorkOrderStatus.completed,
            note: 'Actual ${actual.toStringAsFixed(2)} '
                '${workOrder.currency}',
          ),
        );
    return save(updated);
  }
}

/// Abandons a work order before completion and releases the vehicle.
class CancelWorkOrderUseCase extends _WorkOrderTransition {
  final VehicleRepository vehicleRepository;

  const CancelWorkOrderUseCase(
    super.repository,
    super.transitions,
    this.vehicleRepository,
  );

  Future<WorkOrderEntity> call({
    required WorkOrderEntity workOrder,
    required UserEntity actor,
    required FinancePolicyEntity policy,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw StateError('A cancellation reason is required.');
    }
    if (!workOrder.status.canBeCancelled) {
      throw StateError(
        'A ${workOrder.status.displayName.toLowerCase()} work order cannot be '
        'cancelled.',
      );
    }

    if (workOrder.occupiesVehicle) {
      await _releaseVehicle(workOrder);
    }

    final updated = workOrder
        .copyWith(
          status: WorkOrderStatus.cancelled,
          cancellationReason: reason.trim(),
          updatedAt: DateTime.now(),
        )
        .withEvent(
          event(
            actor: actor,
            action: 'cancelled',
            from: workOrder.status,
            to: WorkOrderStatus.cancelled,
            note: reason.trim(),
          ),
        );
    return save(updated);
  }

  Future<void> _releaseVehicle(WorkOrderEntity workOrder) async {
    final vehicle = await vehicleRepository.getVehicleById(workOrder.vehicleId);
    if (vehicle == null) return;
    if (!VehicleStatus.isInShop(vehicle.status)) return;
    await vehicleRepository.updateVehicle(
      vehicle.copyWith(
        status: workOrder.vehicleStatusBefore ?? VehicleStatus.active,
      ),
    );
  }
}
