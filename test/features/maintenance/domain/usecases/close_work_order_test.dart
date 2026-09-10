import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/features/finance/domain/entities/expense_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/finance_policy_entity.dart';
import 'package:xloop_invoice/features/maintenance/domain/entities/work_order_status.dart';
import 'package:xloop_invoice/features/maintenance/domain/services/work_order_transition_service.dart';
import 'package:xloop_invoice/features/maintenance/domain/usecases/close_work_order_usecase.dart';
import 'package:xloop_invoice/features/vehicle/domain/services/maintenance_history_writer.dart';

import '../../../finance/domain/usecases/test_finance_repository.dart';
import 'test_work_order_fakes.dart';

void main() {
  late FakeWorkOrderRepository workOrders;
  late FakeVehicleRepository vehicles;
  late FakeFinanceRepository finance;
  late CloseWorkOrderUseCase useCase;

  const policy = FinancePolicyEntity();

  setUp(() {
    workOrders = FakeWorkOrderRepository();
    vehicles = FakeVehicleRepository();
    finance = FakeFinanceRepository();
    useCase = CloseWorkOrderUseCase(
      repository: workOrders,
      financeRepository: finance,
      vehicleRepository: vehicles,
      historyWriter: const MaintenanceHistoryWriter(),
      transitions: const WorkOrderTransitionService(),
    );
    vehicles.store['veh-1'] = testVehicle(status: 'In-Shop');
  });

  group('CloseWorkOrderUseCase', () {
    test('creates an expense and closes the work order', () async {
      final workOrder = testWorkOrder();
      workOrders.store[workOrder.id] = workOrder;

      final result = await useCase(
        workOrder: workOrder,
        actor: testUser(),
        policy: policy,
      );

      expect(result.workOrder.status, WorkOrderStatus.closed);
      expect(result.workOrder.expenseId, 'wo_WO-2026-0001');
      expect(result.expense.amount, 380);
      expect(result.expense.expenseCategory, 'VEHICLES');
      expect(result.expense.expenseType, 'Maintenance');
      expect(result.expense.vehicleId, 'veh-1');
      expect(result.expense.workOrderNumber, 'WO-2026-0001');
      expect(result.expense.receiptUrls, isNotEmpty);
    });

    test('derives a deterministic expense id from the work order number',
        () async {
      final workOrder = testWorkOrder(id: 'WO-2026-0042');
      workOrders.store[workOrder.id] = workOrder;

      final result = await useCase(
        workOrder: workOrder,
        actor: testUser(),
        policy: policy,
      );

      // Deterministic so a retry after a mid-way crash overwrites the same
      // document instead of posting the spend a second time.
      expect(result.expense.id, 'wo_WO-2026-0042');
    });

    test('refuses to close a work order that already carries an expense',
        () async {
      final workOrder = testWorkOrder(expenseId: 'wo_WO-2026-0001');
      workOrders.store[workOrder.id] = workOrder;

      await expectLater(
        () => useCase(
          workOrder: workOrder,
          actor: testUser(),
          policy: policy,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('re-reads the work order, so a stale in-memory copy cannot double-post',
        () async {
      final stale = testWorkOrder();
      // Someone else closed it after this copy was loaded.
      workOrders.store[stale.id] = stale.copyWith(
        status: WorkOrderStatus.closed,
        expenseId: 'wo_WO-2026-0001',
      );

      await expectLater(
        () => useCase(
          workOrder: stale,
          actor: testUser(),
          policy: policy,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('refuses when the actual overran the approval beyond tolerance',
        () async {
      final workOrder = testWorkOrder(
        approvedAmount: 400,
        lines: [testLine(estimate: 400, actual: 900)],
      );
      workOrders.store[workOrder.id] = workOrder;

      await expectLater(
        () => useCase(
          workOrder: workOrder,
          actor: testUser(),
          policy: policy,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('re-approval'),
          ),
        ),
      );
    });

    test('allows an overrun inside the tolerance band', () async {
      // 10% default tolerance: 400 approved allows up to 440.
      final workOrder = testWorkOrder(
        approvedAmount: 400,
        lines: [testLine(estimate: 400, actual: 430)],
      );
      workOrders.store[workOrder.id] = workOrder;

      final result = await useCase(
        workOrder: workOrder,
        actor: testUser(),
        policy: policy,
      );

      expect(result.workOrder.status, WorkOrderStatus.closed);
      expect(result.expense.amount, 430);
      // Over the approved amount, so the payment still needs a human.
      expect(result.expense.status, ExpenseStatus.pending);
      expect(result.expenseAutoApproved, isFalse);
    });

    test('creates the expense pre-approved when inside the approved amount',
        () async {
      final workOrder = testWorkOrder(
        approvedAmount: 400,
        lines: [testLine(estimate: 400, actual: 380)],
      );
      workOrders.store[workOrder.id] = workOrder;

      final result = await useCase(
        workOrder: workOrder,
        actor: testUser(),
        policy: policy,
      );

      expect(result.expense.status, ExpenseStatus.approved);
      expect(result.expenseAutoApproved, isTrue);
    });

    test('respects autoApproveExpenseWithinEstimate = false', () async {
      final workOrder = testWorkOrder(
        approvedAmount: 400,
        lines: [testLine(estimate: 400, actual: 380)],
      );
      workOrders.store[workOrder.id] = workOrder;

      final result = await useCase(
        workOrder: workOrder,
        actor: testUser(),
        policy: const FinancePolicyEntity(
          autoApproveExpenseWithinEstimate: false,
        ),
      );

      expect(result.expense.status, ExpenseStatus.pending);
    });

    test('writes one maintenance record per completed line', () async {
      final workOrder = testWorkOrder(
        approvedAmount: 900,
        lines: [
          testLine(id: 'l1', typeId: 'engine_oil', typeName: 'Engine Oil',
              estimate: 400, actual: 400),
          testLine(id: 'l2', typeId: 'air_filter', typeName: 'Air Filter',
              estimate: 200, actual: 200),
          testLine(id: 'l3', typeId: 'brake_pads', typeName: 'Brake Pads',
              estimate: 300, actual: 300, completed: false),
        ],
      );
      workOrders.store[workOrder.id] = workOrder;

      final result = await useCase(
        workOrder: workOrder,
        actor: testUser(),
        policy: policy,
      );

      expect(result.historyRecordsWritten, 2);

      final vehicle = vehicles.store['veh-1']!;
      final history = vehicle.maintenanceHistory ?? [];
      expect(history.length, 2);
      expect(
        history.map((r) => r.serviceType),
        containsAll(['Engine Oil', 'Air Filter']),
      );
      // Each record carries the work order for traceability both ways.
      expect(history.every((r) => r.sourceWorkOrderId == workOrder.id), isTrue);
      expect(history.every((r) => r.mileage == 52000), isTrue);

      // Typed slots drive the alert engine's interval reset.
      expect(vehicle.maintenance?.engineOil, isNotNull);
      expect(vehicle.maintenance?.airFilter, isNotNull);
      expect(vehicle.maintenance?.brakePads, isNull);
    });

    test('returns the vehicle to its pre-workshop status', () async {
      vehicles.store['veh-1'] = testVehicle(status: 'In-Shop');
      final workOrder = testWorkOrder(vehicleStatusBefore: 'Active');
      workOrders.store[workOrder.id] = workOrder;

      await useCase(
        workOrder: workOrder,
        actor: testUser(),
        policy: policy,
      );

      expect(vehicles.store['veh-1']!.status, 'Active');
    });

    test('advances the odometer when the service reading is higher', () async {
      vehicles.store['veh-1'] = testVehicle(status: 'In-Shop', odometer: 50000);
      final workOrder = testWorkOrder();
      workOrders.store[workOrder.id] = workOrder;

      await useCase(
        workOrder: workOrder,
        actor: testUser(),
        policy: policy,
      );

      expect(vehicles.store['veh-1']!.currentOdometer, 52000);
    });

    test('refuses a work order that is not completed', () async {
      final workOrder = testWorkOrder(status: WorkOrderStatus.inProgress);
      workOrders.store[workOrder.id] = workOrder;

      await expectLater(
        () => useCase(
          workOrder: workOrder,
          actor: testUser(),
          policy: policy,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('refuses when no wallet was chosen', () async {
      final workOrder = testWorkOrder(fundAccountId: null);
      workOrders.store[workOrder.id] = workOrder;

      await expectLater(
        () => useCase(
          workOrder: workOrder,
          actor: testUser(),
          policy: policy,
        ),
        throwsA(
          isA<StateError>()
              .having((e) => e.message, 'message', contains('wallet')),
        ),
      );
    });

    test('refuses a driver-advance work order rather than double-counting',
        () async {
      final workOrder = testWorkOrder(paidFromDriverAdvance: true);
      workOrders.store[workOrder.id] = workOrder;

      await expectLater(
        () => useCase(
          workOrder: workOrder,
          actor: testUser(),
          policy: policy,
        ),
        throwsA(
          isA<StateError>()
              .having((e) => e.message, 'message', contains('advance')),
        ),
      );
    });

    test('adopts an already-posted expense instead of overwriting it',
        () async {
      final workOrder = testWorkOrder();
      workOrders.store[workOrder.id] = workOrder;
      // A previous attempt created and paid the expense but never stamped
      // the work order.
      finance.expensesById['wo_WO-2026-0001'] = ExpenseEntity(
        id: 'wo_WO-2026-0001',
        referenceNumber: '#10005',
        date: DateTime(2026, 1, 12),
        createdAt: DateTime(2026, 1, 12),
        submittedBy: 'Coordinator A',
        submittedByRole: 'coordinator',
        expenseCategory: 'VEHICLES',
        expenseType: 'Maintenance',
        amount: 380,
        currency: 'SAR',
        fundAccountId: 'acc-1',
        status: ExpenseStatus.paid,
      );

      final result = await useCase(
        workOrder: workOrder,
        actor: testUser(),
        policy: policy,
      );

      expect(result.workOrder.status, WorkOrderStatus.closed);
      expect(result.expense.referenceNumber, '#10005');
      expect(result.expense.status, ExpenseStatus.paid);
    });
  });
}
