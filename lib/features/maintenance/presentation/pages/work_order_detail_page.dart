import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:xloop_invoice/core/utils/activity_logger.dart';
import 'package:xloop_invoice/core/utils/app_snack_bar.dart';
import 'package:xloop_invoice/core/widgets/modern_app_bar.dart';
import 'package:xloop_invoice/features/auth/presentation/providers/auth_provider.dart';
import 'package:xloop_invoice/features/finance/presentation/providers/finance_provider.dart';
import 'package:xloop_invoice/features/vehicle/presentation/providers/vehicle_provider.dart';

import '../../domain/entities/work_order_entity.dart';
import '../../domain/entities/work_order_event.dart';
import '../../domain/entities/work_order_line.dart';
import '../../domain/entities/work_order_status.dart';
import '../../domain/services/work_order_transition_service.dart';
import '../providers/work_order_provider.dart';
import '../widgets/work_order_status_badge.dart';
import 'work_order_form_page.dart';

/// The full story of one work order, plus the single action that moves it on.
///
/// The action bar shows only the one legal next step for the current user;
/// everything else lives behind the overflow menu. That is the difference
/// between a screen people use and a screen with nine buttons on it.
class WorkOrderDetailPage extends StatefulWidget {
  final String workOrderId;

  const WorkOrderDetailPage({super.key, required this.workOrderId});

  @override
  State<WorkOrderDetailPage> createState() => _WorkOrderDetailPageState();
}

class _WorkOrderDetailPageState extends State<WorkOrderDetailPage> {
  WorkOrderEntity? _workOrder;
  bool _isLoading = true;

