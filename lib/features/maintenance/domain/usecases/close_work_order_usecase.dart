import 'package:xloop_invoice/features/auth/domain/entities/user_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/expense_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/finance_policy_entity.dart';
import 'package:xloop_invoice/features/finance/domain/repositories/finance_repository.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_documents.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_status.dart';
import 'package:xloop_invoice/features/vehicle/domain/repositories/vehicle_repository.dart';
import 'package:xloop_invoice/features/vehicle/domain/services/maintenance_history_writer.dart';

import '../entities/work_order_entity.dart';
import '../entities/work_order_event.dart';
import '../entities/work_order_status.dart';
import '../repositories/work_order_repository.dart';
import '../services/work_order_transition_service.dart';

/// What closing a work order produced, for the confirmation UI.
class CloseWorkOrderResult {
  final WorkOrderEntity workOrder;
  final ExpenseEntity expense;

  /// Number of maintenance records written back to the vehicle.
  final int historyRecordsWritten;

  /// True when the expense was created already approved because the actual
  /// cost stayed inside what was authorised.
  final bool expenseAutoApproved;

  const CloseWorkOrderResult({
    required this.workOrder,
    required this.expense,
    required this.historyRecordsWritten,
    required this.expenseAutoApproved,
  });
}

/// `completed` → `closed`: the point where a maintenance job becomes money.
///
/// This is the step the old flow was missing entirely — `MaintenanceRecord`
/// held a `cost` that never reached finance. Here the cost becomes a real
/// [ExpenseEntity], which then goes through the existing
/// `approveAndPostExpense` for all wallet math (day locks, petty-cash session
/// checks, cash/STC buckets, the `fund_transactions` ledger). No parallel
/// money path is invented.
///
/// Order of operations matters, because Firestore gives us no cross-collection
/// transaction here:
///
/// 1. Re-read the work order and refuse if it already carries an expense id.
/// 2. Create the expense under a **deterministic** document id derived from
///    the work order number, so even a retry after a mid-way crash overwrites
///    the same document instead of posting the spend twice.
/// 3. Write maintenance history back to the vehicle and release it from the
///    workshop.
/// 4. Stamp the work order closed.
class CloseWorkOrderUseCase {
  final WorkOrderRepository repository;
  final FinanceRepository financeRepository;
  final VehicleRepository vehicleRepository;
  final MaintenanceHistoryWriter historyWriter;
  final WorkOrderTransitionService transitions;

  CloseWorkOrderUseCase({
    required this.repository,
    required this.financeRepository,
    required this.vehicleRepository,
    required this.historyWriter,
    required this.transitions,
  });

