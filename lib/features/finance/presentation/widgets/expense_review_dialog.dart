import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xloop_invoice/core/utils/app_snack_bar.dart';
import 'package:xloop_invoice/screens/document_viewer_screen.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/expense_entity.dart';
import '../../domain/entities/fund_account_entity.dart';
import '../../domain/services/finance_permission_service.dart';
import '../pages/expense_form_page.dart';
import '../pages/finance_dashboard_page.dart';
import '../providers/finance_provider.dart';
import '../providers/fund_account_provider.dart';
import '../providers/petty_cash_provider.dart';
import 'expense_status_badge.dart';
import 'finance_dialog_helpers.dart';

/// What the reviewer did with the expense.
enum ExpenseReviewOutcome { approved, rejected, editRequested, dismissed }

/// Receipt-first review dialog used by approvers.
///
/// Approval is deliberately gated behind *seeing* the receipt: the document
/// sits next to the figures being approved, and the approve button only
/// unlocks once the reviewer confirms the receipt matches the expense.
///
/// Pass [readOnly] to reuse the same view purely as a receipt viewer.
Future<ExpenseReviewOutcome?> showExpenseReviewDialog({
  required BuildContext context,
  required ExpenseEntity expense,
  required String accountName,
  bool readOnly = false,
}) {
  return showDialog<ExpenseReviewOutcome>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ExpenseReviewDialog(
      expense: expense,
      accountName: accountName,
      readOnly: readOnly,
    ),
  );
}

class _ExpenseReviewDialog extends StatefulWidget {
  final ExpenseEntity expense;
  final String accountName;
  final bool readOnly;

  const _ExpenseReviewDialog({
    required this.expense,
    required this.accountName,
    required this.readOnly,
  });

  @override
  State<_ExpenseReviewDialog> createState() => _ExpenseReviewDialogState();
}

class _ExpenseReviewDialogState extends State<_ExpenseReviewDialog> {
  final _money = NumberFormat('#,##0.00', 'en_US');
  final _reasonController = TextEditingController();

  int _receiptIndex = 0;
  bool _verified = false;
  bool _showRejectReason = false;
  bool _busy = false;

  ExpenseEntity get expense => widget.expense;
  List<String> get _receipts => expense.receiptUrls;
  bool get _hasReceipts => _receipts.isNotEmpty;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  /// Switches the receipt pane to the receipt at [index].
  void showReceipt(int index) {
    if (index < 0 || index >= _receipts.length) return;
    setState(() => _receiptIndex = index);
  }

  // ─── Derived policy state ────────────────────────────────────

  bool get _receiptRequired {
    final threshold = context.read<FinanceProvider>().policy.receiptRequiredAbove;
    return expense.amount >= threshold;
  }

  bool get _blockedOnMissingReceipt => !_hasReceipts && _receiptRequired;