  final _money = NumberFormat.currency(symbol: '', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final provider = context.read<WorkOrderProvider>();
    final fresh = await provider.refreshOne(widget.workOrderId);
    if (!mounted) return;
    setState(() {
      _workOrder = fresh;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final workOrder = _workOrder;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (workOrder == null) {
      return Scaffold(
        appBar: const ModernAppBar(title: 'Work Order'),
        body: Center(
          child: Text(
            'This work order no longer exists.',
            style: GoogleFonts.inter(fontSize: 13.sp),
          ),
        ),
      );
    }

    final user = context.watch<AuthProvider>().user;
    final policy = context.watch<FinanceProvider>().policy;
    const transitions = WorkOrderTransitionService();
    final actions = transitions.availableActions(
      workOrder: workOrder,
      user: user,
      policy: policy,
    );
    final primary = transitions.primaryAction(
      workOrder: workOrder,
      user: user,
      policy: policy,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: ModernAppBar(
        title: workOrder.workOrderNumber,
        actions: [
          if (actions.where((a) => a != primary).isNotEmpty)
            PopupMenuButton<WorkOrderAction>(
              icon: const Icon(Icons.more_vert, color: Colors.black54),
              onSelected: (action) => _perform(action, workOrder),
              itemBuilder: (_) => actions
                  .where((a) => a != primary)
                  .map(
                    (a) => PopupMenuItem(
                      value: a,
                      child: Text(
                        a.label,
                        style: GoogleFonts.inter(fontSize: 13.sp),
                      ),
                    ),
                  )
                  .toList(),
            ),
          SizedBox(width: 6.w),
        ],
      ),
      bottomNavigationBar:
          primary == null ? null : _buildActionBar(primary, workOrder, policy),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
          children: [
            _buildHeader(workOrder),
            SizedBox(height: 14.h),
            if (workOrder.varianceReason != null) ...[
              _buildBanner(
                icon: Icons.trending_up_rounded,
                color: const Color(0xFFDC2626),
                title: 'Cost overran the approval',
                body: workOrder.varianceReason!,
              ),
              SizedBox(height: 14.h),
            ],
            if (workOrder.rejectionReason != null) ...[
              _buildBanner(
                icon: Icons.block_rounded,
                color: const Color(0xFFDC2626),
                title: 'Rejected',
                body: workOrder.rejectionReason!,
              ),
              SizedBox(height: 14.h),
            ],
            if (workOrder.holdReason != null &&
                workOrder.status == WorkOrderStatus.onHold) ...[
              _buildBanner(
                icon: Icons.pause_circle_outline,
                color: const Color(0xFFEA580C),
                title: 'On hold',
                body: workOrder.holdReason!,
              ),
              SizedBox(height: 14.h),
            ],
            if (workOrder.isPosted) ...[
              _buildBanner(
                icon: Icons.check_circle_outline,
                color: const Color(0xFF16A34A),
                title: 'Expense posted',
                body:
                    '${workOrder.expenseReferenceNumber ?? workOrder.expenseId} '
                    'for ${_money.format(workOrder.actualTotal)} '
                    '${workOrder.currency} · '
                    '${workOrder.fundAccountName ?? 'wallet'}. Find it in '
                    'Finance → Expenses.',
              ),
              SizedBox(height: 14.h),
            ],
            _buildComplaint(workOrder),
            SizedBox(height: 14.h),
            _buildLines(workOrder),
            SizedBox(height: 14.h),
            _buildLogistics(workOrder),
            SizedBox(height: 14.h),
            _buildTimeline(workOrder),
          ],
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────

  Widget _buildHeader(WorkOrderEntity workOrder) {
    final isActual = workOrder.status == WorkOrderStatus.completed ||
        workOrder.status == WorkOrderStatus.closed;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workOrder.vehiclePlate,
                      style: GoogleFonts.inter(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    if (workOrder.vehicleName != null)
                      Text(
                        workOrder.vehicleName!,
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  WorkOrderStatusBadge(status: workOrder.status),
                  SizedBox(height: 6.h),
                  WorkOrderPriorityFlag(priority: workOrder.priority),
                ],
              ),
            ],
          ),
          Divider(height: 24.h),
          Row(
            children: [
              _metric(
                isActual ? 'Actual' : 'Estimate',
                '${_money.format(workOrder.displayTotal)} ${workOrder.currency}',
                color: workOrder.hasOverrun ? const Color(0xFFDC2626) : null,
              ),
              if (workOrder.approvedAmount != null)
                _metric(
                  'Approved',
                  _money.format(workOrder.approvedAmount!),
                ),
              _metric(
                'Odometer',
                workOrder.odometerAtService != null
                    ? '${workOrder.odometerAtService} km'
                    : (workOrder.odometerAtRequest != null
                        ? '${workOrder.odometerAtRequest} km'
                        : '—'),
              ),
              _metric('Age', '${workOrder.ageInDays} d'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, {Color? color}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10.sp,
              color: const Color(0xFF9CA3AF),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: color ?? const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
  }) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18.sp, color: color),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  body,
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: const Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Sections ────────────────────────────────────────────────

  Widget _card(String title, List<Widget> children, {Widget? trailing}) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing,
            ],
          ),
          SizedBox(height: 12.h),
          ...children,
        ],
      ),
    );
  }

  Widget _buildComplaint(WorkOrderEntity workOrder) {
    return _card('Reported problem', [
      Text(
        workOrder.complaint,
        style: GoogleFonts.inter(fontSize: 13.sp, color: const Color(0xFF374151)),
      ),
      SizedBox(height: 10.h),
      Text(
        'Reported by ${workOrder.reportedBy ?? workOrder.createdBy}'
        '${workOrder.reportedAt != null ? ' · ${DateFormat('MMM dd, yyyy').format(workOrder.reportedAt!)}' : ''}'
        ' · ${workOrder.source.displayName}',
        style: GoogleFonts.inter(
          fontSize: 11.sp,
          color: const Color(0xFF9CA3AF),
        ),
      ),
      if (workOrder.reportedAttachmentUrls.isNotEmpty) ...[
        SizedBox(height: 10.h),
        _attachmentStrip(workOrder.reportedAttachmentUrls),
      ],
    ]);
  }

  Widget _buildLines(WorkOrderEntity workOrder) {
    return _card(
      'Items',
      [
        for (final line in workOrder.lines) _lineRow(line, workOrder),
        if (workOrder.lines.isEmpty)
          Text(
            'No items costed yet.',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              color: const Color(0xFF9CA3AF),
            ),
          ),
      ],
    );
  }

  Widget _lineRow(WorkOrderLine line, WorkOrderEntity workOrder) {
    final showActual = line.actualCost != null;
    final over = line.actualCost != null && line.variance > 0;
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          Icon(
            line.completed
                ? Icons.check_circle_outline
                : Icons.radio_button_unchecked,
            size: 16.sp,
            color: line.completed
                ? const Color(0xFF16A34A)
                : const Color(0xFFD1D5DB),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.effectiveTypeName,
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827),
                  ),
                ),
                if (line.partsReplaced != null &&
                    line.partsReplaced!.isNotEmpty)
                  Text(
                    line.partsReplaced!,
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _money.format(line.effectiveCost),
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: over
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF111827),
                ),
              ),
              if (showActual && line.estimatedCost > 0)
                Text(
                  'est. ${_money.format(line.estimatedCost)}',
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogistics(WorkOrderEntity workOrder) {
    return _card(
      'Workshop & payment',
      [
        _kv('Workshop', workOrder.shopName ?? 'Not chosen'),
        _kv(
          'Scheduled',
          workOrder.scheduledDate != null
              ? DateFormat('MMM dd, yyyy').format(workOrder.scheduledDate!)
              : 'Not scheduled',
        ),
        _kv('Wallet', workOrder.fundAccountName ?? 'Not chosen'),
        _kv(
          'Method',
          workOrder.paymentMethod == 'stcPay' ? 'STC Pay' : 'Cash',
        ),
        if (workOrder.shopInvoiceNumber != null)
          _kv('Shop invoice', workOrder.shopInvoiceNumber!),
        if (workOrder.invoiceUrls.isNotEmpty) ...[
          SizedBox(height: 8.h),
          _attachmentStrip(workOrder.invoiceUrls),
        ],
        if (!workOrder.status.isTerminal) ...[
          SizedBox(height: 10.h),
          OutlinedButton.icon(
            onPressed: () => _attachInvoice(workOrder),
            icon: Icon(Icons.attach_file, size: 15.sp),
            label: Text(
              'Attach shop invoice',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110.w,
            child: Text(
              key,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: const Color(0xFF9CA3AF),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _attachmentStrip(List<String> urls) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        for (int i = 0; i < urls.length; i++)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(6.r),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.insert_drive_file_outlined,
                  size: 13.sp,
                  color: const Color(0xFF6B7280),
                ),
                SizedBox(width: 5.w),
                Text(
                  'File ${i + 1}',
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    color: const Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// The accountability chain, top to bottom.
  Widget _buildTimeline(WorkOrderEntity workOrder) {
    final events = workOrder.timeline;
    return _card(
      'History',
      [
        for (int i = 0; i < events.length; i++)
          _timelineRow(events[i], isLast: i == events.length - 1),
        if (events.isEmpty)
          Text(
            'Nothing recorded yet.',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              color: const Color(0xFF9CA3AF),
            ),
          ),
      ],
    );
  }

  Widget _timelineRow(WorkOrderEvent event, {required bool isLast}) {
    final color = event.toStatus != null
        ? WorkOrderStatusBadge.configFor(event.toStatus!).dot
        : const Color(0xFF9CA3AF);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 10.w,
                height: 10.w,
                margin: EdgeInsets.only(top: 4.h),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    color: const Color(0xFFE5E7EB),
                    margin: EdgeInsets.symmetric(vertical: 3.h),
                  ),
                ),
            ],
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.headline,
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  Text(
                    DateFormat('MMM dd, yyyy · HH:mm').format(event.at),
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                  if (event.note != null && event.note!.isNotEmpty) ...[
                    SizedBox(height: 3.h),
                    Text(
                      event.note!,
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Actions ─────────────────────────────────────────────────

  Widget _buildActionBar(
    WorkOrderAction primary,
    WorkOrderEntity workOrder,
    dynamic policy,
  ) {
    const transitions = WorkOrderTransitionService();
    final blocker = transitions.blockerFor(
      action: primary,
      workOrder: workOrder,
      policy: policy,
    );
    final isSubmitting = context.watch<WorkOrderProvider>().isSubmitting;

    return SafeArea(
      child: Container(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (blocker != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14.sp,
                    color: const Color(0xFFD97706),
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      blocker,
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (blocker != null || isSubmitting)
                    ? null
                    : () => _perform(primary, workOrder),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary == WorkOrderAction.close
                      ? const Color(0xFF16A34A)
                      : const Color(0xFF2563EB),
                  padding: EdgeInsets.symmetric(vertical: 15.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: isSubmitting
                    ? SizedBox(
                        width: 18.w,
                        height: 18.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        primary.shortLabel,
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _perform(
    WorkOrderAction action,
    WorkOrderEntity workOrder,
  ) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    final provider = context.read<WorkOrderProvider>();
    final policy = context.read<FinanceProvider>().policy;

    String? reason;
    if (action.requiresReason) {
      reason = await _askForReason(action);
      if (reason == null) return;
    }

    if (action == WorkOrderAction.close) {
      final confirmed = await _confirmClose(workOrder);
      if (confirmed != true) return;
    }

    if (!mounted) return;

    WorkOrderEntity? result;
    String successMessage = '';

    switch (action) {
      case WorkOrderAction.edit:
        final navigator = Navigator.of(context);
        final changed = await navigator.push<bool>(
          MaterialPageRoute(
            builder: (_) => WorkOrderFormPage(workOrder: workOrder),
          ),
        );
        if (changed == true) await _load();
        return;

      case WorkOrderAction.issue:
      case WorkOrderAction.reissue:
        result = await provider.issue(
          workOrder: workOrder,
          actor: user,
          policy: policy,
        );
        successMessage = result?.status == WorkOrderStatus.approved
            ? 'Auto-approved — ready to start.'
            : 'Sent for approval.';
        break;

      case WorkOrderAction.approve:
        result = await provider.approve(
          workOrder: workOrder,
          actor: user,
          policy: policy,
        );
        successMessage = 'Approved.';
        break;

      case WorkOrderAction.reject:
        result = await provider.reject(
          workOrder: workOrder,
          actor: user,
          policy: policy,
          reason: reason!,
        );
        successMessage = 'Rejected.';
        break;

      case WorkOrderAction.start:
        result = await provider.start(
          workOrder: workOrder,
          actor: user,
          policy: policy,
        );
        successMessage = 'Work started — vehicle marked In-Shop.';
        break;

      case WorkOrderAction.hold:
        result = await provider.hold(
          workOrder: workOrder,
          actor: user,
          policy: policy,
          reason: reason!,
        );
        successMessage = 'Put on hold.';
        break;

      case WorkOrderAction.resume:
        result = await provider.resume(
          workOrder: workOrder,
          actor: user,
          policy: policy,
        );
        successMessage = 'Resumed.';
        break;

      case WorkOrderAction.complete:
        result = await provider.complete(
          workOrder: workOrder,
          actor: user,
          policy: policy,
        );
        successMessage = result?.status == WorkOrderStatus.pendingApproval
            ? 'Cost overran the approval — sent back for re-approval.'
            : 'Marked completed. Close it to post the expense.';
        break;

      case WorkOrderAction.cancel:
        result = await provider.cancel(
          workOrder: workOrder,
          actor: user,
          policy: policy,
          reason: reason!,
        );
        successMessage = 'Cancelled.';
        break;

      case WorkOrderAction.close:
        final closeResult = await provider.close(
          workOrder: workOrder,
          actor: user,
          policy: policy,
        );
        if (closeResult != null) {
          result = closeResult.workOrder;
          successMessage =
              'Closed. Expense ${closeResult.expense.referenceNumber} created '
              '(${closeResult.expenseAutoApproved ? 'approved' : 'pending approval'}) '
              'and ${closeResult.historyRecordsWritten} maintenance record'
              '${closeResult.historyRecordsWritten == 1 ? '' : 's'} written.';
          if (mounted) {
            // The fleet list reads vehicle.status, which close just changed.
            await context.read<VehicleProvider>().fetchAllVehicles();
          }
        }
        break;
    }

    if (!mounted) return;
    if (result == null) {
      AppSnackBar.showError(
        context,
        provider.error ?? 'That action could not be completed.',
      );
      provider.clearError();
      return;
    }

    setState(() => _workOrder = result);
    AppSnackBar.showSuccess(context, successMessage);

    await ActivityLogger.log(
      context,
      title: 'Work Order ${result.status.displayName}',
      message: '${result.workOrderNumber} · ${result.vehiclePlate} · '
          '${action.label}',
      relatedId: result.id,
    );
  }

  Future<String?> _askForReason(WorkOrderAction action) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          action.label,
          style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: action == WorkOrderAction.hold
                ? 'Why is this paused? e.g. waiting for parts'
                : 'Reason (required)',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(dialogContext, text);
            },
            child: Text(action.label),
          ),
        ],
      ),
    );
    controller.dispose();
    return reason;
  }

  Future<bool?> _confirmClose(WorkOrderEntity workOrder) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Close and post expense?',
          style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This creates an expense of '
              '${_money.format(workOrder.actualTotal)} ${workOrder.currency} '
              'against ${workOrder.fundAccountName ?? 'the selected wallet'}, '
              'writes ${workOrder.lines.where((l) => l.completed).length} '
              'maintenance record(s) to ${workOrder.vehiclePlate}, and returns '
              'the vehicle to service.',
              style: GoogleFonts.inter(fontSize: 13.sp),
            ),
            SizedBox(height: 10.h),
            Text(
              'It cannot be undone from here — a posted expense has to be '
              'voided in Finance.',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: const Color(0xFF92400E),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Close & Post'),
          ),
        ],
      ),
    );
  }

  Future<void> _attachInvoice(WorkOrderEntity workOrder) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;

    final provider = context.read<WorkOrderProvider>();
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final url = await provider.uploadAttachment(
      file: file,
      workOrderId: workOrder.id,
      kind: 'invoice',
    );
    if (!mounted) return;
    if (url == null) {
      AppSnackBar.showError(context, provider.error ?? 'Upload failed.');
      return;
    }

    final updated = await provider.saveDetails(
      workOrder: workOrder.copyWith(
        invoiceUrls: [...workOrder.invoiceUrls, url],
      ),
      actor: user,
      note: 'Shop invoice attached',
    );
    if (!mounted) return;
    if (updated != null) {
      setState(() => _workOrder = updated);
      AppSnackBar.showSuccess(context, 'Invoice attached.');
    }
  }
}
