import 'package:xloop_invoice/features/auth/domain/entities/user_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/finance_policy_entity.dart';
import 'package:xloop_invoice/features/finance/domain/services/finance_permission_service.dart';

import '../entities/work_order_entity.dart';
import '../entities/work_order_status.dart';

/// Every move a user can make on a work order.
enum WorkOrderAction {
  /// Cost a report and send it for approval.
  issue,

  /// Authorise the spend.
  approve,

  /// Refuse the spend.
  reject,

  /// Send a rejected work order back for another look.
  reissue,

  /// Vehicle has gone to the workshop.
  start,

  /// Pause (waiting for parts).
  hold,

  /// Resume after a hold.
  resume,

  /// Work finished, invoice in hand.
  complete,

  /// Post the expense and write maintenance history.
  close,

  /// Abandon before completion.
  cancel,

  /// Change lines / shop / costs.
  edit;

  String get label {
    switch (this) {
      case WorkOrderAction.issue:
        return 'Send for Approval';
      case WorkOrderAction.approve:
        return 'Approve';
      case WorkOrderAction.reject:
        return 'Reject';
      case WorkOrderAction.reissue:
        return 'Re-submit';
      case WorkOrderAction.start:
        return 'Start Work';
      case WorkOrderAction.hold:
        return 'Put On Hold';
      case WorkOrderAction.resume:
        return 'Resume Work';
      case WorkOrderAction.complete:
        return 'Mark Completed';
      case WorkOrderAction.close:
        return 'Close & Post Expense';
      case WorkOrderAction.cancel:
        return 'Cancel';
      case WorkOrderAction.edit:
        return 'Edit Details';
    }
  }

  /// Short label for the primary button when space is tight.
  String get shortLabel {
    switch (this) {
      case WorkOrderAction.issue:
        return 'Submit';
      case WorkOrderAction.close:
        return 'Close & Post';
      default:
        return label;
    }
  }

  /// Whether the action needs a typed reason before it can proceed.
  bool get requiresReason =>
      this == WorkOrderAction.reject ||
      this == WorkOrderAction.cancel ||
      this == WorkOrderAction.hold;

  /// Whether the action moves money and deserves a confirmation step.
  bool get isDestructiveOrFinancial =>
      this == WorkOrderAction.close ||
      this == WorkOrderAction.cancel ||
      this == WorkOrderAction.reject;

  /// Whether this action advances the work order towards closure.
  ///
  /// Editing, cancelling, rejecting and holding are always *available* to
  /// whoever runs the job, so treating them as forward moves would park every
  /// live work order in that person's queue forever.
  bool get movesForward =>
      this == WorkOrderAction.issue ||
      this == WorkOrderAction.reissue ||
      this == WorkOrderAction.approve ||
      this == WorkOrderAction.start ||
      this == WorkOrderAction.resume ||
      this == WorkOrderAction.complete ||
      this == WorkOrderAction.close;
}

/// Which lane a work order sits in on the board.
enum WorkOrderLane {
  /// Waiting on the current user specifically.
  needsAction,

  /// Live, but waiting on someone else or on the workshop.
  inProgress,

  /// Terminal.
  done;

  String get title {
    switch (this) {
      case WorkOrderLane.needsAction:
        return 'Needs your action';
      case WorkOrderLane.inProgress:
        return 'In progress';
      case WorkOrderLane.done:
        return 'Done';
    }
  }
}

/// The single authority on what may happen to a work order next.
///
/// The board and the detail page both read from here, so a coordinator never
/// sees a button they cannot use and nobody has to learn the state machine to
/// use the screen: whatever is in [WorkOrderLane.needsAction] is theirs.
class WorkOrderTransitionService {
  const WorkOrderTransitionService();

  /// Every action [user] may perform on [workOrder] right now, most
  /// important first.
  List<WorkOrderAction> availableActions({
    required WorkOrderEntity workOrder,
    required UserEntity? user,
    required FinancePolicyEntity policy,
  }) {
    if (user == null) return const [];

    final canIssue = FinancePermissionService.canIssueWorkOrder(
      user: user,
      policy: policy,
    );
    final canProgress = FinancePermissionService.canProgressWorkOrder(
      user: user,
      policy: policy,
    );
    final canApprove = FinancePermissionService.canApproveWorkOrder(
      user: user,
      policy: policy,
      amount: workOrder.estimatedTotal,
    );
    final canClose = FinancePermissionService.canCloseWorkOrder(
      user: user,
      policy: policy,
    );
    final canCancel = FinancePermissionService.canCancelWorkOrder(
      user: user,
      policy: policy,
    );

    final actions = <WorkOrderAction>[];

    switch (workOrder.status) {
      case WorkOrderStatus.reported:
        if (canIssue) actions.add(WorkOrderAction.issue);
        break;

      case WorkOrderStatus.pendingApproval:
        if (canApprove && !_isSelfApprovalBlocked(workOrder, user, policy)) {
          actions.add(WorkOrderAction.approve);
        }
        if (canApprove) actions.add(WorkOrderAction.reject);
        break;

      case WorkOrderStatus.approved:
        if (canProgress) actions.add(WorkOrderAction.start);
        break;

      case WorkOrderStatus.inProgress:
        if (canProgress) {
          actions.add(WorkOrderAction.complete);
          actions.add(WorkOrderAction.hold);
        }
        break;

      case WorkOrderStatus.onHold:
        if (canProgress) actions.add(WorkOrderAction.resume);
        break;

      case WorkOrderStatus.completed:
        if (canClose) actions.add(WorkOrderAction.close);
        break;

      case WorkOrderStatus.rejected:
        if (canIssue) actions.add(WorkOrderAction.reissue);
        break;

      case WorkOrderStatus.closed:
      case WorkOrderStatus.cancelled:
        break;
    }

    if (workOrder.status.canEditDetails && canIssue) {
      actions.add(WorkOrderAction.edit);
    }
    if (workOrder.status.canBeCancelled && canCancel) {
      actions.add(WorkOrderAction.cancel);
    }

    return actions;
  }