  bool get _canApproveNow =>
      !widget.readOnly &&
      expense.status.canApprove &&
      !_blockedOnMissingReceipt &&
      _verified &&
      !_busy;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dialogWidth = size.width * 0.92 > 1040.0 ? 1040.0 : size.width * 0.92;
    final dialogHeight = size.height * 0.88 > 700.0 ? 700.0 : size.height * 0.88;
    final isWide = dialogWidth >= 860;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: finDialogShape,
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            _buildHeader(),
            Divider(height: 1, color: FinDT.border),
            Expanded(
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 6, child: _ReceiptPane(state: this)),
                        VerticalDivider(width: 1, color: FinDT.border),
                        Expanded(flex: 5, child: _buildDetailPane()),
                      ],
                    )
                  : Column(
                      children: [
                        SizedBox(
                          height: 240.h,
                          child: _ReceiptPane(state: this),
                        ),
                        Divider(height: 1, color: FinDT.border),
                        Expanded(child: _buildDetailPane()),
                      ],
                    ),
            ),
            Divider(height: 1, color: FinDT.border),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 12.w, 14.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(9.w),
            decoration: BoxDecoration(
              color: FinDT.brandLight,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(
              widget.readOnly
                  ? Icons.receipt_long_rounded
                  : Icons.fact_check_outlined,
              size: 19.sp,
              color: FinDT.brand,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.readOnly
                      ? 'Receipt • ${expense.referenceNumber}'
                      : 'Verify Receipt & Approve — ${expense.referenceNumber}',
                  style: GoogleFonts.inter(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: FinDT.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '${expense.expenseCategory} • ${expense.expenseType} • '
                  '${DateFormat('dd MMM yyyy').format(expense.date)}',
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    color: FinDT.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ExpenseStatusBadge(status: expense.status),
          SizedBox(width: 4.w),
          IconButton(
            tooltip: 'Close',
            onPressed: _busy
                ? null
                : () => Navigator.pop(context, ExpenseReviewOutcome.dismissed),
            icon: Icon(Icons.close_rounded, size: 18.sp),
            color: FinDT.textSecondary,
          ),
        ],
      ),
    );
  }

  // ─── Detail pane ─────────────────────────────────────────────

  Widget _buildDetailPane() {
    final account =
        context.watch<FundAccountProvider>().getAccountById(expense.fundAccountId);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 18.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAmountBlock(),
          SizedBox(height: 16.h),
          _sectionLabel('CHECK AGAINST THE RECEIPT'),
          SizedBox(height: 8.h),
          _buildFactsCard(),
          SizedBox(height: 16.h),
          _sectionLabel('WALLET IMPACT'),
          SizedBox(height: 8.h),
          _buildWalletImpactCard(account),
          SizedBox(height: 16.h),
          _sectionLabel('POLICY'),
          SizedBox(height: 8.h),
          _buildPolicyCard(),
          if (!widget.readOnly && expense.status.canApprove) ...[
            SizedBox(height: 16.h),
            _buildVerificationBox(),
          ],
          if (_showRejectReason) ...[
            SizedBox(height: 14.h),
            _buildRejectBox(),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 10.sp,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: FinDT.textSecondary,
      ),
    );
  }

  Widget _buildAmountBlock() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: FinDT.brandLight,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: FinDT.brand.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AMOUNT CLAIMED',
            style: GoogleFonts.inter(
              fontSize: 9.5.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: FinDT.brand,
            ),
          ),
          SizedBox(height: 4.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${_money.format(expense.amount)} ${expense.currency}',
              style: GoogleFonts.inter(
                fontSize: 26.sp,
                fontWeight: FontWeight.w800,
                color: FinDT.textPrimary,
              ),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            'Confirm this figure matches the receipt total.',
            style: GoogleFonts.inter(
              fontSize: 10.5.sp,
              color: FinDT.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactsCard() {
    final facts = <(String, String)>[
      ('Date', DateFormat('dd MMM yyyy').format(expense.date)),
      ('Type', expense.expenseType),
      ('Category', expense.expenseCategory),
      ('Payment method', expense.paymentMethod.toUpperCase()),
      ('Wallet', widget.accountName),
      (
        'Submitted by',
        '${expense.submittedBy} (${expense.submittedByRole.toUpperCase()})'
      ),
      ('Submitted on', DateFormat('dd MMM yyyy, hh:mm a').format(expense.createdAt)),
      if (expense.employeeName != null && expense.employeeName!.isNotEmpty)
        ('Employee', expense.employeeName!),
      if (expense.vehicleName != null && expense.vehicleName!.isNotEmpty)
        (
          'Vehicle',
          '${expense.vehicleName!}'
              '${expense.mileageKm != null ? ' (${expense.mileageKm} km)' : ''}'
        ),
      if (expense.srvNumber != null && expense.srvNumber!.isNotEmpty)
        ('SRV #', expense.srvNumber!),
      if (expense.paymentDetails != null && expense.paymentDetails!.isNotEmpty)
        ('Payment details', expense.paymentDetails!),
      if (expense.description != null && expense.description!.isNotEmpty)
        ('Description', expense.description!),
    ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: FinDT.bgPage,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: FinDT.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < facts.length; i++) ...[
            if (i > 0) SizedBox(height: 7.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110.w,
                  child: Text(
                    facts[i].$1,
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      color: FinDT.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    facts[i].$2,
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: FinDT.textPrimary,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWalletImpactCard(FundAccountEntity? account) {
    if (expense.isNonWallet) {
      return _noteBox(
        icon: Icons.info_outline_rounded,
        color: FinDT.textSecondary,
        text: 'Tracking-only expense — approving it does not move money out '
            'of any wallet.',
      );
    }
    if (account == null) {
      return _noteBox(
        icon: Icons.help_outline_rounded,
        color: FinDT.warning,
        text: 'Wallet "${widget.accountName}" could not be resolved, so the '
            'balance impact cannot be shown.',
      );
    }

    final provider = context.watch<FinanceProvider>();
    final ledgerMinor = account.currentBalanceMinor;
    final thisMinor = expense.resolvedAmountMinor;
    final afterMinor = ledgerMinor - thisMinor;
    // Other pending expenses queued against the same wallet.
    final queuedMinor =
        provider.outstandingOutflowMinorFor(account.id) - thisMinor;
    final projectedMinor = afterMinor - (queuedMinor > 0 ? queuedMinor : 0);
    final goesNegative = afterMinor < 0;

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: goesNegative
            ? FinDT.danger.withValues(alpha: 0.05)
            : FinDT.bgPage,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: goesNegative
              ? FinDT.danger.withValues(alpha: 0.3)
              : FinDT.border,
        ),
      ),
      child: Column(
        children: [
          _impactRow('Ledger balance now', ledgerMinor, FinDT.textPrimary),
          SizedBox(height: 6.h),
          _impactRow('This expense', -thisMinor, FinDT.warning, signed: true),
          Divider(height: 14.h, color: FinDT.border),
          _impactRow(
            'Balance after approval',
            afterMinor,
            goesNegative ? FinDT.danger : FinDT.success,
            bold: true,
          ),
          if (queuedMinor > 0) ...[
            SizedBox(height: 6.h),
            _impactRow(
              'Other pending on this wallet',
              -queuedMinor,
              FinDT.textSecondary,
              signed: true,
            ),
            SizedBox(height: 6.h),
            _impactRow(
              'Projected if all approved',
              projectedMinor,
              projectedMinor < 0 ? FinDT.danger : FinDT.textPrimary,
              bold: true,
            ),
          ],
          if (goesNegative) ...[
            SizedBox(height: 10.h),
            _noteBox(
              icon: Icons.warning_amber_rounded,
              color: FinDT.danger,
              text: 'This approval alone would overdraw the wallet. '
                  'Top it up before approving.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _impactRow(String label, int minor, Color color,
      {bool bold = false, bool signed = false}) {
    final text = signed && minor != 0
        ? '− ${_money.format(minor.abs() / 100.0)}'
        : _money.format(minor / 100.0);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.sp,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            color: FinDT.textSecondary,
          ),
        ),
        Text(
          '$text ${expense.currency}',
          style: GoogleFonts.inter(
            fontSize: bold ? 12.5.sp : 11.5.sp,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildPolicyCard() {
    final threshold =
        context.read<FinanceProvider>().policy.receiptRequiredAbove;
    final satisfied = _hasReceipts || !_receiptRequired;

    return Column(
      children: [
        _policyRow(
          ok: satisfied,
          label: _hasReceipts
              ? '${_receipts.length} receipt${_receipts.length == 1 ? '' : 's'} attached'
              : _receiptRequired
                  ? 'Receipt required at or above ${_money.format(threshold)} SAR — none attached'
                  : 'No receipt (below the ${_money.format(threshold)} SAR threshold)',
        ),
        SizedBox(height: 6.h),
        _policyRow(
          ok: expense.status.canApprove,
          label: expense.status.canApprove
              ? 'Awaiting approval'
              : 'Status is ${expense.status.displayName} — no approval action available',
        ),
      ],
    );
  }

  Widget _policyRow({required bool ok, required String label}) {
    final color = ok ? FinDT.success : FinDT.danger;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          ok ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
          size: 14.sp,
          color: color,
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: FinDT.textSecondary,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationBox() {
    if (_blockedOnMissingReceipt) {
      return Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: FinDT.danger.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: FinDT.danger.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.block_rounded, size: 15.sp, color: FinDT.danger),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'Approval blocked — receipt missing',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: FinDT.danger,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 6.h),
            Text(
              'There is nothing to verify against. Ask the submitter for the '
              'receipt, attach it yourself, or reject the claim.',
              style: GoogleFonts.inter(
                fontSize: 11.sp,
                color: FinDT.textSecondary,
                height: 1.35,
              ),
            ),
          ],
        ),
      );
    }

    final label = _hasReceipts
        ? 'I have opened the receipt and it matches the amount, date and '
            'purpose of this expense.'
        : 'No receipt is attached. I confirm this expense may be approved '
            'without one.';

    return Material(
      color: _verified
          ? FinDT.success.withValues(alpha: 0.07)
          : FinDT.warning.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        onTap: _busy ? null : () => setState(() => _verified = !_verified),
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: (_verified ? FinDT.success : FinDT.warning)
                  .withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 20.w,
                height: 20.w,
                child: Checkbox(
                  value: _verified,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _verified = v ?? false),
                  activeColor: FinDT.success,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w600,
                    color: _verified ? FinDT.success : FinDT.warning,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRejectBox() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: FinDT.danger.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: FinDT.danger.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Why is this being rejected?',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: FinDT.danger,
            ),
          ),
          SizedBox(height: 10.h),
          TextField(
            controller: _reasonController,
            maxLines: 3,
            autofocus: true,
            enabled: !_busy,
            decoration: finDialogInputDecoration(
              label: 'Rejection Reason *',
              hint: 'e.g. receipt total does not match the claimed amount',
              prefixIcon: Icons.edit_note_rounded,
            ),
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              color: FinDT.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _noteBox({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14.sp, color: color),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 11.sp,
                color: color,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Footer ──────────────────────────────────────────────────

  Widget _buildFooter() {
    final auth = context.read<AuthProvider>().user;
    final policy = context.read<FinanceProvider>().policy;
    final canApprove = FinancePermissionService.canApproveExpense(
      user: auth,
      policy: policy,
      amount: expense.amount,
    );
    final showActions =
        !widget.readOnly && expense.status.canApprove && canApprove;

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
      child: Row(
        children: [
          if (showActions && !_hasReceipts)
            TextButton.icon(
              onPressed: _busy ? null : _openFormToAttachReceipt,
              icon: Icon(Icons.attach_file_rounded, size: 15.sp),
              label: Text(
                'Attach receipt',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(foregroundColor: FinDT.brand),
            ),
          const Spacer(),
          if (!showActions)
            finDialogActionButton(
              onPressed: () =>
                  Navigator.pop(context, ExpenseReviewOutcome.dismissed),
              label: 'Close',
              backgroundColor: FinDT.brand,
            )
          else if (_showRejectReason) ...[
            finDialogCancelButton(
              context,
              label: 'Back',
              onPressed: _busy
                  ? () {}
                  : () => setState(() => _showRejectReason = false),
            ),
            SizedBox(width: 8.w),
            finDialogActionButton(
              onPressed: _busy ? null : _submitRejection,
              label: 'Confirm Rejection',
              backgroundColor: FinDT.danger,
              icon: Icons.cancel_outlined,
              isLoading: _busy,
            ),
          ] else ...[
            finDialogCancelButton(
              context,
              onPressed: _busy
                  ? () {}
                  : () =>
                      Navigator.pop(context, ExpenseReviewOutcome.dismissed),
            ),
            SizedBox(width: 8.w),
            OutlinedButton.icon(
              onPressed:
                  _busy ? null : () => setState(() => _showRejectReason = true),
              icon: Icon(Icons.cancel_outlined, size: 15.sp),
              label: Text(
                'Reject',
                style: GoogleFonts.inter(
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: FinDT.danger,
                side: BorderSide(color: FinDT.danger.withValues(alpha: 0.4)),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Tooltip(
              message: _canApproveNow
                  ? ''
                  : _blockedOnMissingReceipt
                      ? 'A receipt is required before this can be approved'
                      : 'Confirm you checked the receipt first',
              child: finDialogActionButton(
                onPressed: _canApproveNow ? _submitApproval : null,
                label: expense.isNonWallet ? 'Approve' : 'Approve & Pay',
                backgroundColor: FinDT.success,
                icon: Icons.check_circle_outline_rounded,
                isLoading: _busy,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Actions ─────────────────────────────────────────────────

  void _openFormToAttachReceipt() {
    Navigator.pop(context, ExpenseReviewOutcome.editRequested);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ExpenseFormPage(expense: expense)),
    );
  }

  Future<void> _submitApproval() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final fundProv = context.read<FundAccountProvider>();
    final finProv = context.read<FinanceProvider>();
    final account = fundProv.getAccountById(expense.fundAccountId);

    // Petty cash can only be paid out while a session is open — check up
    // front so the reviewer gets a clear message instead of a raw error.
    if (!expense.isNonWallet && account?.isPettyCash == true) {
      final session =
          await context.read<PettyCashProvider>().getOpenSessionUseCase(
                account!.id,
              );
      if (session == null) {
        if (!mounted) return;
        AppSnackBar.showWarning(
          context,
          'No petty cash session is open for "${account.name}". '
          'Open a session before paying from this drawer.',
        );
        return;
      }
    }

    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await finProv.approveExpense(
        expenseId: expense.id,
        actorName: user.actorLabel,
        actorUserId: user.id,
        actorRole: user.role.name,
        allowSelfApprove: user.isAdmin,
      );
      await fundProv.fetchAllAccounts();
      if (!mounted) return;
      Navigator.pop(context, ExpenseReviewOutcome.approved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnackBar.showError(context, _friendlyError(e));
    }
  }

  Future<void> _submitRejection() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      AppSnackBar.showInfo(context, 'A rejection reason is required.');
      return;
    }

    setState(() => _busy = true);
    try {
      await context.read<FinanceProvider>().rejectExpense(
            expenseId: expense.id,
            actorName: user.actorLabel,
            actorUserId: user.id,
            reason: reason,
          );
      if (!mounted) return;
      Navigator.pop(context, ExpenseReviewOutcome.rejected);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnackBar.showError(context, _friendlyError(e));
    }
  }

  String _friendlyError(Object e) => e
      .toString()
      .replaceFirst('StateError: ', '')
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');
}

// ═══════════════════════════════════════════════════════════════════════════
// RECEIPT PANE
// ═══════════════════════════════════════════════════════════════════════════

class _ReceiptPane extends StatelessWidget {
  final _ExpenseReviewDialogState state;
  const _ReceiptPane({required this.state});

  static const _imageExtensions = {
    '.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.heic',
  };

  /// Firebase Storage URLs keep the object path (with its extension) before
  /// the query string, so the extension is a reliable enough hint.
  static bool _isImage(String url) {
    final path = _objectPath(url).toLowerCase();
    return _imageExtensions.any(path.endsWith);
  }

  static String _fileLabel(String url, int index) {
    final name = _objectPath(url).split('/').last;
    return name.isEmpty ? 'Receipt ${index + 1}' : name;
  }

  /// Decoded storage object path, falling back to the raw string when the
  /// URL is not something we can parse or decode.
  static String _objectPath(String url) {
    final path = Uri.tryParse(url)?.path ?? url;
    try {
      return Uri.decodeComponent(path);
    } on FormatException {
      return path;
    }
  }

  @override
  Widget build(BuildContext context) {
    final receipts = state._receipts;

    return Container(
      color: const Color(0xFF0F172A),
      child: receipts.isEmpty
          ? _buildEmpty(context)
          : Column(
              children: [
                _buildToolbar(context, receipts),
                Expanded(child: _buildViewer(context, receipts)),
                if (receipts.length > 1) _buildThumbnails(context, receipts),
              ],
            ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final blocked = state._blockedOnMissingReceipt;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              blocked
                  ? Icons.receipt_long_outlined
                  : Icons.description_outlined,
              size: 42.sp,
              color: blocked
                  ? FinDT.danger.withValues(alpha: 0.8)
                  : Colors.white24,
            ),
            SizedBox(height: 14.h),
            Text(
              'No receipt attached',
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              blocked
                  ? 'This expense is at or above the receipt threshold, so it '
                      'cannot be approved until a document is attached.'
                  : 'This expense is below the receipt threshold, so approval '
                      'is still possible without a document.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11.5.sp,
                color: Colors.white60,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context, List<String> receipts) {
    final index = state._receiptIndex;
    final url = receipts[index];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      color: Colors.black.withValues(alpha: 0.35),
      child: Row(
        children: [
          Icon(Icons.receipt_long_rounded, size: 14.sp, color: Colors.white70),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              receipts.length == 1
                  ? _fileLabel(url, index)
                  : 'Receipt ${index + 1} of ${receipts.length} — ${_fileLabel(url, index)}',
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          if (receipts.length > 1) ...[
            _toolbarButton(
              icon: Icons.chevron_left_rounded,
              tooltip: 'Previous receipt',
              onTap: index == 0 ? null : () => state.showReceipt(index - 1),
            ),
            _toolbarButton(
              icon: Icons.chevron_right_rounded,
              tooltip: 'Next receipt',
              onTap: index == receipts.length - 1
                  ? null
                  : () => state.showReceipt(index + 1),
            ),
          ],
          _toolbarButton(
            icon: Icons.open_in_new_rounded,
            tooltip: 'Open in browser / new tab',
            onTap: () => launchUrl(
              Uri.parse(url),
              mode: LaunchMode.externalApplication,
            ),
          ),
          _toolbarButton(
            icon: Icons.open_in_full_rounded,
            tooltip: 'Open full screen',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DocumentViewerScreen(
                  attachmentUrl: url,
                  title: _fileLabel(url, index),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 17.sp),
        color: Colors.white,
        disabledColor: Colors.white24,
        visualDensity: VisualDensity.compact,
        splashRadius: 18.r,
      ),
    );
  }

  Widget _buildViewer(BuildContext context, List<String> receipts) {
    final url = receipts[state._receiptIndex];

    if (!_isImage(url)) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.picture_as_pdf_outlined,
                size: 40.sp,
                color: Colors.white54,
              ),
              SizedBox(height: 12.h),
              Text(
                _fileLabel(url, state._receiptIndex),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Document preview is not inline — open it to verify.',
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  color: Colors.white60,
                ),
              ),
              SizedBox(height: 14.h),
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DocumentViewerScreen(
                      attachmentUrl: url,
                      title: _fileLabel(url, state._receiptIndex),
                    ),
                  ),
                ),
                icon: Icon(Icons.open_in_new_rounded, size: 15.sp),
                label: Text(
                  'Open document',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: FinDT.brand,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return InteractiveViewer(
      minScale: 1,
      maxScale: 5,
      child: Center(
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.contain,
          placeholder: (_, __) => Padding(
            padding: EdgeInsets.all(28.w),
            child: const CircularProgressIndicator(
              color: Colors.white54,
              strokeWidth: 2.5,
            ),
          ),
          errorWidget: (_, __, ___) => _buildImageErrorWidget(context, url),
        ),
      ),
    );
  }

  Widget _buildImageErrorWidget(BuildContext context, String url) {
    return Padding(
      padding: EdgeInsets.all(24.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 34.sp,
            color: Colors.white38,
          ),
          SizedBox(height: 10.h),
          Text(
            'Receipt could not be loaded.',
            style: GoogleFonts.inter(
              fontSize: 11.5.sp,
              color: Colors.white60,
            ),
          ),
          SizedBox(height: 12.h),
          OutlinedButton.icon(
            onPressed: () => launchUrl(
              Uri.parse(url),
              mode: LaunchMode.externalApplication,
            ),
            icon: Icon(Icons.open_in_new, size: 14.sp, color: Colors.white70),
            label: Text(
              'Open in browser',
              style: GoogleFonts.inter(fontSize: 11.sp, color: Colors.white),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnails(BuildContext context, List<String> receipts) {
    return Container(
      height: 64.h,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      color: Colors.black.withValues(alpha: 0.35),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: receipts.length,
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemBuilder: (_, i) {
          final selected = i == state._receiptIndex;
          final url = receipts[i];
          return InkWell(
            onTap: () => state.showReceipt(i),
            borderRadius: BorderRadius.circular(6.r),
            child: Container(
              width: 48.w,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6.r),
                border: Border.all(
                  color: selected ? FinDT.brand : Colors.white24,
                  width: selected ? 2 : 1,
                ),
                color: Colors.white10,
              ),
              clipBehavior: Clip.antiAlias,
              child: _isImage(url)
                  ? CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: Colors.white10),
                      errorWidget: (_, __, ___) => Icon(
                        Icons.broken_image_outlined,
                        size: 16.sp,
                        color: Colors.white38,
                      ),
                    )
                  : Icon(
                      Icons.description_outlined,
                      size: 18.sp,
                      color: Colors.white70,
                    ),
            ),
          );
        },
      ),
    );
  }
}
