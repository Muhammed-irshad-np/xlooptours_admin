import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/features/finance/domain/entities/finance_policy_entity.dart';
import 'package:xloop_invoice/features/maintenance/domain/entities/work_order_status.dart';
import 'package:xloop_invoice/features/maintenance/domain/services/work_order_transition_service.dart';

import '../usecases/test_work_order_fakes.dart';

void main() {
  const service = WorkOrderTransitionService();
  const policy = FinancePolicyEntity();

  final coordinator = testUser(role: 'coordinator', id: 'coord-1');
  final manager = testUser(role: 'manager', id: 'mgr-1', name: 'Manager A');
  final driver = testUser(role: 'driver', id: 'drv-1', name: 'Driver A');

  group('availableActions', () {
    test('a coordinator can cost a report but not approve it', () {
      final workOrder = testWorkOrder(status: WorkOrderStatus.reported);

      final actions = service.availableActions(
        workOrder: workOrder,
        user: coordinator,
        policy: policy,
      );

      expect(actions, contains(WorkOrderAction.issue));
      expect(actions, isNot(contains(WorkOrderAction.approve)));
    });

    test('a manager sees approve and reject on a pending work order', () {
      final workOrder = testWorkOrder(
        status: WorkOrderStatus.pendingApproval,
        lines: [testLine(estimate: 500)],
      );

      final actions = service.availableActions(
        workOrder: workOrder,
        user: manager,
        policy: policy,
      );

      expect(actions, contains(WorkOrderAction.approve));
      expect(actions, contains(WorkOrderAction.reject));
    });

    test('a coordinator sees nothing to do on a pending work order', () {
      final workOrder = testWorkOrder(
        status: WorkOrderStatus.pendingApproval,
        lines: [testLine(estimate: 5000)],
      );

      final actions = service.availableActions(
        workOrder: workOrder,
        user: coordinator,
        policy: policy,
      );

      expect(actions, isNot(contains(WorkOrderAction.approve)));
    });

    test('a driver can do nothing beyond reporting', () {
      final workOrder = testWorkOrder(status: WorkOrderStatus.reported);

      final actions = service.availableActions(
        workOrder: workOrder,
        user: driver,
        policy: policy,
      );

      expect(actions, isEmpty);
    });

    test('an amount over the role limit is not approvable', () {
      // Default manager limit is 5000.
      final workOrder = testWorkOrder(
        status: WorkOrderStatus.pendingApproval,
        lines: [testLine(estimate: 9000)],
      );

      final actions = service.availableActions(
        workOrder: workOrder,
        user: manager,
        policy: policy,
      );

      expect(actions, isNot(contains(WorkOrderAction.approve)));
    });

    test('blocks self-approval when policy says so', () {
      final workOrder = testWorkOrder(
        status: WorkOrderStatus.pendingApproval,
        lines: [testLine(estimate: 500)],
      ).copyWith(createdByUserId: manager.id);

      final actions = service.availableActions(
        workOrder: workOrder,
        user: manager,
        policy: policy,
      );

      expect(actions, isNot(contains(WorkOrderAction.approve)));
      // Rejecting your own request is still fine.
      expect(actions, contains(WorkOrderAction.reject));
    });

    test('a terminal work order offers nothing', () {
      for (final status in [
        WorkOrderStatus.closed,
        WorkOrderStatus.cancelled,
      ]) {
        final actions = service.availableActions(
          workOrder: testWorkOrder(status: status),
          user: manager,
          policy: policy,
        );
        expect(actions, isEmpty, reason: 'status $status');
      }
    });
  });

  group('primaryAction', () {
    test('prefers the forward move over edit and cancel', () {
      final workOrder = testWorkOrder(status: WorkOrderStatus.approved);

      final primary = service.primaryAction(
        workOrder: workOrder,
        user: coordinator,
        policy: policy,
      );

      expect(primary, WorkOrderAction.start);
    });

    test('is close on a completed work order', () {
      final primary = service.primaryAction(
        workOrder: testWorkOrder(status: WorkOrderStatus.completed),
        user: coordinator,
        policy: policy,
      );

      expect(primary, WorkOrderAction.close);
    });
  });

  group('laneFor', () {
    test('an approval sits in the manager queue, not the coordinator queue',
        () {
      final workOrder = testWorkOrder(
        status: WorkOrderStatus.pendingApproval,
        lines: [testLine(estimate: 500)],
      );

      expect(
        service.laneFor(
          workOrder: workOrder,
          user: manager,
          policy: policy,
        ),
        WorkOrderLane.needsAction,
      );
      expect(
        service.laneFor(
          workOrder: workOrder,
          user: coordinator,
          policy: policy,
        ),
        WorkOrderLane.inProgress,
      );
    });

    test('a held job is not in anyone queue — the shop is the blocker', () {
      final workOrder = testWorkOrder(status: WorkOrderStatus.onHold);

      expect(
        service.laneFor(
          workOrder: workOrder,
          user: coordinator,
          policy: policy,
        ),
        WorkOrderLane.inProgress,
      );
    });

    test('terminal work orders are done for everyone', () {
      expect(
        service.laneFor(
          workOrder: testWorkOrder(status: WorkOrderStatus.closed),
          user: manager,
          policy: policy,
        ),
        WorkOrderLane.done,
      );
    });
  });

  group('entryStatusFor', () {
    test('a report is always reported, even with lines', () {
      expect(
        service.entryStatusFor(
          source: WorkOrderSource.reported,
          estimatedTotal: 1000,
          hasLines: true,
          policy: policy,
        ),
        WorkOrderStatus.reported,
      );
    });

    test('no lines means nothing to approve yet', () {
      expect(
        service.entryStatusFor(
          source: WorkOrderSource.adhoc,
          estimatedTotal: 0,
          hasLines: false,
          policy: policy,
        ),
        WorkOrderStatus.reported,
      );
    });

    test('auto-approve can be switched off with a zero threshold', () {
      expect(
        service.entryStatusFor(
          source: WorkOrderSource.adhoc,
          estimatedTotal: 50,
          hasLines: true,
          policy: const FinancePolicyEntity(workOrderAutoApproveBelow: 0),
        ),
        WorkOrderStatus.pendingApproval,
      );
    });
  });

  group('blockerFor', () {
    test('names the variance ceiling when an actual overran', () {
      final workOrder = testWorkOrder(
        approvedAmount: 400,
        lines: [testLine(estimate: 400, actual: 900)],
      );

      final blocker = service.blockerFor(
        action: WorkOrderAction.close,
        workOrder: workOrder,
        policy: policy,
      );

      expect(blocker, isNotNull);
      expect(blocker, contains('440'));
    });

    test('reports an already-posted work order by its expense', () {
      final workOrder = testWorkOrder(expenseId: 'wo_WO-2026-0001')
          .copyWith(expenseReferenceNumber: '#10007');

      final blocker = service.blockerFor(
        action: WorkOrderAction.close,
        workOrder: workOrder,
        policy: policy,
      );

      expect(blocker, contains('#10007'));
    });

    test('nothing blocks a clean close', () {
      expect(
        service.blockerFor(
          action: WorkOrderAction.close,
          workOrder: testWorkOrder(),
          policy: policy,
        ),
        isNull,
      );
    });
  });
}
