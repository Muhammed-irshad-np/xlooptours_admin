import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../employee/domain/entities/employee_entity.dart';
import '../../../employee/presentation/providers/employee_provider.dart';
import '../../domain/entities/cash_advance_entity.dart';
import '../../domain/entities/fund_account_entity.dart';
import '../../domain/entities/salary_entity.dart';
import '../../domain/services/finance_export_service.dart';
import '../../domain/services/finance_permission_service.dart';
import '../providers/cash_advance_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/fund_account_provider.dart';
import '../providers/salary_provider.dart';
import '../widgets/finance_dialog_helpers.dart';
import 'finance_dashboard_page.dart';

/// One line of the monthly payroll: an employee on the payroll, together with
/// this month's salary row when it already exists.
class _PayrollRow {
  final String employeeId;
  final String employeeName;
  final String position;
  final SalaryStructureEntity? structure;
  final SalaryPaymentEntity? payment;

  const _PayrollRow({
    required this.employeeId,
    required this.employeeName,
    required this.position,
    this.structure,
    this.payment,
  });

  double get basic => payment?.basicSalary ?? structure?.basicSalary ?? 0;
  double get allowances => payment?.allowances ?? structure?.allowances ?? 0;
  double get deductions => payment?.deductions ?? 0;
  double get advanceRecovery => payment?.advanceRecovery ?? 0;

  /// Everything held back from gross pay: manual deductions plus any amount
  /// recovered against outstanding advances.
  double get withheld => deductions + advanceRecovery;
  double get net =>
      payment?.netAmount ??
      SalaryPaymentEntity.computeNet(
        basicSalary: basic,
        allowances: allowances,
      );
  String get currency => payment?.currency ?? structure?.currency ?? 'SAR';
}

/// Monthly staff payroll: set a salary per employee, then pay each one out of
/// a fund account for the selected month.
class SalariesPage extends StatefulWidget {
  const SalariesPage({super.key});

  @override
  State<SalariesPage> createState() => _SalariesPageState();
}