  Future<CloseWorkOrderResult> call({
    required WorkOrderEntity workOrder,
    required UserEntity actor,
    required FinancePolicyEntity policy,
  }) async {
    // ── 1. Guard against double-posting, on fresh data ──────────
    final fresh = await repository.getWorkOrderById(workOrder.id) ?? workOrder;

    if (fresh.isPosted) {
      throw StateError(
        'Work order ${fresh.workOrderNumber} is already closed — expense '
        '${fresh.expenseReferenceNumber ?? fresh.expenseId} was posted on '
        '${_formatDate(fresh.closedAt)}.',
      );
    }
    if (fresh.status != WorkOrderStatus.completed) {
      throw StateError(
        'Only a completed work order can be closed. '
        '${fresh.workOrderNumber} is ${fresh.status.displayName.toLowerCase()}.',
      );
    }
    final blocker = transitions.blockerFor(
      action: WorkOrderAction.close,
      workOrder: fresh,
      policy: policy,
    );
    if (blocker != null) throw StateError(blocker);

    if (fresh.paidFromDriverAdvance) {
      // Creating a fresh expense here would double-count spend that already
      // left the fund when the advance was issued. Settling the advance is
      // the correct path and is not wired up yet, so refuse rather than post
      // something wrong.
      throw StateError(
        'This work order is marked as paid from a driver cash advance. '
        'Settle the advance in Finance → Advances instead of closing here.',
      );
    }

    final completedLines = fresh.lines.where((l) => l.completed).toList();
    final actualTotal = fresh.actualTotal;
    final expenseId = 'wo_${fresh.workOrderNumber}';

    // ── 2. Create (or re-create) the expense ────────────────────
    final existingExpense = await financeRepository.getExpenseById(expenseId);
    if (existingExpense != null && existingExpense.status.isPosted) {
      // The expense made it through on a previous attempt but the work order
      // was never stamped. Adopt it rather than overwriting a paid record.
      final adopted = await _finalise(
        workOrder: fresh,
        actor: actor,
        expense: existingExpense,
        completedLineCount: completedLines.length,
        writeHistory: true,
      );
      return CloseWorkOrderResult(
        workOrder: adopted,
        expense: existingExpense,
        historyRecordsWritten: completedLines.length,
        expenseAutoApproved: true,
      );
    }

    final approvedAmount = fresh.approvedAmount;
    final withinEstimate = approvedAmount == null ||
        actualTotal <= approvedAmount + 1e-9;
    final autoApprove =
        policy.autoApproveExpenseWithinEstimate && withinEstimate;

    final referenceNumber = existingExpense?.referenceNumber ??
        await financeRepository.generateReferenceNumber();
    final now = DateTime.now();

    final expense = ExpenseEntity(
      id: expenseId,
      referenceNumber: referenceNumber,
      date: fresh.completedAt ?? now,
      createdAt: now,
      submittedBy: actor.actorLabel,
      submittedByRole: actor.roleId,
      submittedByUserId: actor.id,
      expenseCategory: 'VEHICLES',
      expenseType: 'Maintenance',
      description: _buildDescription(fresh),
      paymentDetails: fresh.shopInvoiceNumber != null
          ? 'Shop invoice ${fresh.shopInvoiceNumber}'
          : null,
      paymentMethod: fresh.paymentMethod,
      amount: actualTotal,
      amountMinor: (actualTotal * 100).round(),
      currency: fresh.currency,
      fundAccountId: fresh.fundAccountId ?? '',
      fundAccountName: fresh.fundAccountName,
      // Approved here means "the spend was authorised on the work order";
      // the payment itself is still posted by approveAndPostExpense.
      status: autoApprove ? ExpenseStatus.approved : ExpenseStatus.pending,
      approvedBy: autoApprove ? fresh.approvedBy : null,
      approvedByUserId: autoApprove ? fresh.approvedByUserId : null,
      approvedAt: autoApprove ? fresh.approvedAt : null,
      vehicleId: fresh.vehicleId,
      vehicleName: '${fresh.vehiclePlate} · ${fresh.vehicleName ?? ''}'.trim(),
      mileageKm: (fresh.odometerAtService ?? fresh.odometerAtRequest)
          ?.toDouble(),
      receiptUrls: fresh.invoiceUrls,
      workOrderId: fresh.id,
      workOrderNumber: fresh.workOrderNumber,
      notes: _buildExpenseNotes(fresh, autoApprove),
    );

    await financeRepository.insertExpense(expense);

    // ── 3 & 4. History write-back, vehicle release, stamp ───────
    final closed = await _finalise(
      workOrder: fresh,
      actor: actor,
      expense: expense,
      completedLineCount: completedLines.length,
      writeHistory: true,
    );

    return CloseWorkOrderResult(
      workOrder: closed,
      expense: expense,
      historyRecordsWritten: completedLines.length,
      expenseAutoApproved: autoApprove,
    );
  }

  /// Writes maintenance history, releases the vehicle, and stamps the work
  /// order closed. Split out so the "adopt an orphaned expense" path reuses
  /// exactly the same finishing steps.
  Future<WorkOrderEntity> _finalise({
    required WorkOrderEntity workOrder,
    required UserEntity actor,
    required ExpenseEntity expense,
    required int completedLineCount,
    required bool writeHistory,
  }) async {
    if (writeHistory) {
      await _writeHistoryAndReleaseVehicle(workOrder, actor);
    }

    final closed = workOrder
        .copyWith(
          status: WorkOrderStatus.closed,
          closedAt: DateTime.now(),
          closedBy: actor.actorLabel,
          expenseId: expense.id,
          expenseReferenceNumber: expense.referenceNumber,
          updatedAt: DateTime.now(),
        )
        .withEvent(
          WorkOrderEvent(
            at: DateTime.now(),
            actor: actor.actorLabel,
            actorUserId: actor.id,
            actorRole: actor.roleId,
            action: 'closed',
            fromStatus: workOrder.status,
            toStatus: WorkOrderStatus.closed,
            note: 'Expense ${expense.referenceNumber} for '
                '${expense.amount.toStringAsFixed(2)} ${expense.currency}; '
                '$completedLineCount maintenance record'
                '${completedLineCount == 1 ? '' : 's'} written to vehicle '
                'history',
          ),
        );

    await repository.updateWorkOrder(closed);
    return closed;
  }

