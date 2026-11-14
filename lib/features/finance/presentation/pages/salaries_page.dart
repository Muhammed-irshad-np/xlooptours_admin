import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../../widgets/searchable_dropdown.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../employee/domain/entities/employee_entity.dart';
import '../../../employee/domain/entities/employee_role_entity.dart';
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

/// Which list the page shows: staff payroll or the month's external staff.
enum _SalaryTab { payroll, trips }

/// One line of the monthly payroll: an employee on the payroll (or an external
/// driver), together with this month's payment row when it already exists.
class _PayrollRow {
  final String employeeId;
  final String employeeName;

  /// The employee's unique code (EMP#X1001), read live from the employee
  /// record; null when the employee has none or no longer exists.
  final String? employeeCode;
  final String position;
  final SalaryPaymentKind kind;
  final SalaryStructureEntity? structure;
  final SalaryPaymentEntity? payment;

  const _PayrollRow({
    required this.employeeId,
    required this.employeeName,
    this.employeeCode,
    required this.position,
    this.kind = SalaryPaymentKind.salary,
    this.structure,
    this.payment,
  });

  bool get isTrip => kind == SalaryPaymentKind.tripSettlement;

  /// Basic salary, or the month's earnings for an external employee.
  double get basic => payment?.basicSalary ?? structure?.basicSalary ?? 0;
  int? get tripCount => payment?.tripCount;
  double get allowances => payment?.allowances ?? structure?.allowances ?? 0;
  double get extraAllowance => payment?.extraAllowance ?? 0;
  int get leaveDays => payment?.leaveDays ?? 0;
  double get leaveDeduction => payment?.leaveDeduction ?? 0;
  double get deductions => payment?.deductions ?? 0;
  double get advanceRecovery => payment?.advanceRecovery ?? 0;

  /// Everything held back from gross pay: unpaid leave, manual deductions and
  /// any amount recovered against outstanding advances.
  double get withheld => leaveDeduction + deductions + advanceRecovery;
  double get net =>
      payment?.netAmount ??
      SalaryPaymentEntity.computeNet(
        basicSalary: basic,
        allowances: allowances,
        extraAllowance: extraAllowance,
      );
  String get currency => payment?.currency ?? structure?.currency ?? 'SAR';
}

/// Monthly staff payroll, paid in two steps: a finalizer sets each month's
/// amounts and fund account and finalizes them, then a payer (coordinator)
/// pays the finalized amount. Who may do each step is set in Finance Master
/// Data. A second tab holds external staff, who have no fixed salary: the
/// finalizer adds whoever worked this month, so every month starts empty.
class SalariesPage extends StatefulWidget {
  const SalariesPage({super.key});

  @override
  State<SalariesPage> createState() => _SalariesPageState();
}

