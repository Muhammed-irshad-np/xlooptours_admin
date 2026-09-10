import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/features/finance/domain/entities/finance_policy_entity.dart';
import 'package:xloop_invoice/features/maintenance/domain/entities/work_order_status.dart';
import 'package:xloop_invoice/features/maintenance/domain/services/work_order_transition_service.dart';
import 'package:xloop_invoice/features/maintenance/domain/usecases/create_work_order_usecase.dart';
import 'package:xloop_invoice/features/maintenance/domain/usecases/work_order_workflow_usecases.dart';

import 'test_work_order_fakes.dart';

void main() {
  late FakeWorkOrderRepository repo;
  late FakeVehicleRepository vehicles;
  const transitions = WorkOrderTransitionService();
  const policy = FinancePolicyEntity();

  setUp(() {
    repo = FakeWorkOrderRepository();
    vehicles = FakeVehicleRepository();
    vehicles.store['veh-1'] = testVehicle();
  });

  group('CreateWorkOrderUseCase', () {
    test('a fault report lands in reported with no costing', () async {
      final useCase = CreateWorkOrderUseCase(repo, transitions);

      final created = await useCase(
        vehicle: testVehicle(),
        complaint: 'Grinding noise from front brakes',
        actor: testUser(role: 'driver', name: 'Shamnad'),
        policy: policy,
        source: WorkOrderSource.reported,
      );

      expect(created.status, WorkOrderStatus.reported);
      expect(created.workOrderNumber, 'WO-2026-0001');
      expect(created.reportedBy, contains('Shamnad'));
      expect(created.timeline.single.action, 'reported');
    });

    test('a costed job above the threshold goes to pendingApproval', () async {
      final useCase = CreateWorkOrderUseCase(repo, transitions);

      final created = await useCase(
        vehicle: testVehicle(),
        complaint: 'Service due',
        actor: testUser(),
        policy: policy,
        lines: [testLine(estimate: 900)],
      );

      expect(created.status, WorkOrderStatus.pendingApproval);
      expect(created.approvedAmount, isNull);
    });

    test('a job under the auto-approve limit skips approval', () async {
      final useCase = CreateWorkOrderUseCase(repo, transitions);

      // Default threshold is 300 SAR — an oil change should not need a
      // manager's attention.
      final created = await useCase(
        vehicle: testVehicle(),
        complaint: 'Oil change',
        actor: testUser(),
        policy: policy,
        lines: [testLine(estimate: 250)],
      );

      expect(created.status, WorkOrderStatus.approved);
      expect(created.approvedAmount, 250);
      // The audit trail records the auto-approval rather than leaving a gap
      // where an approval would be.
      expect(
        created.timeline.map((e) => e.action),
        contains('autoApproved'),
      );
    });
  });

  group('IssueWorkOrderUseCase', () {
    test('refuses to issue a work order with no items', () async {
      final useCase = IssueWorkOrderUseCase(repo, transitions);
      final workOrder = testWorkOrder(
        status: WorkOrderStatus.reported,
        lines: const [],
        approvedAmount: null,
      );

      await expectLater(
        () => useCase(
          workOrder: workOrder,
          actor: testUser(),
          policy: policy,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('sends a costed report for approval', () async {
      final useCase = IssueWorkOrderUseCase(repo, transitions);
      final workOrder = testWorkOrder(
        status: WorkOrderStatus.reported,
        lines: [testLine(estimate: 800)],
        approvedAmount: null,
      );

      final result = await useCase(
        workOrder: workOrder,
        actor: testUser(),
        policy: policy,
      );

      expect(result.status, WorkOrderStatus.pendingApproval);
    });
  });

  group('ApproveWorkOrderUseCase', () {
    test('freezes the approved amount at the time of approval', () async {
      final useCase = ApproveWorkOrderUseCase(repo, transitions);
      final workOrder = testWorkOrder(
        status: WorkOrderStatus.pendingApproval,
        lines: [testLine(estimate: 500)],
        approvedAmount: null,
      );

      final result = await useCase(
        workOrder: workOrder,
        actor: testUser(role: 'manager'),
        policy: policy,
      );

      expect(result.status, WorkOrderStatus.approved);
      expect(result.approvedAmount, 500);
      expect(result.approvedBy, contains('Coordinator A'));
    });
  });

  group('StartWorkOrderUseCase', () {
    test('marks the vehicle In-Shop and remembers its previous status',
        () async {
      final useCase = StartWorkOrderUseCase(repo, transitions, vehicles);
      final workOrder = testWorkOrder(status: WorkOrderStatus.approved);

      final result = await useCase(
        workOrder: workOrder,
        actor: testUser(),
        policy: policy,
      );

      expect(result.status, WorkOrderStatus.inProgress);
      expect(result.vehicleStatusBefore, 'Active');
      expect(vehicles.store['veh-1']!.status, 'In-Shop');
    });

    test('refuses to start without a workshop', () async {
      final useCase = StartWorkOrderUseCase(repo, transitions, vehicles);
      final workOrder = testWorkOrder(status: WorkOrderStatus.approved)
          .copyWith(clearShop: true);

      await expectLater(
        () => useCase(
          workOrder: workOrder,
          actor: testUser(),
          policy: policy,
        ),
        throwsA(
          isA<StateError>()
              .having((e) => e.message, 'message', contains('workshop')),
        ),
      );
    });
  });

  group('CompleteWorkOrderUseCase', () {
    test('completes when the actual is within tolerance', () async {
      final useCase = CompleteWorkOrderUseCase(repo, transitions);
      final workOrder = testWorkOrder(
        status: WorkOrderStatus.inProgress,
        approvedAmount: 400,
        lines: [testLine(estimate: 400, actual: 410)],
      );

      final result = await useCase(
        workOrder: workOrder,
        actor: testUser(),
        policy: policy,
      );

      expect(result.status, WorkOrderStatus.completed);
    });

    test('routes an overrun back for re-approval rather than completing',
        () async {
      final useCase = CompleteWorkOrderUseCase(repo, transitions);
      final workOrder = testWorkOrder(
        status: WorkOrderStatus.inProgress,
        approvedAmount: 400,
        lines: [testLine(estimate: 400, actual: 2400)],
      );

      final result = await useCase(
        workOrder: workOrder,
        actor: testUser(),
        policy: policy,
      );

      expect(result.status, WorkOrderStatus.pendingApproval);
      expect(result.varianceReason, isNotNull);
      expect(result.completedAt, isNotNull);
    });

    test('refuses to complete without the shop invoice', () async {
      final useCase = CompleteWorkOrderUseCase(repo, transitions);
      final workOrder = testWorkOrder(
        status: WorkOrderStatus.inProgress,
        invoiceUrls: const [],
      );

      await expectLater(
        () => useCase(
          workOrder: workOrder,
          actor: testUser(),
          policy: policy,
        ),
        throwsA(
          isA<StateError>()
              .having((e) => e.message, 'message', contains('invoice')),
        ),
      );
    });
  });

  group('CancelWorkOrderUseCase', () {
    test('releases the vehicle when cancelling mid-job', () async {
      vehicles.store['veh-1'] = testVehicle(status: 'In-Shop');
      final useCase = CancelWorkOrderUseCase(repo, transitions, vehicles);
      final workOrder = testWorkOrder(status: WorkOrderStatus.inProgress);

      final result = await useCase(
        workOrder: workOrder,
        actor: testUser(),
        policy: policy,
        reason: 'Shop could not source the part',
      );

      expect(result.status, WorkOrderStatus.cancelled);
      expect(vehicles.store['veh-1']!.status, 'Active');
    });

    test('cannot cancel a closed work order', () async {
      final useCase = CancelWorkOrderUseCase(repo, transitions, vehicles);
      final workOrder = testWorkOrder(status: WorkOrderStatus.closed);

      await expectLater(
        () => useCase(
          workOrder: workOrder,
          actor: testUser(),
          policy: policy,
          reason: 'Changed my mind',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('requires a reason', () async {
      final useCase = CancelWorkOrderUseCase(repo, transitions, vehicles);
      final workOrder = testWorkOrder(status: WorkOrderStatus.approved);

      await expectLater(
        () => useCase(
          workOrder: workOrder,
          actor: testUser(),
          policy: policy,
          reason: '   ',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('audit trail', () {
    test('every transition appends a timeline entry', () async {
      final workOrder = testWorkOrder(status: WorkOrderStatus.approved);

      final started = await StartWorkOrderUseCase(repo, transitions, vehicles)(
        workOrder: workOrder,
        actor: testUser(name: 'Coordinator A'),
        policy: policy,
      );
      expect(started.timeline.last.action, 'started');
      expect(started.timeline.last.actor, contains('Coordinator A'));

      final held = await HoldWorkOrderUseCase(repo, transitions)(
        workOrder: started,
        actor: testUser(),
        policy: policy,
        reason: 'Waiting for parts',
      );
      expect(held.timeline.last.action, 'held');
      expect(held.timeline.last.note, 'Waiting for parts');

      final resumed = await ResumeWorkOrderUseCase(repo, transitions)(
        workOrder: held,
        actor: testUser(),
        policy: policy,
      );
      expect(resumed.timeline.last.action, 'resumed');
      expect(resumed.timeline.length, greaterThan(started.timeline.length));
    });
  });
}