  /// The one action to surface as the primary button.
  WorkOrderAction? primaryAction({
    required WorkOrderEntity workOrder,
    required UserEntity? user,
    required FinancePolicyEntity policy,
  }) {
    final actions = availableActions(
      workOrder: workOrder,
      user: user,
      policy: policy,
    );
    for (final action in actions) {
      if (action.movesForward) return action;
    }
    // Only secondary actions (edit / cancel / reject / hold) are open to this
    // user, and none of those is something they are being *waited on* for.
    return null;
  }

  /// Whether [workOrder] is waiting on [user] specifically.
  bool needsActionFrom({
    required WorkOrderEntity workOrder,
    required UserEntity? user,
    required FinancePolicyEntity policy,
  }) {
    if (workOrder.status.isTerminal) return false;
    final primary = primaryAction(
      workOrder: workOrder,
      user: user,
      policy: policy,
    );
    if (primary == null) return false;
    // Resuming a hold is a nudge, not a queue item — the shop is the blocker.
    return primary != WorkOrderAction.resume;
  }

  /// Which board lane [workOrder] belongs in for [user].
  WorkOrderLane laneFor({
    required WorkOrderEntity workOrder,
    required UserEntity? user,
    required FinancePolicyEntity policy,
  }) {
    if (workOrder.status.isTerminal) return WorkOrderLane.done;
    if (needsActionFrom(
      workOrder: workOrder,
      user: user,
      policy: policy,
    )) {
      return WorkOrderLane.needsAction;
    }
    return WorkOrderLane.inProgress;
  }

  /// Status a newly created work order should land in.
  ///
  /// A report starts as [WorkOrderStatus.reported] because it has no costing
  /// yet. A costed work order goes straight to approval — or skips it when the
  /// estimate is under the policy's auto-approve threshold, so an oil change
  /// does not need a manager's attention.
  WorkOrderStatus entryStatusFor({
    required WorkOrderSource source,
    required double estimatedTotal,
    required bool hasLines,
    required FinancePolicyEntity policy,
  }) {
    if (source == WorkOrderSource.reported || !hasLines) {
      return WorkOrderStatus.reported;
    }
    if (policy.workOrderSkipsApproval(estimatedTotal)) {
      return WorkOrderStatus.approved;
    }
    return WorkOrderStatus.pendingApproval;
  }

  /// Why [action] cannot be performed, or null when it can.
  ///
  /// Complements the permission checks above with the data preconditions —
  /// these are the messages the user actually needs to see.
  String? blockerFor({
    required WorkOrderAction action,
    required WorkOrderEntity workOrder,
    required FinancePolicyEntity policy,
  }) {
    switch (action) {
      case WorkOrderAction.issue:
      case WorkOrderAction.reissue:
        if (workOrder.lines.isEmpty) {
          return 'Add at least one maintenance item before sending for approval.';
        }
        if (workOrder.estimatedTotal <= 0) {
          return 'Enter an estimated cost before sending for approval.';
        }
        return null;

      case WorkOrderAction.complete:
        if (workOrder.lines.where((l) => l.completed).isEmpty) {
          return 'Tick at least one item as carried out.';
        }
        if (policy.requireInvoiceOnWorkOrderComplete &&
            workOrder.invoiceUrls.isEmpty) {
          return 'Attach the shop invoice before marking this completed.';
        }
        if (workOrder.actualTotal <= 0) {
          return 'Enter the actual cost for at least one item.';
        }
        return null;

      case WorkOrderAction.close:
        if (workOrder.isPosted) {
          return 'Already closed — expense ${workOrder.expenseReferenceNumber ?? workOrder.expenseId} was posted.';
        }
        if ((workOrder.fundAccountId ?? '').isEmpty) {
          return 'Choose the wallet this was paid from before closing.';
        }
        final approved = workOrder.approvedAmount;
        if (approved != null &&
            !policy.isWorkOrderVarianceAcceptable(
              approvedAmount: approved,
              actual: workOrder.actualTotal,
            )) {
          final ceiling = policy.workOrderVarianceCeiling(approved);
          return 'Actual ${workOrder.actualTotal.toStringAsFixed(2)} exceeds the '
              'approved ${approved.toStringAsFixed(2)} by more than '
              '${policy.workOrderVarianceTolerancePct.toStringAsFixed(0)}% '
              '(limit ${ceiling.toStringAsFixed(2)}). Send it back for '
              're-approval.';
        }
        return null;

      case WorkOrderAction.start:
        if ((workOrder.shopId ?? '').isEmpty &&
            (workOrder.shopName ?? '').isEmpty) {
          return 'Pick the workshop before starting the job.';
        }
        return null;

      case WorkOrderAction.approve:
      case WorkOrderAction.reject:
      case WorkOrderAction.hold:
      case WorkOrderAction.resume:
      case WorkOrderAction.cancel:
      case WorkOrderAction.edit:
        return null;
    }
  }

  bool _isSelfApprovalBlocked(
    WorkOrderEntity workOrder,
    UserEntity user,
    FinancePolicyEntity policy,
  ) {
    if (!policy.blockSelfApprove) return false;
    if (user.isAdmin) return false;
    final creator = workOrder.createdByUserId;
    return creator != null && creator.isNotEmpty && creator == user.id;
  }
}