class _SalariesPageState extends State<SalariesPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _statusFilter = 'ALL';
  _SalaryTab _tab = _SalaryTab.payroll;

  bool get _isTrips => _tab == _SalaryTab.trips;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SalaryProvider>().load();
      context.read<EmployeeProvider>().fetchAllEmployees();
      context.read<FundAccountProvider>().fetchAllAccounts();
      // Needed to offer advance recovery when paying a salary.
      context.read<CashAdvanceProvider>().load();
      // Holds which accounts salaries and trip payments may use.
      final finProv = context.read<FinanceProvider>();
      if (!finProv.isPolicyLoaded) finProv.fetchFinancePolicy();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Active accounts the Master Data payroll settings allow for [kind]. An
  /// empty setting allows every active account.
  List<FundAccountEntity> _payrollAccounts(SalaryPaymentKind kind) {
    final policy = context.read<FinanceProvider>().policy;
    final allowed = kind == SalaryPaymentKind.tripSettlement
        ? policy.tripPaymentAccountIds
        : policy.salaryAccountIds;
    final active = context.read<FundAccountProvider>().activeAccounts;
    if (allowed.isEmpty) return active;
    return active.where((a) => allowed.contains(a.id)).toList();
  }

  /// Step 1: manage the payroll, set the month's amounts, finalize, reopen
  /// and void.
  bool get _canFinalize => FinancePermissionService.canFinalizeSalaries(
        user: context.read<AuthProvider>().user,
        policy: context.read<FinanceProvider>().policy,
      );

  /// Step 2: pay what has been finalized.
  bool get _canPay => FinancePermissionService.canPaySalaries(
        user: context.read<AuthProvider>().user,
        policy: context.read<FinanceProvider>().policy,
      );

  /// Employees that can be put on the payroll: active internal staff only.
  List<EmployeeEntity> _payrollEligibleEmployees() {
    return context
        .read<EmployeeProvider>()
        .employees
        .where((e) => e.isActive && e.canHoldCompanyRecords)
        .toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  /// Active external staff not yet on [provider]'s month, drivers first.
  List<EmployeeEntity> _externalStaffNotInMonth(SalaryProvider provider) {
    final inMonth = provider.tripPayments.map((p) => p.employeeId).toSet();
    return context
        .read<EmployeeProvider>()
        .employees
        .where((e) => e.isActive && e.isExternal && !inMonth.contains(e.id))
        .toList()
      ..sort((a, b) {
        if (a.isDriver != b.isDriver) return a.isDriver ? -1 : 1;
        return a.fullName.compareTo(b.fullName);
      });
  }

  /// Employee codes by employee id, for showing and searching salary rows.
  Map<String, String> _employeeCodes() => {
        for (final e in context.read<EmployeeProvider>().employees)
          if (e.employeeCode != null) e.id: e.employeeCode!,
      };

  /// "Name · EMP#X1001 · Position" for the employee pickers.
  static String _employeeLabel(EmployeeEntity e) => [
        e.fullName,
        if (e.employeeCode != null) e.employeeCode!,
        if (e.position.isNotEmpty) e.position,
      ].join(' · ');

  List<_PayrollRow> _buildRows(SalaryProvider provider) =>
      _isTrips ? _buildTripRows(provider) : _buildPayrollRows(provider);

  /// Only the people the finalizer added to this month — external staff
  /// change from month to month, so a new month starts with an empty list.
  List<_PayrollRow> _buildTripRows(SalaryProvider provider) {
    final rows = <_PayrollRow>[];
    final codes = _employeeCodes();
    for (final p in provider.tripPayments) {
      rows.add(
        _PayrollRow(
          employeeId: p.employeeId,
          employeeName: p.employeeName,
          employeeCode: codes[p.employeeId],
          position: p.position,
          kind: SalaryPaymentKind.tripSettlement,
          payment: p,
        ),
      );
    }

    rows.sort((a, b) => a.employeeName.compareTo(b.employeeName));
    return rows;
  }

  List<_PayrollRow> _buildPayrollRows(SalaryProvider provider) {
    final rows = <_PayrollRow>[];
    final seen = <String>{};
    final codes = _employeeCodes();

    for (final s in provider.structures) {
      if (!s.isActive) continue;
      seen.add(s.employeeId);
      rows.add(
        _PayrollRow(
          employeeId: s.employeeId,
          employeeName: s.employeeName,
          employeeCode: codes[s.employeeId],
          position: s.position,
          structure: s,
          payment: provider.paymentFor(s.employeeId),
        ),
      );
    }

    // Salary rows whose employee was since taken off the payroll still belong
    // to the month's history.
    for (final p in provider.salaryPayments) {
      if (seen.contains(p.employeeId)) continue;
      rows.add(
        _PayrollRow(
          employeeId: p.employeeId,
          employeeName: p.employeeName,
          employeeCode: codes[p.employeeId],
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
      // No payment row yet counts as pending — nothing has been finalized.
      final isPending = status == null || status == SalaryPaymentStatus.pending;
      if (_statusFilter == 'PENDING' && !isPending) return false;
      if (_statusFilter == 'FINALIZED' &&
          status != SalaryPaymentStatus.finalized) {
        return false;
      }
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
        final codeMatch =
            (r.employeeCode ?? '').toLowerCase().contains(q);
        if (!nameMatch && !posMatch && !codeMatch) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');

    // Employees are watched too: the trips tab lists drivers straight from
    // the employee records, which may finish loading after the payroll.
    context.watch<EmployeeProvider>();

    return Consumer<SalaryProvider>(
      builder: (context, provider, _) {
        final rows = _buildRows(provider);
        final filtered = _filterRows(rows);
        // Open advances per employee, shown on each row as "Advance pending".
        final advancesOwed = _openAdvancesByEmployee(
          context.watch<CashAdvanceProvider>().advances,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTabSwitcher(provider),
            SizedBox(height: 12.h),
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
                itemBuilder: (_, i) => _buildSalaryCard(
                  context,
                  provider,
                  filtered[i],
                  fmt,
                  advancesOwed[filtered[i].employeeId],
                ),
              ),
          ],
        );
      },
    );
  }

  // ─── Toolbar ────────────────────────────────────────────────

  Widget _buildTabSwitcher(SalaryProvider provider) {
    Widget tab(_SalaryTab value, String label, IconData icon, int count) {
      final isSelected = _tab == value;
      return InkWell(
        onTap: () => setState(() => _tab = value),
        borderRadius: BorderRadius.circular(10.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
          decoration: BoxDecoration(
            color: isSelected ? FinDT.brand : Colors.white,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: isSelected ? FinDT.brand : FinDT.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15.sp,
                color: isSelected ? Colors.white : FinDT.textSecondary,
              ),
              SizedBox(width: 8.w),
              Text(
                '$label ($count)',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : FinDT.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        tab(
          _SalaryTab.payroll,
          'Staff Payroll',
          Icons.badge_outlined,
          provider.activeStructures.length,
        ),
        SizedBox(width: 8.w),
        tab(
          _SalaryTab.trips,
          'External Staff',
          Icons.local_taxi_outlined,
          provider.tripPayments.length,
        ),
      ],
    );
  }

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
            child: Icon(
              _isTrips ? Icons.local_taxi_outlined : Icons.badge_outlined,
              size: 20.sp,
              color: FinDT.brand,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isTrips
                      ? 'External Staff — Monthly Payments'
                      : 'Payroll & Salaries',
                  style: GoogleFonts.inter(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: FinDT.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  _isTrips
                      ? 'Add who worked this month and finalize their amount — the coordinator then pays'
                      : 'Finalize each salary for the month — the coordinator then pays it from the chosen account',
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
            onPressed:
                (_isTrips ? provider.tripPayments : provider.salaryPayments)
                    .isEmpty
                ? null
                : () async {
                    await FinanceExportService.shareCsv(
                      fileName: _isTrips
                          ? 'driver_trips_${provider.period}.csv'
                          : 'salaries_${provider.period}.csv',
                      csvContent: FinanceExportService.salariesToCsv(
                        _isTrips
                            ? provider.tripPayments
                            : provider.salaryPayments,
                        employeeCodes: _employeeCodes(),
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
          if (_canFinalize) ...[
            SizedBox(width: 8.w),
            OutlinedButton.icon(
              onPressed: () => _isTrips
                  ? _showAddExternalDialog(context, provider)
                  : _showStructureDialog(context),
              icon: Icon(Icons.person_add_alt_1_outlined, size: 15.sp),
              label: Text(
                _isTrips ? 'Add to This Month' : 'Add to Payroll',
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
        ],
      ),
    );
  }

  /// Pending pay once each unpaid employee's open advances are recovered from
  /// it. An advance can only be recovered up to what that employee is owed, so
  /// one person's large advance never reduces another's pending pay.
  ({double gross, double afterAdvances, double advances}) _pendingTotals(
    List<_PayrollRow> unpaidRows,
  ) {
    final advances = context
        .watch<CashAdvanceProvider>()
        .advances
        .where((a) => a.isOpen)
        .toList();
    var gross = 0.0;
    var after = 0.0;
    var recovered = 0.0;
    for (final r in unpaidRows) {
      final owed = SalaryPaymentEntity.totalOutstanding(
        advances.where((a) => a.employeeId == r.employeeId).toList(),
      );
      // A row already carrying a recovery has had it taken off its net, and a
      // finalized row's net is locked whatever it recovers.
      final locked = r.advanceRecovery > 0 ||
          r.payment?.status == SalaryPaymentStatus.finalized;
      final recoverable = locked ? 0.0 : owed;
      final take = recoverable < r.net ? recoverable : r.net;
      gross += r.net;
      after += r.net - take;
      recovered += take;
    }
    return (gross: gross, afterAdvances: after, advances: recovered);
  }

  Widget _buildKpiRow(
    SalaryProvider provider,
    List<_PayrollRow> rows,
    NumberFormat fmt,
  ) {
    if (_isTrips) return _buildTripKpiRow(provider, rows, fmt);

    // "Pending" is computed live from the payroll list, not from generated
    // rows — an employee who hasn't been paid yet this month counts as
    // pending whether or not a salary_payments row exists for them.
    final unpaidRows = rows
        .where((r) => r.payment?.status != SalaryPaymentStatus.paid)
        .toList();
    final pending = _pendingTotals(unpaidRows);
    final totalPending = pending.gross;
    final currency = rows.isEmpty ? 'SAR' : rows.first.currency;
    final readyToPay = unpaidRows
        .where((r) => r.payment?.status == SalaryPaymentStatus.finalized)
        .length;

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
              subtitle: '${unpaidRows.length - readyToPay} to finalize · '
                  '$readyToPay ready to pay',
              icon: Icons.schedule_outlined,
              color: FinDT.warning,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _buildKpiCard(
              title: 'Pending After Advances',
              value: fmt.format(pending.afterAdvances),
              subtitle: '${fmt.format(pending.advances)} advances deducted',
              icon: Icons.account_balance_wallet_outlined,
              color: FinDT.brand,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripKpiRow(
    SalaryProvider provider,
    List<_PayrollRow> rows,
    NumberFormat fmt,
  ) {
    final unclosedRows = rows
        .where((r) => r.payment?.status != SalaryPaymentStatus.paid)
        .toList();
    final notFinalized = rows
        .where((r) =>
            r.payment == null ||
            r.payment!.status == SalaryPaymentStatus.pending)
        .length;
    final readyToPay = unclosedRows.length - notFinalized;
    final pending = _pendingTotals(unclosedRows);
    final driverIds = rows.map((r) => r.employeeId).toSet();
    final driverAdvances = context
        .watch<CashAdvanceProvider>()
        .advances
        .where((a) => a.isOpen && driverIds.contains(a.employeeId))
        .toList();
    final outstanding = SalaryPaymentEntity.totalOutstanding(driverAdvances);
    final currency = rows.isEmpty ? 'SAR' : rows.first.currency;

    return SizedBox(
      height: 96.h,
      child: Row(
        children: [
          Expanded(
            child: _buildKpiCard(
              title: 'Not Finalized',
              value: '$notFinalized',
              subtitle: 'of ${rows.length} added this month',
              icon: Icons.schedule_outlined,
              color: FinDT.warning,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _buildKpiCard(
              title: 'Paid This Month',
              value: fmt.format(provider.totalTripPaid),
              subtitle: '${provider.paidTripPayments.length} people paid',
              icon: Icons.check_circle_outline,
              color: FinDT.success,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _buildKpiCard(
              title: 'Total Pending',
              value: fmt.format(pending.gross),
              subtitle: '$readyToPay ready to pay',
              icon: Icons.hourglass_empty_outlined,
              color: FinDT.warning,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _buildKpiCard(
              title: 'Pending After Advances',
              value: fmt.format(pending.afterAdvances),
              subtitle: '${fmt.format(outstanding)} $currency open advances',
              icon: Icons.account_balance_outlined,
              color: FinDT.brand,
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
                hint: 'Name, employee code or position',
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
                    label: 'Finalized',
                    count: countOf(SalaryPaymentStatus.finalized),
                    value: 'FINALIZED',
                    color: FinDT.brand,
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
          Icon(
            _isTrips ? Icons.local_taxi_outlined : Icons.badge_outlined,
            size: 40.sp,
            color: FinDT.textMuted,
          ),
          SizedBox(height: 12.h),
          Text(
            !payrollEmpty
                ? 'Nothing matches this filter'
                : _isTrips
                    ? 'No one added for this month'
                    : 'No one on the payroll yet',
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: FinDT.textPrimary,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            !payrollEmpty
                ? 'Try another status or clear the search.'
                : _isTrips
                ? 'Use "Add to This Month" to add the external staff who worked this month, or create a new one.'
                : 'Use "Add to Payroll" to set an employee\'s monthly salary.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textSecondary),
          ),
        ],
      ),
    );
  }

  // ─── Salary row ─────────────────────────────────────────────

  /// Outstanding balance and number of open advances, per employee.
  static Map<String, ({double owed, int count})> _openAdvancesByEmployee(
    List<CashAdvanceEntity> advances,
  ) {
    final out = <String, ({double owed, int count})>{};
    for (final a in advances) {
      if (!a.isOpen || a.outstanding <= 0) continue;
      final prev = out[a.employeeId];
      out[a.employeeId] = (
        owed: (prev?.owed ?? 0) + a.outstanding,
        count: (prev?.count ?? 0) + 1,
      );
    }
    return out;
  }

  Widget _buildSalaryCard(
    BuildContext context,
    SalaryProvider provider,
    _PayrollRow row,
    NumberFormat fmt,
    ({double owed, int count})? advances,
  ) {
    final payment = row.payment;
    final status = payment?.status;
    // No payment row yet reads the same as pending — nothing finalized yet.
    final statusColor = switch (status) {
      null || SalaryPaymentStatus.pending => FinDT.warning,
      SalaryPaymentStatus.finalized => FinDT.brand,
      SalaryPaymentStatus.paid => FinDT.success,
      SalaryPaymentStatus.voided => FinDT.danger,
    };
    final statusLabel = switch (status) {
      SalaryPaymentStatus.finalized => 'Ready to Pay',
      _ => status?.displayName ?? 'Pending',
    };
    // An external row added to the month has no amount until it's finalized.
    final hasAmount = !row.isTrip ||
        (payment != null &&
            (payment.status != SalaryPaymentStatus.pending ||
                payment.basicSalary > 0));

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
                Text.rich(
                  TextSpan(
                    children: [
                      if (row.employeeCode != null) ...[
                        TextSpan(
                          text: row.employeeCode,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                            color: FinDT.brand,
                          ),
                        ),
                        const TextSpan(text: ' · '),
                      ],
                      TextSpan(
                        text: row.position.isEmpty ? '—' : row.position,
                      ),
                    ],
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    color: FinDT.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (row.isTrip) ...[
            Expanded(
              flex: 2,
              child: _amountCell(
                'Earnings',
                hasAmount ? fmt.format(row.basic) : '—',
                hasAmount ? row.currency : '',
                note: row.tripCount != null ? '${row.tripCount} trips' : null,
              ),
            ),
            Expanded(
              flex: 2,
              child: _amountCell(
                'Extra',
                fmt.format(row.extraAllowance),
                row.currency,
              ),
            ),
          ] else ...[
            Expanded(
              flex: 2,
              child: _amountCell('Basic', fmt.format(row.basic), row.currency),
            ),
            Expanded(
              flex: 2,
              child: _amountCell(
                'Allowances',
                fmt.format(row.allowances + row.extraAllowance),
                row.currency,
                note: row.extraAllowance > 0
                    ? 'incl. ${fmt.format(row.extraAllowance)} extra'
                    : null,
              ),
            ),
          ],
          Expanded(
            flex: 2,
            child: _amountCell(
              'Advance pending',
              fmt.format(advances?.owed ?? 0),
              row.currency,
              color: (advances?.owed ?? 0) > 0 ? FinDT.warning : FinDT.textMuted,
              note: [
                if (advances != null)
                  '${advances.count} open '
                      '${advances.count == 1 ? 'advance' : 'advances'}',
                // Recovery already set on an unpaid row comes off this
                // balance when it is paid.
                if (row.advanceRecovery > 0 &&
                    row.payment?.status != SalaryPaymentStatus.paid &&
                    row.payment?.status != SalaryPaymentStatus.voided)
                  '${fmt.format(row.advanceRecovery)} recovering this month',
              ].join('\n'),
            ),
          ),
          Expanded(
            flex: 2,
            child: _amountCell(
              'Withheld',
              fmt.format(row.withheld),
              row.currency,
              color: row.withheld > 0 ? FinDT.danger : null,
              note: [
                if (row.advanceRecovery > 0)
                  'incl. ${fmt.format(row.advanceRecovery)} advance',
                if (row.deductions > 0 &&
                    (row.payment?.deductionNote ?? '').isNotEmpty)
                  'Deduction: ${row.payment!.deductionNote}',
              ].join('\n'),
            ),
          ),
          Expanded(
            flex: 2,
            child: _amountCell(
              'Net pay',
              hasAmount ? fmt.format(row.net) : '—',
              hasAmount ? row.currency : '',
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
                if (payment?.status == SalaryPaymentStatus.finalized) ...[
                  SizedBox(height: 4.h),
                  Text(
                    'From ${payment!.fundAccountName ?? 'account'}\n'
                    'Finalized by ${payment.finalizedBy ?? '—'}',
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      color: FinDT.textMuted,
                    ),
                  ),
                ],
                if (payment?.status == SalaryPaymentStatus.paid) ...[
                  SizedBox(height: 4.h),
                  Text(
                    '${payment!.fundAccountName ?? 'Account'} · '
                    '${DateFormat('d MMM').format(payment.paidAt ?? payment.createdAt)}'
                    '${payment.paidBy != null ? '\nPaid by ${payment.paidBy}' : ''}',
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
        if (note != null && note.isNotEmpty)
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
    final status = payment?.status ?? SalaryPaymentStatus.pending;
    final canFinalize = _canFinalize;
    final canPay = _canPay;

    final menu = <PopupMenuEntry<String>>[
      if (canFinalize) ...[
        if (row.structure != null && !row.isTrip)
          const PopupMenuItem(value: 'edit', child: Text('Edit salary')),
        if (status.canReopen)
          const PopupMenuItem(
            value: 'reopen',
            child: Text('Reopen to change amounts'),
          ),
        if (payment != null && status.canDelete)
          const PopupMenuItem(
            value: 'delete',
            child: Text('Remove from this month'),
          ),
        if (status.canVoid)
          const PopupMenuItem(
            value: 'void',
            child: Text('Void payment'),
          ),
        if (row.structure != null && !row.isTrip)
          const PopupMenuItem(
            value: 'off_payroll',
            child: Text('Take off payroll'),
          ),
      ],
    ];

    Widget? primary;
    if (status.canFinalize && canFinalize) {
      primary = finDialogActionButton(
        onPressed: () => _showFinalizeDialog(context, provider, row),
        label: 'Finalize',
        icon: Icons.fact_check_outlined,
      );
    } else if (status.canPay && canPay) {
      primary = finDialogActionButton(
        onPressed: () => _showPayDialog(context, provider, row),
        label: 'Pay',
        icon: Icons.payments_outlined,
      );
    } else if (status.canFinalize) {
      primary = _waitingLabel('Awaiting finalize');
    } else if (status.canPay) {
      primary = _waitingLabel('Awaiting payment');
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (primary != null) primary,
        if (menu.isNotEmpty)
          PopupMenuButton<String>(
            tooltip: 'More',
            icon:
                Icon(Icons.more_vert, size: 18.sp, color: FinDT.textSecondary),
            itemBuilder: (_) => menu,
            onSelected: (action) =>
                _handleRowAction(context, provider, row, action),
          )
        else
          SizedBox(width: 40.w),
      ],
    );
  }

  /// Shown in place of an action button the viewer isn't allowed to press.
  Widget _waitingLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 11.sp,
        fontWeight: FontWeight.w600,
        color: FinDT.textMuted,
      ),
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
      case 'reopen':
        await _reopenPayment(context, provider, row);
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

  Future<void> _reopenPayment(
    BuildContext context,
    SalaryProvider provider,
    _PayrollRow row,
  ) async {
    if (!_guardFinalize(context)) return;
    final confirmed = await showFinConfirmationDialog(
      context: context,
      title: 'Reopen ${row.isTrip ? 'Payment' : 'Salary'}',
      icon: Icons.lock_open_outlined,
      message:
          '${row.employeeName}\'s ${row.isTrip ? 'payment' : 'salary'} goes back '
          'to Pending so you can change the amounts. It can\'t be paid until '
          'you finalize it again.',
      confirmLabel: 'Reopen',
    );
    if (confirmed != true || !context.mounted) return;

    final user = context.read<AuthProvider>().user;
    try {
      await provider.reopen(
        paymentId: row.payment!.id,
        actorName: user?.actorLabel ?? 'Admin',
        actorUserId: user?.id,
      );
      if (context.mounted) {
        _snack(context, 'Reopened — finalize it again when ready.',
            FinDT.success);
      }
    } catch (e) {
      if (context.mounted) _snack(context, 'Failed: $e', FinDT.danger);
    }
  }

  Future<void> _deletePendingPayment(
    BuildContext context,
    SalaryProvider provider,
    _PayrollRow row,
  ) async {
    if (!_guardFinalize(context)) return;
    final confirmed = await showFinConfirmationDialog(
      context: context,
      title: 'Remove From This Month',
      icon: Icons.delete_outline_rounded,
      iconColor: FinDT.danger,
      confirmColor: FinDT.danger,
      message: row.isTrip
          ? 'Remove ${row.employeeName} from this month\'s external staff? '
                'Nothing has been paid. You can add them again later.'
          : 'Remove ${row.employeeName}\'s unpaid salary for this month? '
                'Nothing has been paid. You can finalize it again later.',
      confirmLabel: 'Remove',
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await provider.deletePayment(row.payment!.id);
      if (context.mounted) {
        _snack(
          context,
          '${row.employeeName} removed from this month.',
          FinDT.success,
        );
      }
    } catch (e) {
      if (context.mounted) _snack(context, 'Failed: $e', FinDT.danger);
    }
  }

  Future<void> _takeOffPayroll(
    BuildContext context,
    SalaryProvider provider,
    _PayrollRow row,
  ) async {
    if (!_guardFinalize(context)) return;
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
    if (!_guardFinalize(context)) return;

    final provider = context.read<SalaryProvider>();
    final accounts = _payrollAccounts(SalaryPaymentKind.salary);
    if (accounts.isEmpty) {
      _snack(
        context,
        'No salary account available — create an active fund account or '
        'pick salary accounts in Master Data.',
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
                                  child: Text(_employeeLabel(e)),
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

  /// Step 1 — finalize one salary (or an external employee's month): set the
  /// month's amounts, the advance recovery and the account it is paid from.
  /// Nothing is paid here; the payer does that afterwards.
  Future<void> _showFinalizeDialog(
    BuildContext context,
    SalaryProvider provider,
    _PayrollRow row,
  ) async {
    if (!_guardFinalize(context)) return;

    final allAccounts = _payrollAccounts(row.kind);
    final accounts =
        allAccounts.where((a) => a.currency == row.currency).toList();
    if (accounts.isEmpty) {
      _snack(
        context,
        'No ${row.isTrip ? 'trip payment' : 'salary'} account in '
        '${row.currency} to pay this from — check Payroll Accounts in '
        'Master Data.',
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
    final extraCtrl = TextEditingController(
      text: row.extraAllowance > 0 ? row.extraAllowance.toStringAsFixed(2) : '',
    );
    final extraNoteCtrl =
        TextEditingController(text: row.payment?.extraAllowanceNote ?? '');
    // A reopened row keeps the recovery it was finalized with.
    final recoveryCtrl = TextEditingController(
      text: row.advanceRecovery > 0
          ? row.advanceRecovery.toStringAsFixed(2)
          : '',
    );
    // Salary only: unpaid leave days, each costing a day's pay.
    final leaveDaysCtrl = TextEditingController(
      text: row.leaveDays > 0 ? row.leaveDays.toString() : '',
    );
    // External staff only: the month's earnings are typed in each month.
    final tripAmountCtrl = TextEditingController(
      text: row.isTrip && row.basic > 0 ? row.basic.toStringAsFixed(2) : '',
    );
    final tripCountCtrl = TextEditingController(
      text: row.tripCount?.toString() ?? '',
    );

    String accountId = row.payment?.fundAccountId ??
        row.structure?.defaultFundAccountId ??
        accounts.first.id;
    if (accounts.every((a) => a.id != accountId)) accountId = accounts.first.id;
    bool isPaying = false;

    final fmt = NumberFormat('#,##0.00');
    final monthLabel = DateFormat('MMMM y').format(provider.periodDate);
    // Leave is charged per calendar day of this month (28–31).
    final daysInMonth = SalaryPaymentEntity.daysInPeriod(provider.period);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) {
          final account = accounts.firstWhere(
            (a) => a.id == accountId,
            orElse: () => accounts.first,
          );

          final extra = double.tryParse(extraCtrl.text.trim()) ?? 0;
          final deduction = double.tryParse(deductionCtrl.text.trim()) ?? 0;
          final requestedRecovery =
              double.tryParse(recoveryCtrl.text.trim()) ?? 0;
          final basic = row.isTrip
              ? double.tryParse(tripAmountCtrl.text.trim()) ?? 0
              : row.basic;
          final gross = basic + row.allowances + extra;
          final leaveDays = row.isTrip
              ? 0
              : int.tryParse(leaveDaysCtrl.text.trim()) ?? 0;
          final dailyRate = SalaryPaymentEntity.dailyRate(
            basicSalary: basic,
            allowances: row.allowances,
            daysInMonth: daysInMonth,
          );
          final leaveDeduction = SalaryPaymentEntity.leaveDeductionFor(
            basicSalary: basic,
            allowances: row.allowances,
            leaveDays: leaveDays,
            daysInMonth: daysInMonth,
          );
          // Never recover more than is owed, nor more than what is left after
          // leave and manual deductions.
          final maxRecovery = [
            totalOutstanding,
            gross - leaveDeduction - deduction,
          ].reduce((a, b) => a < b ? a : b);
          final recovery = requestedRecovery <= 0
              ? 0.0
              : (requestedRecovery > maxRecovery ? maxRecovery : requestedRecovery);
          final net = SalaryPaymentEntity.computeNet(
            basicSalary: basic,
            allowances: row.allowances,
            extraAllowance: extra,
            leaveDeduction: leaveDeduction,
            deductions: deduction,
            advanceRecovery: recovery,
          );

          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: finDialogShape,
            title: finDialogTitle(
              'Finalize — ${row.employeeName}',
              icon: Icons.fact_check_outlined,
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
                        'Month: $monthLabel',
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          color: FinDT.textSecondary,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      _buildInfoStrip(
                        'Finalizing locks these amounts and the account. The '
                        'coordinator then pays it and can\'t change anything — '
                        'reopen it if a figure needs to change.',
                        Icons.lock_outline,
                        FinDT.brand,
                      ),
                      SizedBox(height: 12.h),
                      DropdownButtonFormField<String>(
                        initialValue: accountId,
                        decoration: finDialogInputDecoration(
                          label: 'Pay From Account *',
                          hint: 'The coordinator pays from this account',
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
                      if (row.isTrip) ...[
                        SizedBox(height: 14.h),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: tripAmountCtrl,
                                enabled: !isPaying,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d*'),
                                  ),
                                ],
                                onChanged: (_) => setInner(() {}),
                                decoration: finDialogInputDecoration(
                                  label: 'Earnings This Month *',
                                  hint: 'Trips / work done this month',
                                  prefixIcon: Icons.local_taxi_outlined,
                                  suffixText: row.currency,
                                ),
                                style: GoogleFonts.inter(
                                  fontSize: 12.sp,
                                  color: FinDT.textPrimary,
                                ),
                                validator: (v) {
                                  final n = double.tryParse(v ?? '');
                                  if (n == null || n <= 0) {
                                    return 'Enter what they earned this month';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: tripCountCtrl,
                                enabled: !isPaying,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: finDialogInputDecoration(
                                  label: 'No. of Trips',
                                  hint: 'Optional',
                                  prefixIcon: Icons.tag,
                                ),
                                style: GoogleFonts.inter(
                                  fontSize: 12.sp,
                                  color: FinDT.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        _buildInfoStrip(
                          'No receipt needed — this record is the proof of '
                          'payment.',
                          Icons.receipt_long_outlined,
                          FinDT.textSecondary,
                        ),
                      ],
                      SizedBox(height: 14.h),
                      TextFormField(
                        controller: extraCtrl,
                        enabled: !isPaying,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        onChanged: (_) => setInner(() {}),
                        decoration: finDialogInputDecoration(
                          label: row.isTrip
                              ? 'Extra Amount (this month)'
                              : 'Extra Allowance (this month)',
                          hint: row.isTrip
                              ? 'Waiting time, parking, tolls…'
                              : 'Bonus, overtime, Eid allowance…',
                          prefixIcon: Icons.add_circle_outline,
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
                          return null;
                        },
                      ),
                      if (extra > 0) ...[
                        SizedBox(height: 14.h),
                        TextFormField(
                          controller: extraNoteCtrl,
                          enabled: !isPaying,
                          decoration: finDialogInputDecoration(
                            label: row.isTrip
                                ? 'Extra Amount Reason *'
                                : 'Extra Allowance Reason *',
                            hint: 'e.g. Overtime – September',
                            prefixIcon: Icons.description_outlined,
                          ),
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            color: FinDT.textPrimary,
                          ),
                          validator: (v) => extra > 0 &&
                                  (v == null || v.trim().isEmpty)
                              ? 'Give a reason for the extra amount'
                              : null,
                        ),
                      ],
                      if (!row.isTrip) ...[
                        SizedBox(height: 14.h),
                        TextFormField(
                          controller: leaveDaysCtrl,
                          enabled: !isPaying,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) => setInner(() {}),
                          decoration: finDialogInputDecoration(
                            label: 'Leave Days (unpaid)',
                            hint: 'Days of unpaid leave this month',
                            prefixIcon: Icons.event_busy_outlined,
                            suffixText: leaveDays > 0
                                ? '− ${fmt.format(leaveDeduction)} ${row.currency}'
                                : 'days',
                          ),
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            color: FinDT.textPrimary,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final n = int.tryParse(v);
                            if (n == null || n < 0) return 'Enter a valid number';
                            if (n > daysInMonth) {
                              return 'At most $daysInMonth days in $monthLabel';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          'One day = ${fmt.format(dailyRate)} ${row.currency} '
                          '(basic + allowances ÷ $daysInMonth days '
                          'in $monthLabel)',
                          style: GoogleFonts.inter(
                            fontSize: 10.sp,
                            color: FinDT.textMuted,
                          ),
                        ),
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
                          hint: 'Fines, other withholdings',
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
                          if (n > gross - leaveDeduction) {
                            return 'Deductions exceed gross pay';
                          }
                          return null;
                        },
                      ),
                      if (deduction > 0) ...[
                        SizedBox(height: 14.h),
                        TextFormField(
                          controller: deductionNoteCtrl,
                          decoration: finDialogInputDecoration(
                            label: 'Deduction Reason *',
                            hint: 'e.g. Traffic fine',
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
                          recoverLabel: row.isTrip
                              ? 'Recover From This Payment'
                              : 'Recover From This Salary',
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
                        basic: basic,
                        extra: extra,
                        leaveDays: leaveDays,
                        leaveDeduction: leaveDeduction,
                        deduction: deduction,
                        recovery: recovery,
                        net: net,
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
                label: 'Finalize ${fmt.format(net)} ${row.currency}',
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  if (net <= 0 && recovery <= 0) {
                    _snack(context, 'Net pay must be above zero.', FinDT.danger);
                    return;
                  }

                  final user = context.read<AuthProvider>().user;
                  final actorName = user?.actorLabel ?? 'Admin';

                  setInner(() => isPaying = true);
                  try {
                    final paymentId = row.payment?.id ??
                        (row.isTrip
                            ? SalaryPaymentEntity.buildTripId(
                                provider.period,
                                row.employeeId,
                              )
                            : SalaryPaymentEntity.buildId(
                                provider.period,
                                row.employeeId,
                              ));
                    final base = row.payment;
                    await provider.finalize(
                      payment: SalaryPaymentEntity(
                        id: paymentId,
                        period: provider.period,
                        kind: row.kind,
                        employeeId: row.employeeId,
                        employeeName: row.employeeName,
                        position: row.position,
                        basicSalary: basic,
                        tripCount: row.isTrip
                            ? int.tryParse(tripCountCtrl.text.trim())
                            : null,
                        allowances: row.allowances,
                        extraAllowance: extra,
                        extraAllowanceNote:
                            extra <= 0 || extraNoteCtrl.text.trim().isEmpty
                                ? null
                                : extraNoteCtrl.text.trim(),
                        leaveDays: leaveDays,
                        leaveDeduction: leaveDeduction,
                        deductions: deduction,
                        deductionNote: deduction <= 0 ||
                                deductionNoteCtrl.text.trim().isEmpty
                            ? null
                            : deductionNoteCtrl.text.trim(),
                        advanceRecovery: recovery,
                        netAmount: net,
                        netAmountMinor: (net * 100).round(),
                        currency: row.currency,
                        fundAccountId: account.id,
                        fundAccountName: account.name,
                        paymentMethod: base?.paymentMethod ?? 'cash',
                        notes: base?.notes,
                        createdAt: base?.createdAt ?? DateTime.now(),
                        createdBy: base?.createdBy ?? actorName,
                      ),
                      actorName: actorName,
                      actorUserId: user?.id,
                    );

                    if (ctx.mounted) finSafePop(ctx);
                    if (context.mounted) {
                      _snack(
                        context,
                        'Finalized ${fmt.format(net)} ${row.currency} for '
                        '${row.employeeName} — ready to be paid from '
                        '${account.name}.',
                        FinDT.success,
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      setInner(() => isPaying = false);
                      _snack(context, 'Failed to finalize: $e', FinDT.danger);
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

  /// Step 2 — pay a finalized salary. Every amount and the account are fixed
  /// by the finalizer; the payer only says whether the money went out as cash
  /// or STC Pay, then confirms.
  Future<void> _showPayDialog(
    BuildContext context,
    SalaryProvider provider,
    _PayrollRow row,
  ) async {
    if (!_guardPay(context)) return;
    final payment = row.payment;
    if (payment == null || !payment.status.canPay) return;

    final account = context
        .read<FundAccountProvider>()
        .accounts
        .where((a) => a.id == payment.fundAccountId)
        .firstOrNull;
    if (account == null || !account.isActive) {
      _snack(
        context,
        'The account chosen at finalize '
        '(${payment.fundAccountName ?? 'unknown'}) is no longer available. '
        'Ask the finalizer to reopen this ${row.isTrip ? 'payment' : 'salary'}.',
        FinDT.danger,
      );
      return;
    }

    // The finalizer fixed how much is recovered; spread it over the advances
    // still open now, oldest first.
    final openAdvances = context
        .read<CashAdvanceProvider>()
        .advances
        .where((a) => a.employeeId == row.employeeId && a.isOpen)
        .toList()
      ..sort((a, b) => a.issuedAt.compareTo(b.issuedAt));
    final allocation = SalaryPaymentEntity.allocateAdvanceRecovery(
      amount: payment.advanceRecovery,
      advances: openAdvances,
    );
    final allocated = allocation.values.fold(0.0, (sum, v) => sum + v);
    if ((allocated - payment.advanceRecovery).abs() > 0.005) {
      _snack(
        context,
        '${row.employeeName}\'s advances changed after this was finalized. '
        'Ask the finalizer to reopen and finalize it again.',
        FinDT.danger,
      );
      return;
    }

    final fmt = NumberFormat('#,##0.00');
    final monthLabel = DateFormat('MMMM y').format(provider.periodDate);
    final net = payment.netAmount;
    final recovery = payment.advanceRecovery;
    String paymentMethod =
        payment.paymentMethod == 'stcPay' ? 'stcPay' : 'cash';
    bool isPaying = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) {
          // Petty cash wallets track physical cash and STC Pay separately, so
          // the payer says which one the money came out of.
          final usesBuckets = account.isPettyCash ||
              account.cashBalance > 0 ||
              account.stcPayBalance > 0;
          final effectiveMethod = usesBuckets ? paymentMethod : 'bank';
          // Mirrors the server's bucket resolution: a wallet whose cash and
          // STC buckets are both empty is spent from the total balance.
          final usesSplitBalances =
              account.cashBalance > 0 || account.stcPayBalance > 0;
          final bucketBalance = !usesSplitBalances
              ? account.currentBalance
              : switch (effectiveMethod) {
                  'cash' => account.cashBalance,
                  'stcPay' => account.stcPayBalance,
                  _ => account.currentBalance,
                };
          final balanceLabel =
              usesSplitBalances ? _methodLabel(effectiveMethod) : 'Account';

          final reasons = [
            if ((payment.extraAllowanceNote ?? '').isNotEmpty)
              'Extra: ${payment.extraAllowanceNote}',
            if ((payment.deductionNote ?? '').isNotEmpty)
              'Deduction: ${payment.deductionNote}',
            if (row.isTrip && payment.tripCount != null)
              '${payment.tripCount} trips',
          ];

          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: finDialogShape,
            title: finDialogTitle(
              'Pay — ${row.employeeName}',
              icon: Icons.payments_outlined,
            ),
            content: SizedBox(
              width: 460.w,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 8.h),
                    Text(
                      'Month: $monthLabel',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        color: FinDT.textSecondary,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    _buildInfoStrip(
                      'Finalized by ${payment.finalizedBy ?? '—'}'
                      '${payment.finalizedAt != null ? ' on ${DateFormat('d MMM y').format(payment.finalizedAt!)}' : ''}. '
                      'The amounts and account are locked.',
                      Icons.verified_outlined,
                      FinDT.brand,
                    ),
                    SizedBox(height: 12.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: FinDT.bgPage,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(color: FinDT.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 18.sp,
                            color: FinDT.textSecondary,
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pay From',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.sp,
                                    color: FinDT.textMuted,
                                  ),
                                ),
                                Text(
                                  account.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w700,
                                    color: FinDT.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${fmt.format(account.currentBalance)} '
                            '${account.currency}',
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: FinDT.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (usesBuckets) ...[
                      SizedBox(height: 14.h),
                      _buildMethodSelector(
                        selected: effectiveMethod,
                        account: account,
                        fmt: fmt,
                        enabled: !isPaying,
                        onChanged: (m) => setInner(() => paymentMethod = m),
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
                    SizedBox(height: 16.h),
                    _buildPaySummary(
                      row: row,
                      basic: payment.basicSalary,
                      extra: payment.extraAllowance,
                      leaveDays: payment.leaveDays,
                      leaveDeduction: payment.leaveDeduction,
                      deduction: payment.deductions,
                      recovery: recovery,
                      net: net,
                      fmt: fmt,
                      account: account,
                      balanceLabel: balanceLabel,
                      bucketBalance: bucketBalance,
                    ),
                    if (reasons.isNotEmpty) ...[
                      SizedBox(height: 8.h),
                      Text(
                        reasons.join(' · '),
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          color: FinDT.textMuted,
                        ),
                      ),
                    ],
                  ],
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
                  final fundProv = context.read<FundAccountProvider>();
                  final advanceProv = context.read<CashAdvanceProvider>();

                  setInner(() => isPaying = true);
                  try {
                    await provider.pay(
                      paymentId: payment.id,
                      fundAccountId: account.id,
                      actorName: user?.actorLabel ?? 'Admin',
                      actorUserId: user?.id,
                      paymentMethod: effectiveMethod,
                      advanceRecoveries: allocation,
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
                      _snack(context, 'Failed to pay: $e', FinDT.danger);
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

  /// Adds an external employee to the selected month (picking an existing one
  /// or creating a new one), then goes straight on to finalizing their amount.
  Future<void> _showAddExternalDialog(
    BuildContext context,
    SalaryProvider provider,
  ) async {
    if (!_guardFinalize(context)) return;

    final candidates = _externalStaffNotInMonth(provider);
    final monthLabel = DateFormat('MMMM y').format(provider.periodDate);
    final tripAccounts = _payrollAccounts(SalaryPaymentKind.tripSettlement);
    final currency =
        tripAccounts.isEmpty ? 'SAR' : tripAccounts.first.currency;
    EmployeeEntity? selected;
    bool isSaving = false;

    final added = await showDialog<SalaryPaymentEntity>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: finDialogShape,
          title: finDialogTitle(
            'Add to $monthLabel',
            icon: Icons.person_add_alt_1_outlined,
          ),
          content: SizedBox(
            width: 420.w,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8.h),
                SearchableDropdown<EmployeeEntity>(
                  // Rebuilt when a new employee is created and selected.
                  key: ValueKey(selected?.id),
                  value: selected,
                  labelText: 'External Employee',
                  searchHint: 'Search by name or code…',
                  decoration: finDialogInputDecoration(
                    label: 'External Employee *',
                    hint: candidates.isEmpty
                        ? 'Everyone is already added — create a new one'
                        : 'Pick who worked this month',
                    prefixIcon: Icons.person_outline,
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: FinDT.textPrimary,
                  ),
                  items: candidates,
                  itemToString: _employeeLabel,
                  enabled: !isSaving,
                  onChanged: (e) => setInner(() => selected = e),
                ),
                SizedBox(height: 10.h),
                TextButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final created =
                              await _showQuickAddExternalDialog(ctx);
                          if (created == null) return;
                          setInner(() {
                            candidates.insert(0, created);
                            selected = created;
                          });
                        },
                  icon: Icon(Icons.add, size: 16.sp),
                  label: Text(
                    'New External Employee',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(foregroundColor: FinDT.brand),
                ),
                SizedBox(height: 6.h),
                _buildInfoStrip(
                  'External staff are added month by month — next month\'s '
                  'list starts empty.',
                  Icons.info_outline,
                  FinDT.textSecondary,
                ),
              ],
            ),
          ),
          actions: [
            finDialogCancelButton(ctx, onPressed: isSaving ? () {} : null),
            finDialogActionButton(
              isLoading: isSaving,
              label: 'Add & Set Amount',
              onPressed: () async {
                final employee = selected;
                if (employee == null) {
                  _snack(context, 'Pick an external employee first.',
                      FinDT.danger);
                  return;
                }
                final user = context.read<AuthProvider>().user;
                setInner(() => isSaving = true);
                try {
                  await provider.savePayment(
                    SalaryPaymentEntity(
                      id: SalaryPaymentEntity.buildTripId(
                        provider.period,
                        employee.id,
                      ),
                      period: provider.period,
                      kind: SalaryPaymentKind.tripSettlement,
                      employeeId: employee.id,
                      employeeName: employee.fullName,
                      position: employee.position,
                      basicSalary: 0,
                      netAmount: 0,
                      currency: currency,
                      createdAt: DateTime.now(),
                      createdBy: user?.actorLabel ?? 'Admin',
                    ),
                  );
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop(provider.tripPaymentFor(employee.id));
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    setInner(() => isSaving = false);
                    _snack(context, 'Failed to add: $e', FinDT.danger);
                  }
                }
              },
            ),
          ],
        ),
      ),
    );

    if (added == null || !context.mounted) return;
    await _showFinalizeDialog(
      context,
      provider,
      _PayrollRow(
        employeeId: added.employeeId,
        employeeName: added.employeeName,
        employeeCode: _employeeCodes()[added.employeeId],
        position: added.position,
        kind: SalaryPaymentKind.tripSettlement,
        payment: added,
      ),
    );
  }

  /// Creates a minimal external employee record (the same fields the
  /// Employees form keeps for external staff) and returns it.
  Future<EmployeeEntity?> _showQuickAddExternalDialog(
    BuildContext context,
  ) async {
    final employeeProv = context.read<EmployeeProvider>();
    if (employeeProv.roles.isEmpty) {
      try {
        await employeeProv.fetchEmployeeRoles();
      } catch (_) {
        // Fall back to the built-in positions below.
      }
    }
    if (!context.mounted) return null;
    final positions = (employeeProv.roles.isEmpty
            ? EmployeeRoleEntity.defaults
            : employeeProv.roles)
        .map((r) => r.name)
        .toList();

    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final nationalityCtrl = TextEditingController();
    String position = positions.contains('Driver') ? 'Driver' : positions.first;
    String gender = 'Male';
    bool isSaving = false;

    return showDialog<EmployeeEntity>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: finDialogShape,
          title: finDialogTitle(
            'New External Employee',
            icon: Icons.person_add_alt_outlined,
          ),
          content: SizedBox(
            width: 400.w,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 8.h),
                    TextFormField(
                      controller: nameCtrl,
                      enabled: !isSaving,
                      textCapitalization: TextCapitalization.words,
                      decoration: finDialogInputDecoration(
                        label: 'Full Name *',
                        prefixIcon: Icons.person_outline,
                      ),
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: FinDT.textPrimary,
                      ),
                      validator: (v) {
                        final name = v?.trim() ?? '';
                        if (name.isEmpty) return 'Required';
                        final taken = employeeProv.employees.any((e) =>
                            e.isExternal &&
                            e.fullName.trim().toLowerCase() ==
                                name.toLowerCase());
                        if (taken) {
                          return 'Already exists — pick them from the list';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 14.h),
                    DropdownButtonFormField<String>(
                      initialValue: position,
                      decoration: finDialogInputDecoration(
                        label: 'Position *',
                        prefixIcon: Icons.work_outline,
                      ),
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: FinDT.textPrimary,
                      ),
                      items: positions
                          .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                          .toList(),
                      onChanged: isSaving
                          ? null
                          : (v) => setInner(() => position = v ?? position),
                    ),
                    SizedBox(height: 14.h),
                    TextFormField(
                      controller: phoneCtrl,
                      enabled: !isSaving,
                      keyboardType: TextInputType.phone,
                      decoration: finDialogInputDecoration(
                        label: 'Phone',
                        hint: 'Optional',
                        prefixIcon: Icons.phone_outlined,
                      ),
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: FinDT.textPrimary,
                      ),
                    ),
                    SizedBox(height: 14.h),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: nationalityCtrl,
                            enabled: !isSaving,
                            textCapitalization: TextCapitalization.words,
                            decoration: finDialogInputDecoration(
                              label: 'Nationality',
                              hint: 'Optional',
                              prefixIcon: Icons.flag_outlined,
                            ),
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              color: FinDT.textPrimary,
                            ),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: gender,
                            decoration: finDialogInputDecoration(
                              label: 'Gender',
                              prefixIcon: Icons.wc_outlined,
                            ),
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              color: FinDT.textPrimary,
                            ),
                            items: const ['Male', 'Female']
                                .map((g) =>
                                    DropdownMenuItem(value: g, child: Text(g)))
                                .toList(),
                            onChanged: isSaving
                                ? null
                                : (v) => setInner(() => gender = v ?? gender),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    _buildInfoStrip(
                      'Saved in Employees as External. Add vehicle details '
                      'there later if needed.',
                      Icons.info_outline,
                      FinDT.textSecondary,
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
              label: 'Create Employee',
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final employee = EmployeeEntity(
                  id: const Uuid().v4(),
                  fullName: nameCtrl.text.trim(),
                  position: position,
                  email: '',
                  phoneNumber: phoneCtrl.text.trim(),
                  nationality: nationalityCtrl.text.trim(),
                  idType: '',
                  idNumber: '',
                  gender: gender,
                  employmentType: EmploymentType.external,
                );
                setInner(() => isSaving = true);
                try {
                  await employeeProv.addEmployee(employee);
                  if (ctx.mounted) Navigator.of(ctx).pop(employee);
                } catch (e) {
                  if (ctx.mounted) {
                    setInner(() => isSaving = false);
                    _snack(context, 'Failed to create employee: $e',
                        FinDT.danger);
                  }
                }
              },
            ),
          ],
        ),
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
    required String recoverLabel,
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
              label: recoverLabel,
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
    required double basic,
    required double extra,
    required int leaveDays,
    required double leaveDeduction,
    required double deduction,
    required double recovery,
    required double net,
    required NumberFormat fmt,
    // Shown on the pay step only, where money actually leaves the account.
    FundAccountEntity? account,
    String? balanceLabel,
    double? bucketBalance,
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
          if (row.isTrip)
            line('Earnings', '${fmt.format(basic)} ${row.currency}')
          else ...[
            line('Basic', '${fmt.format(basic)} ${row.currency}'),
            line('Allowances', '${fmt.format(row.allowances)} ${row.currency}'),
          ],
          if (extra > 0)
            line(
              row.isTrip ? 'Extra' : 'Extra allowance',
              '+ ${fmt.format(extra)} ${row.currency}',
              color: FinDT.success,
            ),
          if (leaveDays > 0)
            line(
              'Leave ($leaveDays ${leaveDays == 1 ? 'day' : 'days'})',
              '− ${fmt.format(leaveDeduction)} ${row.currency}',
              color: FinDT.danger,
            ),
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
          if (account != null && bucketBalance != null) ...[
            SizedBox(height: 6.h),
            line(
              '${balanceLabel ?? 'Account'} balance after',
              '${fmt.format(bucketBalance - net)} ${account.currency}',
              color: bucketBalance - net < 0 ? FinDT.danger : null,
            ),
          ],
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
    if (!_guardFinalize(context)) return;

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
            payment.isTripSettlement
                ? 'Void Trip Payment'
                : 'Void Salary Payment',
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
                    _snack(
                      context,
                      '${payment.kind.displayName} voided.',
                      FinDT.success,
                    );
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

  bool _guardFinalize(BuildContext context) {
    if (_canFinalize) return true;
    _snack(
      context,
      'Only a salary finalizer can do this — see Salary Finalize in '
      'Master Data.',
      FinDT.danger,
    );
    return false;
  }

  bool _guardPay(BuildContext context) {
    if (_canPay) return true;
    _snack(
      context,
      'You are not allowed to pay salaries — see Salary Pay in Master Data.',
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