  Future<void> _writeHistoryAndReleaseVehicle(
    WorkOrderEntity workOrder,
    UserEntity actor,
  ) async {
    // Fresh read: maintenance history is a nested array, so working from a
    // cached vehicle would drop anything written since the list was loaded.
    final vehicle = await vehicleRepository.getVehicleById(workOrder.vehicleId);
    if (vehicle == null) return;

    final serviceDate = workOrder.completedAt ?? DateTime.now();
    final serviceOdometer = workOrder.odometerAtService ??
        workOrder.odometerAtRequest ??
        vehicle.currentOdometer ??
        0;

    // One record per completed line — the alert engine groups history by
    // service type, so a single combined record would reset only one interval.
    final records = <TypedMaintenanceRecord>[
      for (final line in workOrder.lines.where((l) => l.completed))
        (
          typeId: line.maintenanceTypeId,
          record: MaintenanceRecord(
            date: serviceDate,
            mileage: serviceOdometer,
            cost: line.effectiveCost,
            partsCost: line.partsCost,
            laborCost: line.laborCost,
            serviceProvider: workOrder.shopName ?? '',
            workOrderNumber: workOrder.workOrderNumber,
            sourceWorkOrderId: workOrder.id,
            serviceType: line.effectiveTypeName,
            partsReplaced: line.partsReplaced,
            notes: line.notes,
            nextServiceDate: line.followUpDate ?? line.targetDueDate,
            nextServiceMileage: line.followUpKm,
            notificationDays: line.notificationDays,
            isFollowUpRequired: line.followUpRequired,
            followUpReason: line.followUpReason,
            isFollowUpCompleted: line.followUpRequired ? false : null,
            followUpCompletions: line.followUpRequired ? const [] : null,
            performedBy: actor.actorLabel,
          ),
        ),
    ];

    var updated = historyWriter.applyRecords(vehicle, records);

    // Put the vehicle back exactly as it was before the workshop took it.
    if (VehicleStatus.isInShop(updated.status)) {
      updated = updated.copyWith(
        status: workOrder.vehicleStatusBefore ?? VehicleStatus.active,
      );
    }

    // A service reading higher than the recorded odometer is newer
    // information; the odometer-triggered alerts measure from this value.
    if (serviceOdometer > (updated.currentOdometer ?? 0)) {
      updated = updated.copyWith(
        currentOdometer: serviceOdometer,
        lastOdometerUpdateDate: serviceDate,
      );
    }

    await vehicleRepository.updateVehicle(updated);
  }

  String _buildDescription(WorkOrderEntity workOrder) {
    final parts = <String>[
      workOrder.workOrderNumber,
      workOrder.lineSummary,
    ];
    final shop = workOrder.shopName?.trim();
    if (shop != null && shop.isNotEmpty) parts.add('at $shop');
    return parts.join(' · ');
  }

  String _buildExpenseNotes(WorkOrderEntity workOrder, bool autoApproved) {
    final lines = <String>[
      'Vehicle: ${workOrder.vehiclePlate}',
      'Complaint: ${workOrder.complaint}',
    ];
    for (final line in workOrder.lines.where((l) => l.completed)) {
      lines.add(
        '- ${line.effectiveTypeName}: '
        '${line.effectiveCost.toStringAsFixed(2)} '
        '(est. ${line.estimatedCost.toStringAsFixed(2)})',
      );
    }
    if (autoApproved) {
      lines.add(
        'Auto-approved: within the ${workOrder.approvedAmount?.toStringAsFixed(2)} '
        'authorised on the work order.',
      );
    }
    return lines.join('\n');
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'an earlier date';
    return '${date.day}/${date.month}/${date.year}';
  }
}