class _SalariesPageState extends State<SalariesPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SalaryProvider>().load();
      context.read<EmployeeProvider>().fetchAllEmployees();
      context.read<FundAccountProvider>().fetchAllAccounts();
      // Needed to offer advance recovery when paying a salary.
      context.read<CashAdvanceProvider>().load();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _canManage {
    final user = context.read<AuthProvider>().user;
    final policy = context.read<FinanceProvider>().policy;
    return FinancePermissionService.canManageSalaries(
      user: user,
      policy: policy,
    );
  }

  /// Employees that can be put on the payroll: active internal staff only.
  List<EmployeeEntity> _payrollEligibleEmployees() {
    return context
        .read<EmployeeProvider>()
        .employees
        .where((e) => e.isActive && e.canHoldCompanyRecords)
        .toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  List<_PayrollRow> _buildRows(SalaryProvider provider) {
    final rows = <_PayrollRow>[];
    final seen = <String>{};

    for (final s in provider.structures) {
      if (!s.isActive) continue;
      seen.add(s.employeeId);
      rows.add(
        _PayrollRow(
          employeeId: s.employeeId,
          employeeName: s.employeeName,
          position: s.position,
          structure: s,
          payment: provider.paymentFor(s.employeeId),
        ),
      );
    }

    // Salary rows whose employee was since taken off the payroll still belong
    // to the month's history.
    for (final p in provider.payments) {
      if (seen.contains(p.employeeId)) continue;
      rows.add(
        _PayrollRow(
          employeeId: p.employeeId,
          employeeName: p.employeeName,
          position: p.position,
          structure: provider.structureFor(p.employeeId),
          payment: p,
        ),
      );
    }

    rows.sort((a, b) => a.employeeName.compareTo(b.employeeName));
    return rows;
  }

  List<_PayrollRow> _filterRows(List<_PayrollRow> rows) {
    return rows.where((r) {
      final status = r.payment?.status;
      // No payment row yet counts as pending — it hasn't been paid.
      final isPending = status == null || status == SalaryPaymentStatus.pending;
      if (_statusFilter == 'PENDING' && !isPending) return false;
      if (_statusFilter == 'PAID' && status != SalaryPaymentStatus.paid) {
        return false;
      }
      if (_statusFilter == 'VOIDED' && status != SalaryPaymentStatus.voided) {
        return false;
      }

      final q = _searchCtrl.text.trim().toLowerCase();
      if (q.isNotEmpty) {
        final nameMatch = r.employeeName.toLowerCase().contains(q);
        final posMatch = r.position.toLowerCase().contains(q);
        if (!nameMatch && !posMatch) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');

    return Consumer<SalaryProvider>(
      builder: (context, provider, _) {
        final rows = _buildRows(provider);
        final filtered = _filterRows(rows);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildToolbar(context, provider, rows),
            SizedBox(height: 16.h),
            _buildKpiRow(provider, rows, fmt),
            SizedBox(height: 16.h),
            _buildFilterBar(rows),
            SizedBox(height: 12.h),
            if (provider.isLoading && rows.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 60.h),
                child: const Center(
                  child: CircularProgressIndicator(color: FinDT.brand),
                ),
              )
            else if (filtered.isEmpty)
              _buildEmptyState(rows.isEmpty)
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => SizedBox(height: 10.h),
                itemBuilder: (_, i) =>
                    _buildSalaryCard(context, provider, filtered[i], fmt),
              ),
          ],
        );
      },
    );
  }

  // ─── Toolbar ────────────────────────────────────────────────

  Widget _buildToolbar(
    BuildContext context,
    SalaryProvider provider,
    List<_PayrollRow> rows,
  ) {
    final monthLabel = DateFormat('MMMM y').format(provider.periodDate);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: FinDT.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: FinDT.brand.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(Icons.badge_outlined, size: 20.sp, color: FinDT.brand),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payroll & Salaries',
                  style: GoogleFonts.inter(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: FinDT.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Set a monthly salary per employee, then pay each one from a fund account',
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    color: FinDT.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Month stepper
          Container(
            decoration: BoxDecoration(
              color: FinDT.bgPage,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: FinDT.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  onPressed: provider.isLoading
                      ? null
                      : () => provider.shiftPeriod(-1),
                  icon: Icon(Icons.chevron_left, size: 18.sp),
                  color: FinDT.textSecondary,
                ),
                SizedBox(
                  width: 110.w,
                  child: Text(
                    monthLabel,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: FinDT.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Next month',
                  onPressed: provider.isLoading
                      ? null
                      : () => provider.shiftPeriod(1),
                  icon: Icon(Icons.chevron_right, size: 18.sp),
                  color: FinDT.textSecondary,
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          OutlinedButton.icon(
            onPressed: provider.payments.isEmpty
                ? null
                : () async {
                    await FinanceExportService.shareCsv(
                      fileName: 'salaries_${provider.period}.csv',
                      csvContent: FinanceExportService.salariesToCsv(
                        provider.payments,
                      ),
                    );
                  },
            icon: Icon(Icons.download_rounded, size: 15.sp),
            label: Text(
              'Export CSV',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: FinDT.brand,
              side: BorderSide(color: FinDT.brand.withValues(alpha: 0.4)),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          OutlinedButton.icon(
            onPressed: () => _showStructureDialog(context),
            icon: Icon(Icons.person_add_alt_1_outlined, size: 15.sp),
            label: Text(
              'Add to Payroll',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: FinDT.textPrimary,
              side: const BorderSide(color: FinDT.border),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiRow(
    SalaryProvider provider,
    List<_PayrollRow> rows,
    NumberFormat fmt,
  ) {
    // "Pending" is computed live from the payroll list, not from generated
    // rows — an employee who hasn't been paid yet this month counts as
    // pending whether or not a salary_payments row exists for them.
    final unpaidRows = rows
        .where((r) => r.payment?.status != SalaryPaymentStatus.paid)
        .toList();
    final totalPending = unpaidRows.fold(0.0, (sum, r) => sum + r.net);
    final currency = rows.isEmpty ? 'SAR' : rows.first.currency;

    return SizedBox(
      height: 96.h,
      child: Row(
        children: [
          Expanded(
            child: _buildKpiCard(
              title: 'On Payroll',
              value: '${provider.activeStructures.length}',
              subtitle:
                  '${fmt.format(provider.monthlyPayrollCost)} $currency / month',
              icon: Icons.groups_outlined,
              color: FinDT.brand,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _buildKpiCard(
              title: 'Paid This Month',
              value: fmt.format(provider.totalPaid),
              subtitle: '${provider.paidPayments.length} salaries paid',
              icon: Icons.check_circle_outline,
              color: FinDT.success,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _buildKpiCard(
              title: 'Pending',
              value: fmt.format(totalPending),
              subtitle: '${unpaidRows.length} awaiting payment',
              icon: Icons.schedule_outlined,
              color: FinDT.warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: FinDT.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: FinDT.textSecondary,
                ),
              ),
              Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(icon, size: 16.sp, color: color),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w800,
                  color: FinDT.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w500,
                  color: FinDT.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(List<_PayrollRow> rows) {
    int countOf(SalaryPaymentStatus status) =>
        rows.where((r) => r.payment?.status == status).length;
    // No payment row yet also counts as pending.
    final pendingCount = rows
        .where((r) =>
            r.payment == null ||
            r.payment!.status == SalaryPaymentStatus.pending)
        .length;

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: FinDT.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 260.w,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.inter(fontSize: 12.sp),
              decoration: finDialogInputDecoration(
                label: 'Search',
                hint: 'Employee or position',
                prefixIcon: Icons.search,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatusPill(label: 'All', count: rows.length, value: 'ALL'),
                  SizedBox(width: 8.w),
                  _buildStatusPill(
                    label: 'Pending',
                    count: pendingCount,
                    value: 'PENDING',
                    color: FinDT.warning,
                  ),
                  SizedBox(width: 8.w),
                  _buildStatusPill(
                    label: 'Paid',
                    count: countOf(SalaryPaymentStatus.paid),
                    value: 'PAID',
                    color: FinDT.success,
                  ),
                  SizedBox(width: 8.w),
                  _buildStatusPill(
                    label: 'Voided',
                    count: countOf(SalaryPaymentStatus.voided),
                    value: 'VOIDED',
                    color: FinDT.danger,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill({
    required String label,
    required int count,
    required String value,
    Color? color,
  }) {
    final isSelected = _statusFilter == value;
    final activeColor = color ?? FinDT.brand;

    return InkWell(
      onTap: () => setState(() => _statusFilter = value),
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.12) : FinDT.bgPage,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: isSelected ? activeColor.withValues(alpha: 0.5) : FinDT.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.sp,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : FinDT.textSecondary,
              ),
            ),
            SizedBox(width: 6.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: isSelected ? activeColor : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : FinDT.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool payrollEmpty) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 56.h, horizontal: 24.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: FinDT.border),
      ),
      child: Column(
        children: [
          Icon(Icons.badge_outlined, size: 40.sp, color: FinDT.textMuted),
          SizedBox(height: 12.h),
          Text(
            payrollEmpty ? 'No one on the payroll yet' : 'Nothing matches this filter',
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: FinDT.textPrimary,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            payrollEmpty
                ? 'Use "Add to Payroll" to set an employee\'s monthly salary, then generate the month.'
                : 'Try another status or clear the search.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textSecondary),
          ),
        ],
      ),
    );
  }

  // ─── Salary row ─────────────────────────────────────────────

  Widget _buildSalaryCard(
    BuildContext context,
    SalaryProvider provider,
    _PayrollRow row,
    NumberFormat fmt,
  ) {
    final payment = row.payment;
    final status = payment?.status;
    // No payment row yet reads the same as pending — it just hasn't been paid.
    final statusColor = switch (status) {
      null || SalaryPaymentStatus.pending => FinDT.warning,
      SalaryPaymentStatus.paid => FinDT.success,
      SalaryPaymentStatus.voided => FinDT.danger,
    };
    final statusLabel = status?.displayName ?? 'Pending';

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: FinDT.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18.r,
            backgroundColor: FinDT.brandLight,
            child: Text(
              _initials(row.employeeName),
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: FinDT.brand,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.employeeName,
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: FinDT.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  row.position.isEmpty ? '—' : row.position,
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    color: FinDT.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: _amountCell('Basic', fmt.format(row.basic), row.currency),
          ),
          Expanded(
            flex: 2,
            child: _amountCell(
              'Allowances',
              fmt.format(row.allowances),
              row.currency,
            ),
          ),
          Expanded(
            flex: 2,
            child: _amountCell(
              'Withheld',
              fmt.format(row.withheld),
              row.currency,
              color: row.withheld > 0 ? FinDT.danger : null,
              note: row.advanceRecovery > 0
                  ? 'incl. ${fmt.format(row.advanceRecovery)} advance'
                  : null,
            ),
          ),
          Expanded(
            flex: 2,
            child: _amountCell(
              'Net pay',
              fmt.format(row.net),
              row.currency,
              emphasize: true,
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    statusLabel,
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                if (payment?.status == SalaryPaymentStatus.paid) ...[
                  SizedBox(height: 4.h),
                  Text(
                    '${payment!.fundAccountName ?? 'Account'} · '
                    '${DateFormat('d MMM').format(payment.paidAt ?? payment.createdAt)}',
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      color: FinDT.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          _buildRowActions(context, provider, row),
        ],
      ),
    );
  }

  Widget _amountCell(
    String label,
    String value,
    String currency, {
    bool emphasize = false,
    Color? color,
    String? note,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10.sp, color: FinDT.textMuted),
        ),
        SizedBox(height: 2.h),
        Text(
          '$value $currency',
          style: GoogleFonts.inter(
            fontSize: emphasize ? 13.sp : 12.sp,
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            color: color ?? FinDT.textPrimary,
          ),
        ),
        if (note != null)
          Text(
            note,
            style: GoogleFonts.inter(fontSize: 9.sp, color: FinDT.warning),
          ),
      ],
    );
  }

  Widget _buildRowActions(
    BuildContext context,
    SalaryProvider provider,
    _PayrollRow row,
  ) {
    final payment = row.payment;
    final canPay = payment == null || payment.status.canPay;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canPay)
          finDialogActionButton(
            onPressed: () => _showPayDialog(context, provider, row),
            label: 'Pay',
            icon: Icons.payments_outlined,
          ),
        PopupMenuButton<String>(
          tooltip: 'More',
          icon: Icon(Icons.more_vert, size: 18.sp, color: FinDT.textSecondary),
          itemBuilder: (_) => [
            if (row.structure != null)
              const PopupMenuItem(value: 'edit', child: Text('Edit salary')),
            if (payment != null && payment.status.canDelete)
              const PopupMenuItem(
                value: 'delete',
                child: Text('Remove this month'),
              ),
            if (payment != null && payment.status.canVoid)
              const PopupMenuItem(
                value: 'void',
                child: Text('Void payment'),
              ),
            if (row.structure != null)
              const PopupMenuItem(
                value: 'off_payroll',
                child: Text('Take off payroll'),
              ),
          ],
          onSelected: (action) =>
              _handleRowAction(context, provider, row, action),
        ),
      ],
    );
  }

  Future<void> _handleRowAction(
    BuildContext context,
    SalaryProvider provider,
    _PayrollRow row,
    String action,
  ) async {
    switch (action) {
      case 'edit':
        await _showStructureDialog(context, existing: row.structure);
        break;
      case 'delete':
        await _deletePendingPayment(context, provider, row);
        break;
      case 'void':
        await _showVoidDialog(context, provider, row.payment!);
        break;
      case 'off_payroll':
        await _takeOffPayroll(context, provider, row);
        break;
    }
  }

  // ─── Actions ────────────────────────────────────────────────

  Future<void> _deletePendingPayment(
    BuildContext context,
    SalaryProvider provider,
    _PayrollRow row,
  ) async {
    if (!_guardPermission(context)) return;
    final confirmed = await showFinConfirmationDialog(
      context: context,
      title: 'Remove Salary Row',
      icon: Icons.delete_outline_rounded,
      iconColor: FinDT.danger,
      confirmColor: FinDT.danger,
      message:
          'Remove ${row.employeeName}\'s pending salary for this month? '
          'You can regenerate it later.',
      confirmLabel: 'Remove',
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await provider.deletePayment(row.payment!.id);
      if (context.mounted) _snack(context, 'Salary row removed.', FinDT.success);
    } catch (e) {
      if (context.mounted) _snack(context, 'Failed: $e', FinDT.danger);
    }
  }

  Future<void> _takeOffPayroll(
    BuildContext context,
    SalaryProvider provider,
    _PayrollRow row,
  ) async {
    if (!_guardPermission(context)) return;
    final confirmed = await showFinConfirmationDialog(
      context: context,
      title: 'Take Off Payroll',
      icon: Icons.person_remove_outlined,
      iconColor: FinDT.danger,
      confirmColor: FinDT.danger,
      message:
          '${row.employeeName} will no longer be included when a payroll month '
          'is generated. Salaries already paid stay in the history.',
      confirmLabel: 'Take Off Payroll',
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await provider.removeStructure(row.employeeId);
      if (context.mounted) {
        _snack(context, '${row.employeeName} taken off the payroll.', FinDT.success);
      }
    } catch (e) {
      if (context.mounted) _snack(context, 'Failed: $e', FinDT.danger);
    }
  }

  // ─── Dialogs ────────────────────────────────────────────────

  /// Put an employee on the payroll (or edit their monthly salary).
  Future<void> _showStructureDialog(
    BuildContext context, {
    SalaryStructureEntity? existing,
  }) async {
    if (!_guardPermission(context)) return;

    final provider = context.read<SalaryProvider>();
    final accounts = context.read<FundAccountProvider>().activeAccounts;
    if (accounts.isEmpty) {
      _snack(
        context,
        'Create an active fund account first — salaries are paid from one.',
        FinDT.danger,
      );
      return;
    }

    final onPayroll = provider.structures.map((s) => s.employeeId).toSet();
    final employees = _payrollEligibleEmployees()
        .where((e) => e.id == existing?.employeeId || !onPayroll.contains(e.id))
        .toList();

    if (existing == null && employees.isEmpty) {
      _snack(
        context,
        'Every active employee is already on the payroll.',
        FinDT.textSecondary,
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final basicCtrl = TextEditingController(
      text: existing != null ? existing.basicSalary.toStringAsFixed(2) : '',
    );
    final allowanceCtrl = TextEditingController(
      text: existing != null ? existing.allowances.toStringAsFixed(2) : '',
    );
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');

    EmployeeEntity? employee = existing == null
        ? null
        : employees.where((e) => e.id == existing.employeeId).firstOrNull;
    String? accountId = existing?.defaultFundAccountId ??
        (accounts.isNotEmpty ? accounts.first.id : null);
    if (accounts.every((a) => a.id != accountId)) accountId = accounts.first.id;
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) {
          final account = accounts.firstWhere(
            (a) => a.id == accountId,
            orElse: () => accounts.first,
          );

          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: finDialogShape,
            title: finDialogTitle(
              existing == null ? 'Add Employee to Payroll' : 'Edit Monthly Salary',
              icon: Icons.badge_outlined,
            ),
            content: SizedBox(
              width: 420.w,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: 8.h),
                      if (existing == null)
                        DropdownButtonFormField<EmployeeEntity>(
                          initialValue: employee,
                          decoration: finDialogInputDecoration(
                            label: 'Employee *',
                            hint: 'Select staff member',
                            prefixIcon: Icons.person_outline,
                          ),
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            color: FinDT.textPrimary,
                          ),
                          items: employees
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(
                                    e.position.isEmpty
                                        ? e.fullName
                                        : '${e.fullName} · ${e.position}',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged:
                              isSaving ? null : (v) => setInner(() => employee = v),
                          validator: (v) => v == null ? 'Required' : null,
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: FinDT.bgPage,
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(color: FinDT.border),
                          ),
                          child: Text(
                            existing.employeeName,
                            style: GoogleFonts.inter(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: FinDT.textPrimary,
                            ),
                          ),
                        ),
                      SizedBox(height: 14.h),
                      DropdownButtonFormField<String>(
                        initialValue: accountId,
                        decoration: finDialogInputDecoration(
                          label: 'Default Pay Account *',
                          hint: 'Salary is paid from here',
                          prefixIcon: Icons.account_balance_wallet_outlined,
                        ),
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          color: FinDT.textPrimary,
                        ),
                        items: accounts
                            .map(
                              (a) => DropdownMenuItem(
                                value: a.id,
                                child: Text('${a.name} (${a.currency})'),
                              ),
                            )
                            .toList(),
                        onChanged:
                            isSaving ? null : (v) => setInner(() => accountId = v),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      SizedBox(height: 14.h),
                      TextFormField(
                        controller: basicCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        decoration: finDialogInputDecoration(
                          label: 'Basic Monthly Salary *',
                          hint: '0.00',
                          prefixIcon: Icons.payments_outlined,
                          suffixText: account.currency,
                        ),
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          color: FinDT.textPrimary,
                        ),
                        validator: (v) {
                          final n = double.tryParse(v ?? '');
                          if (n == null || n <= 0) {
                            return 'Enter a valid positive amount';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 14.h),
                      TextFormField(
                        controller: allowanceCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        decoration: finDialogInputDecoration(
                          label: 'Fixed Allowances',
                          hint: 'Housing, transport, phone… (0 if none)',
                          prefixIcon: Icons.add_card_outlined,
                          suffixText: account.currency,
                        ),
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          color: FinDT.textPrimary,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final n = double.tryParse(v);
                          if (n == null || n < 0) return 'Enter a valid amount';
                          return null;
                        },
                      ),
                      SizedBox(height: 14.h),
                      TextFormField(
                        controller: notesCtrl,
                        decoration: finDialogInputDecoration(
                          label: 'Notes',
                          hint: 'Contract reference, review date…',
                          prefixIcon: Icons.notes_outlined,
                        ),
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          color: FinDT.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              finDialogCancelButton(ctx, onPressed: isSaving ? () {} : null),
              finDialogActionButton(
                isLoading: isSaving,
                label: existing == null ? 'Add to Payroll' : 'Save Salary',
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final user = context.read<AuthProvider>().user;
                  final acc =
                      accounts.firstWhere((a) => a.id == accountId);
                  final structure = SalaryStructureEntity(
                    employeeId: existing?.employeeId ?? employee!.id,
                    employeeName: existing?.employeeName ?? employee!.fullName,
                    position: existing?.position ?? employee?.position ?? '',
                    basicSalary: double.parse(basicCtrl.text),
                    allowances:
                        double.tryParse(allowanceCtrl.text.trim()) ?? 0,
                    currency: acc.currency,
                    defaultFundAccountId: acc.id,
                    notes: notesCtrl.text.trim().isEmpty
                        ? null
                        : notesCtrl.text.trim(),
                    updatedAt: DateTime.now(),
                    updatedBy: user?.actorLabel ?? 'Admin',
                  );

                  setInner(() => isSaving = true);
                  try {
                    await provider.saveStructure(structure);
                    if (ctx.mounted) finSafePop(ctx);
                    if (context.mounted) {
                      _snack(
                        context,
                        '${structure.employeeName} saved with '
                        '${structure.grossSalary.toStringAsFixed(2)} '
                        '${structure.currency} / month.',
                        FinDT.success,
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      setInner(() => isSaving = false);
                      _snack(context, 'Failed to save salary: $e', FinDT.danger);
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  /// Pay one salary: pick the account and bucket, optionally deduct and
  /// recover outstanding advances, then post the money.
  Future<void> _showPayDialog(
    BuildContext context,
    SalaryProvider provider,
    _PayrollRow row,
  ) async {
    if (!_guardPermission(context)) return;

    final allAccounts = context.read<FundAccountProvider>().activeAccounts;
    final accounts =
        allAccounts.where((a) => a.currency == row.currency).toList();
    if (accounts.isEmpty) {
      _snack(
        context,
        'No active fund account in ${row.currency} to pay this salary from.',
        FinDT.danger,
      );
      return;
    }

    // Outstanding advances this employee still owes back.
    final openAdvances = context
        .read<CashAdvanceProvider>()
        .advances
        .where((a) => a.employeeId == row.employeeId && a.isOpen)
        .toList()
      ..sort((a, b) => a.issuedAt.compareTo(b.issuedAt));
    final totalOutstanding =
        SalaryPaymentEntity.totalOutstanding(openAdvances);

    final formKey = GlobalKey<FormState>();
    final deductionCtrl = TextEditingController(
      text: row.deductions > 0 ? row.deductions.toStringAsFixed(2) : '',
    );
    final deductionNoteCtrl =
        TextEditingController(text: row.payment?.deductionNote ?? '');
    final recoveryCtrl = TextEditingController();

    String accountId = row.payment?.fundAccountId ??
        row.structure?.defaultFundAccountId ??
        accounts.first.id;
    if (accounts.every((a) => a.id != accountId)) accountId = accounts.first.id;
    String paymentMethod = row.payment?.paymentMethod ?? 'cash';
    bool isPaying = false;

    final fmt = NumberFormat('#,##0.00');
    final monthLabel = DateFormat('MMMM y').format(provider.periodDate);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) {
          final account = accounts.firstWhere(
            (a) => a.id == accountId,
            orElse: () => accounts.first,
          );
          // Petty cash wallets track physical cash and STC Pay separately, so
          // the payer has to say which one the salary came out of.
          final usesBuckets = account.isPettyCash ||
              account.cashBalance > 0 ||
              account.stcPayBalance > 0;
          final effectiveMethod = usesBuckets ? paymentMethod : 'bank';

          final deduction = double.tryParse(deductionCtrl.text.trim()) ?? 0;
          final requestedRecovery =
              double.tryParse(recoveryCtrl.text.trim()) ?? 0;
          final gross = row.basic + row.allowances;
          // Never recover more than is owed, nor more than what is left after
          // manual deductions.
          final maxRecovery = [
            totalOutstanding,
            gross - deduction,
          ].reduce((a, b) => a < b ? a : b);
          final recovery = requestedRecovery <= 0
              ? 0.0
              : (requestedRecovery > maxRecovery ? maxRecovery : requestedRecovery);
          final net = SalaryPaymentEntity.computeNet(
            basicSalary: row.basic,
            allowances: row.allowances,
            deductions: deduction,
            advanceRecovery: recovery,
          );
          // Mirrors the server's bucket resolution: a wallet whose cash and
          // STC buckets are both empty is spent from the total balance, so
          // validating against an empty bucket would block it wrongly.
          final usesSplitBalances =
              account.cashBalance > 0 || account.stcPayBalance > 0;
          final bucketBalance = !usesSplitBalances
              ? account.currentBalance
              : switch (effectiveMethod) {
                  'cash' => account.cashBalance,
                  'stcPay' => account.stcPayBalance,
                  _ => account.currentBalance,
                };
          final balanceLabel = usesSplitBalances
              ? _methodLabel(effectiveMethod)
              : 'Account';

          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: finDialogShape,
            title: finDialogTitle(
              'Pay Salary — ${row.employeeName}',
              icon: Icons.payments_outlined,
            ),
            content: SizedBox(
              width: 460.w,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 8.h),
                      Text(
                        'Payroll month: $monthLabel',
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          color: FinDT.textSecondary,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      DropdownButtonFormField<String>(
                        initialValue: accountId,
                        decoration: finDialogInputDecoration(
                          label: 'Pay From Account *',
                          prefixIcon: Icons.account_balance_wallet_outlined,
                        ),
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          color: FinDT.textPrimary,
                        ),
                        items: accounts
                            .map(
                              (a) => DropdownMenuItem(
                                value: a.id,
                                child: Text(
                                  '${a.name} (${fmt.format(a.currentBalance)} ${a.currency})',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: isPaying
                            ? null
                            : (v) => setInner(() => accountId = v!),
                      ),
                      if (usesBuckets) ...[
                        SizedBox(height: 14.h),
                        _buildMethodSelector(
                          selected: effectiveMethod,
                          account: account,
                          fmt: fmt,
                          enabled: !isPaying,
                          onChanged: (m) =>
                              setInner(() => paymentMethod = m),
                        ),
                        if (account.isPettyCash) ...[
                          SizedBox(height: 8.h),
                          _buildInfoStrip(
                            'Petty cash rules apply: the day\'s session must be '
                            'open and not yet verified, or the payment is rejected.',
                            Icons.info_outline,
                            FinDT.brand,
                          ),
                        ],
                      ],
                      SizedBox(height: 14.h),
                      TextFormField(
                        controller: deductionCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        onChanged: (_) => setInner(() {}),
                        decoration: finDialogInputDecoration(
                          label: 'Deductions',
                          hint: 'Absences, fines, other withholdings',
                          prefixIcon: Icons.remove_circle_outline,
                          suffixText: row.currency,
                        ),
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          color: FinDT.textPrimary,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final n = double.tryParse(v);
                          if (n == null || n < 0) return 'Enter a valid amount';
                          if (n > gross) return 'Deductions exceed gross pay';
                          return null;
                        },
                      ),
                      if (deduction > 0) ...[
                        SizedBox(height: 14.h),
                        TextFormField(
                          controller: deductionNoteCtrl,
                          decoration: finDialogInputDecoration(
                            label: 'Deduction Reason *',
                            hint: 'e.g. 2 days unpaid leave',
                            prefixIcon: Icons.description_outlined,
                          ),
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            color: FinDT.textPrimary,
                          ),
                          validator: (v) => deduction > 0 &&
                                  (v == null || v.trim().isEmpty)
                              ? 'Give a reason for the deduction'
                              : null,
                        ),
                      ],
                      if (openAdvances.isNotEmpty) ...[
                        SizedBox(height: 16.h),
                        _buildAdvancePanel(
                          advances: openAdvances,
                          totalOutstanding: totalOutstanding,
                          maxRecovery: maxRecovery,
                          controller: recoveryCtrl,
                          currency: row.currency,
                          fmt: fmt,
                          enabled: !isPaying,
                          onChanged: () => setInner(() {}),
                          onRecoverAll: () => setInner(() {
                            recoveryCtrl.text = maxRecovery <= 0
                                ? ''
                                : maxRecovery.toStringAsFixed(2);
                          }),
                        ),
                      ],
                      SizedBox(height: 16.h),
                      _buildPaySummary(
                        row: row,
                        deduction: deduction,
                        recovery: recovery,
                        net: net,
                        account: account,
                        balanceLabel: balanceLabel,
                        bucketBalance: bucketBalance,
                        fmt: fmt,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              finDialogCancelButton(ctx, onPressed: isPaying ? () {} : null),
              finDialogActionButton(
                isLoading: isPaying,
                label: net <= 0 && recovery > 0
                    ? 'Settle Against Advance'
                    : 'Pay ${fmt.format(net)} ${row.currency}',
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  if (net <= 0 && recovery <= 0) {
                    _snack(context, 'Net salary must be above zero.', FinDT.danger);
                    return;
                  }
                  if (net > bucketBalance + 1e-9) {
                    _snack(
                      context,
                      'Net pay exceeds the available $balanceLabel balance '
                      '(${fmt.format(bucketBalance)} ${account.currency}).',
                      FinDT.danger,
                    );
                    return;
                  }

                  final user = context.read<AuthProvider>().user;
                  final actorName = user?.actorLabel ?? 'Admin';
                  final fundProv = context.read<FundAccountProvider>();
                  final advanceProv = context.read<CashAdvanceProvider>();

                  setInner(() => isPaying = true);
                  try {
                    // Upsert the salary row first so the amounts being paid are
                    // exactly what the dialog shows.
                    final paymentId = row.payment?.id ??
                        SalaryPaymentEntity.buildId(
                          provider.period,
                          row.employeeId,
                        );
                    final base = row.payment;
                    final toSave = SalaryPaymentEntity(
                      id: paymentId,
                      period: provider.period,
                      employeeId: row.employeeId,
                      employeeName: row.employeeName,
                      position: row.position,
                      basicSalary: row.basic,
                      allowances: row.allowances,
                      deductions: deduction,
                      deductionNote: deductionNoteCtrl.text.trim().isEmpty
                          ? null
                          : deductionNoteCtrl.text.trim(),
                      netAmount: net,
                      netAmountMinor: (net * 100).round(),
                      currency: row.currency,
                      fundAccountId: account.id,
                      fundAccountName: account.name,
                      paymentMethod: effectiveMethod,
                      status: SalaryPaymentStatus.pending,
                      notes: base?.notes,
                      createdAt: base?.createdAt ?? DateTime.now(),
                      createdBy: base?.createdBy ?? actorName,
                    );
                    await provider.savePayment(toSave);
                    await provider.pay(
                      paymentId: paymentId,
                      fundAccountId: account.id,
                      actorName: actorName,
                      actorUserId: user?.id,
                      paymentMethod: effectiveMethod,
                      advanceRecoveries:
                          SalaryPaymentEntity.allocateAdvanceRecovery(
                        amount: recovery,
                        advances: openAdvances,
                      ),
                    );
                    await Future.wait([
                      fundProv.fetchAllAccounts(),
                      if (recovery > 0) advanceProv.load(),
                    ]);

                    if (ctx.mounted) finSafePop(ctx);
                    if (context.mounted) {
                      _snack(
                        context,
                        recovery > 0
                            ? 'Paid ${fmt.format(net)} ${row.currency} to '
                                '${row.employeeName}, recovering '
                                '${fmt.format(recovery)} against advances.'
                            : 'Paid ${fmt.format(net)} ${row.currency} to '
                                '${row.employeeName} from ${account.name}.',
                        FinDT.success,
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      setInner(() => isPaying = false);
                      _snack(context, 'Failed to pay salary: $e', FinDT.danger);
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  static String _methodLabel(String method) => switch (method) {
        'cash' => 'Cash',
        'stcPay' => 'STC Pay',
        _ => 'Account',
      };

  /// Cash vs STC Pay picker for split (petty cash style) wallets.
  Widget _buildMethodSelector({
    required String selected,
    required FundAccountEntity account,
    required NumberFormat fmt,
    required bool enabled,
    required ValueChanged<String> onChanged,
  }) {
    Widget option(String value, String label, IconData icon, double balance) {
      final isSelected = selected == value;
      return Expanded(
        child: InkWell(
          onTap: enabled ? () => onChanged(value) : null,
          borderRadius: BorderRadius.circular(10.r),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
            decoration: BoxDecoration(
              color: isSelected ? FinDT.brandLight : FinDT.bgPage,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: isSelected ? FinDT.brand : FinDT.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16.sp,
                  color: isSelected ? FinDT.brand : FinDT.textSecondary,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? FinDT.brand : FinDT.textPrimary,
                        ),
                      ),
                      Text(
                        '${fmt.format(balance)} available',
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          color: FinDT.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Paid From *',
          style: GoogleFonts.inter(
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            color: FinDT.textSecondary,
          ),
        ),
        SizedBox(height: 6.h),
        Row(
          children: [
            option('cash', 'Physical Cash', Icons.payments_outlined,
                account.cashBalance),
            SizedBox(width: 8.w),
            option('stcPay', 'STC Pay', Icons.phone_iphone_outlined,
                account.stcPayBalance),
          ],
        ),
      ],
    );
  }

  /// Outstanding advances for this employee, with how much to recover now.
  Widget _buildAdvancePanel({
    required List<CashAdvanceEntity> advances,
    required double totalOutstanding,
    required double maxRecovery,
    required TextEditingController controller,
    required String currency,
    required NumberFormat fmt,
    required bool enabled,
    required VoidCallback onChanged,
    required VoidCallback onRecoverAll,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: FinDT.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: FinDT.warning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_outlined,
                  size: 16.sp, color: FinDT.warning),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'Outstanding advances: ${fmt.format(totalOutstanding)} $currency',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: FinDT.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: enabled && maxRecovery > 0 ? onRecoverAll : null,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Recover max',
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: FinDT.brand,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          ...advances.take(3).map(
                (a) => Padding(
                  padding: EdgeInsets.only(bottom: 3.h),
                  child: Text(
                    '• ${a.purpose} — ${fmt.format(a.outstanding)} $currency left '
                    '(issued ${DateFormat('d MMM y').format(a.issuedAt)})',
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      color: FinDT.textSecondary,
                    ),
                  ),
                ),
              ),
          if (advances.length > 3)
            Text(
              '• +${advances.length - 3} more',
              style: GoogleFonts.inter(
                fontSize: 10.sp,
                color: FinDT.textMuted,
              ),
            ),
          SizedBox(height: 10.h),
          TextFormField(
            controller: controller,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            onChanged: (_) => onChanged(),
            decoration: finDialogInputDecoration(
              label: 'Recover From This Salary',
              hint: 'Leave blank to skip. Oldest advance settles first.',
              prefixIcon: Icons.undo_rounded,
              suffixText: currency,
            ),
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              color: FinDT.textPrimary,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              final n = double.tryParse(v);
              if (n == null || n < 0) return 'Enter a valid amount';
              if (n > maxRecovery + 1e-9) {
                return 'At most ${fmt.format(maxRecovery)} can be recovered now';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoStrip(String message, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14.sp, color: color),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 10.sp,
                color: FinDT.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaySummary({
    required _PayrollRow row,
    required double deduction,
    required double recovery,
    required double net,
    required FundAccountEntity account,
    required String balanceLabel,
    required double bucketBalance,
    required NumberFormat fmt,
  }) {
    Widget line(String label, String value, {bool bold = false, Color? color}) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 3.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.sp,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: bold ? FinDT.textPrimary : FinDT.textSecondary,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: bold ? 13.sp : 11.sp,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: color ?? FinDT.textPrimary,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: FinDT.bgPage,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: FinDT.border),
      ),
      child: Column(
        children: [
          line('Basic', '${fmt.format(row.basic)} ${row.currency}'),
          line('Allowances', '${fmt.format(row.allowances)} ${row.currency}'),
          line(
            'Deductions',
            '− ${fmt.format(deduction)} ${row.currency}',
            color: deduction > 0 ? FinDT.danger : null,
          ),
          line(
            'Advance recovery',
            '− ${fmt.format(recovery)} ${row.currency}',
            color: recovery > 0 ? FinDT.warning : null,
          ),
          Divider(height: 14.h, color: FinDT.border),
          line('Net pay', '${fmt.format(net)} ${row.currency}', bold: true),
          SizedBox(height: 6.h),
          line(
            '$balanceLabel balance after',
            '${fmt.format(bucketBalance - net)} ${account.currency}',
            color: bucketBalance - net < 0 ? FinDT.danger : null,
          ),
          if (recovery > 0) ...[
            SizedBox(height: 8.h),
            Text(
              'The recovered amount never leaves the wallet — it settles the '
              'advance instead.',
              style: GoogleFonts.inter(
                fontSize: 10.sp,
                color: FinDT.textMuted,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }


  Future<void> _showVoidDialog(
    BuildContext context,
    SalaryProvider provider,
    SalaryPaymentEntity payment,
  ) async {
    if (!_guardPermission(context)) return;

    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isVoiding = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: finDialogShape,
          title: finDialogTitle(
            'Void Salary Payment',
            icon: Icons.undo_rounded,
            iconColor: FinDT.danger,
          ),
          content: SizedBox(
            width: 400.w,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${payment.netAmount.toStringAsFixed(2)} ${payment.currency} '
                    'paid to ${payment.employeeName} will be returned to '
                    '${payment.fundAccountName ?? 'the fund account'}.',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: FinDT.textSecondary,
                    ),
                  ),
                  SizedBox(height: 14.h),
                  TextFormField(
                    controller: reasonCtrl,
                    decoration: finDialogInputDecoration(
                      label: 'Reason *',
                      hint: 'e.g. paid twice by mistake',
                      prefixIcon: Icons.description_outlined,
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: FinDT.textPrimary,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Reason required'
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            finDialogCancelButton(ctx, onPressed: isVoiding ? () {} : null),
            finDialogActionButton(
              isLoading: isVoiding,
              label: 'Void Payment',
              backgroundColor: FinDT.danger,
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final user = context.read<AuthProvider>().user;
                final fundProv = context.read<FundAccountProvider>();
                setInner(() => isVoiding = true);
                try {
                  await provider.voidPayment(
                    paymentId: payment.id,
                    reason: reasonCtrl.text.trim(),
                    actorName: user?.actorLabel ?? 'Admin',
                    actorUserId: user?.id,
                  );
                  await fundProv.fetchAllAccounts();
                  if (ctx.mounted) finSafePop(ctx);
                  if (context.mounted) {
                    _snack(context, 'Salary payment voided.', FinDT.success);
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    setInner(() => isVoiding = false);
                    _snack(context, 'Failed to void: $e', FinDT.danger);
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────

  bool _guardPermission(BuildContext context) {
    if (_canManage) return true;
    _snack(
      context,
      'Your role is not allowed to manage salaries.',
      FinDT.danger,
    );
    return false;
  }

  void _snack(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 12.sp),
        ),
        backgroundColor: color,
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts[1].characters.first)
        .toUpperCase();
  }
}
