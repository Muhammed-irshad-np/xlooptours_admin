import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:xloop_invoice/core/utils/app_snack_bar.dart';
import 'package:xloop_invoice/core/utils/file_download.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../employee/presentation/providers/employee_provider.dart';
import '../../domain/entities/expense_entity.dart';
import '../../domain/entities/finance_report.dart';
import '../../domain/entities/fund_account_entity.dart';
import '../../domain/entities/fund_transaction_entity.dart';
import '../../domain/services/finance_permission_service.dart';
import '../../domain/services/finance_report_builder.dart';
import '../../domain/services/finance_report_file_service.dart';
import '../providers/finance_report_provider.dart';
import '../providers/fund_account_provider.dart';
import '../widgets/expense_status_badge.dart';
import 'finance_dashboard_page.dart';

/// Finance → Reports: pick a report, filter it, read it on screen and
/// download it as Excel or PDF.
class FinanceReportsPage extends StatefulWidget {
  const FinanceReportsPage({super.key});

  @override
  State<FinanceReportsPage> createState() => _FinanceReportsPageState();
}

class _FinanceReportsPageState extends State<FinanceReportsPage> {
  static const _pageSize = 100;
  int _visibleRows = _pageSize;
  bool _exporting = false;
  String? _scopeKey;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final provider = context.read<FinanceReportProvider>();
    _searchController.text = provider.filter.search;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      provider.load();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Admins report on every account (closed ones too, for history);
  /// everyone else only on the accounts assigned to them.
  void _syncScope() {
    final user = context.read<AuthProvider>().user;
    final accountProvider = context.read<FundAccountProvider>();
    final employees = context.read<EmployeeProvider>().employees;
    final isAdmin = user?.isAdmin ?? false;

    String? employeeName;
    final employeeId = user?.employeeId ?? '';
    for (final e in employees) {
      if (employeeId.isNotEmpty && e.id == employeeId) {
        employeeName = e.fullName;
        break;
      }
    }
    final accounts = isAdmin
        ? accountProvider.accounts
        : accountProvider.accounts
            .where((a) => FinancePermissionService.canSeeAccount(
                  user: user,
                  account: a,
                  employeeName: employeeName,
                ))
            .toList();
    context
        .read<FinanceReportProvider>()
        .setScope(accounts, includeUnassigned: isAdmin);
  }

  void _update(FinanceReportFilter filter) {
    setState(() => _visibleRows = _pageSize);
    context.read<FinanceReportProvider>().updateFilter(filter);
  }

  @override
  Widget build(BuildContext context) {
    // Re-scope when accounts, employees or the signed-in user change.
    final scopeKey = [
      context.select<FundAccountProvider, Object>(
        (p) => Object.hashAll(p.accounts.map((a) => a.id)),
      ),
      context.select<EmployeeProvider, int>((p) => p.employees.length),
      context.select<AuthProvider, String?>((p) => p.user?.id),
    ].join('|');
    if (scopeKey != _scopeKey) {
      _scopeKey = scopeKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncScope();
      });
    }

    return Consumer<FinanceReportProvider>(
      builder: (context, provider, _) {
        final filter = provider.filter;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ReportTypeSelector(
              selected: filter.type,
              onChanged: (t) {
                setState(() => _visibleRows = _pageSize);
                provider.setType(t);
              },
            ),
            SizedBox(height: 16.h),
            _buildFilters(provider),
            SizedBox(height: 16.h),
            if (provider.isLoading && !provider.hasLoaded)
              _buildLoading()
            else if (provider.error != null && !provider.hasLoaded)
              _buildError(provider)
            else ...[
              _buildActionsBar(provider),
              SizedBox(height: 16.h),
              if (filter.type.isLedger)
                ..._buildLedgerBody(provider)
              else
                ..._buildExpenseBody(provider),
            ],
          ],
        );
      },
    );
  }

  // ─── Filters ─────────────────────────────────────────────────────────

  Widget _buildFilters(FinanceReportProvider provider) {
    final filter = provider.filter;
    final accounts = provider.accounts;

    return _Card(
      padding: EdgeInsets.all(18.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 18.sp, color: FinDT.brand),
              SizedBox(width: 8.w),
              Text(
                'Filters',
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: FinDT.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _visibleRows = _pageSize);
                  provider.resetFilters();
                },
                icon: Icon(Icons.filter_alt_off_outlined, size: 16.sp),
                label: Text(
                  'Clear filters',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(foregroundColor: FinDT.danger),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _FilterLabel('Period'),
          _PeriodPicker(
            from: filter.from,
            to: filter.to,
            onChanged: (from, to) => _update(
              from == null && to == null
                  ? filter.copyWith(clearDates: true)
                  : filter.copyWith(from: from, to: to),
            ),
          ),
          SizedBox(height: 14.h),
          Wrap(
            spacing: 10.w,
            runSpacing: 10.h,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _MultiSelectButton<String>(
                label: 'Accounts',
                icon: Icons.account_balance_wallet_outlined,
                options: [for (final a in accounts) a.id],
                optionLabel: (id) => _accountLabel(accounts, id),
                selected: filter.accountIds,
                onChanged: (ids) => _update(filter.copyWith(accountIds: ids)),
              ),
              if (!filter.type.isLedger) ...[
                _MultiSelectButton<String>(
                  label: 'Category',
                  icon: Icons.category_outlined,
                  options: provider.categoryOptions,
                  optionLabel: (s) => s,
                  selected: filter.categories,
                  onChanged: (v) => _update(filter.copyWith(categories: v)),
                ),
                _MultiSelectButton<String>(
                  label: 'Expense type',
                  icon: Icons.label_outline_rounded,
                  options: provider.expenseTypeOptions,
                  optionLabel: (s) => s,
                  selected: filter.expenseTypes,
                  onChanged: (v) => _update(filter.copyWith(expenseTypes: v)),
                ),
                _MultiSelectButton<String>(
                  label: 'Payment method',
                  icon: Icons.payments_outlined,
                  options: provider.paymentMethodOptions,
                  optionLabel: FinanceReportBuilder.paymentMethodLabel,
                  selected: filter.paymentMethods,
                  onChanged: (v) =>
                      _update(filter.copyWith(paymentMethods: v)),
                ),
                _MultiSelectButton<String>(
                  label: 'Employee',
                  icon: Icons.badge_outlined,
                  options: provider.employeeOptions,
                  optionLabel: (s) => s,
                  selected: filter.employees,
                  onChanged: (v) => _update(filter.copyWith(employees: v)),
                ),
                _MultiSelectButton<String>(
                  label: 'Vehicle',
                  icon: Icons.directions_car_outlined,
                  options: provider.vehicleOptions,
                  optionLabel: (s) => s,
                  selected: filter.vehicles,
                  onChanged: (v) => _update(filter.copyWith(vehicles: v)),
                ),
              ],
              if (filter.type == FinanceReportType.accountActivity)
                _SegmentedChoice<LedgerDirection>(
                  values: LedgerDirection.values,
                  selected: filter.direction,
                  label: (d) => d.displayName,
                  onChanged: (d) => _update(filter.copyWith(direction: d)),
                ),
              if (filter.type.isLedger)
                _ToggleChip(
                  label: 'Hide transfers between selected accounts',
                  value: filter.excludeInternalTransfers,
                  onChanged: (v) =>
                      _update(filter.copyWith(excludeInternalTransfers: v)),
                ),
              SizedBox(
                width: 280.w,
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => _update(filter.copyWith(search: v)),
                  decoration: InputDecoration(
                    hintText: filter.type.isLedger
                        ? 'Search ref, description, account, user...'
                        : 'Search ref, type, employee, vehicle...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: FinDT.textMuted,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 18.sp,
                      color: FinDT.textMuted,
                    ),
                    filled: true,
                    fillColor: FinDT.bgPage,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                    isDense: true,
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: FinDT.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          if (filter.type.isLedger) ...[
            _FilterLabel('Transaction types'),
            _ChipSet<FundTransactionType>(
              values: FundTransactionType.values,
              selected: filter.transactionTypes,
              label: (t) => t.displayName,
              onChanged: (v) =>
                  _update(filter.copyWith(transactionTypes: v)),
            ),
          ] else ...[
            _FilterLabel('Status'),
            _ChipSet<ExpenseStatus>(
              values: ExpenseStatus.values
                  .where((s) => s != ExpenseStatus.closed)
                  .toList(),
              selected: filter.statuses,
              label: (s) => s.displayName,
              onChanged: (v) => _update(filter.copyWith(statuses: v)),
            ),
          ],
        ],
      ),
    );
  }

  static String _accountLabel(List<FundAccountEntity> accounts, String id) {
    for (final a in accounts) {
      if (a.id == id) {
        final closed = a.isActive ? '' : ' (closed)';
        return a.code.isEmpty ? '${a.name}$closed' : '${a.name} · ${a.code}$closed';
      }
    }
    return id;
  }

  // ─── Actions ─────────────────────────────────────────────────────────

  Widget _buildActionsBar(FinanceReportProvider provider) {
    final count = provider.filter.type.isLedger
        ? provider.ledgerReport.rows.length
        : provider.expenseReport.rows.length;
    final noun = provider.filter.type.isLedger ? 'entries' : 'expenses';
    return Row(
      children: [
        Text(
          '$count $noun',
          style: GoogleFonts.inter(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: FinDT.textSecondary,
          ),
        ),
        if (provider.isLoading) ...[
          SizedBox(width: 10.w),
          SizedBox(
            width: 14.w,
            height: 14.w,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
        const Spacer(),
        _ActionButton(
          icon: Icons.refresh_rounded,
          label: 'Reload data',
          onTap: provider.isLoading ? null : provider.load,
        ),
        SizedBox(width: 10.w),
        _ActionButton(
          icon: Icons.table_view_rounded,
          label: 'Download Excel',
          color: FinDT.success,
          onTap: _exporting ? null : () => _export(excel: true),
        ),
        SizedBox(width: 10.w),
        _ActionButton(
          icon: Icons.picture_as_pdf_rounded,
          label: 'Download PDF',
          color: FinDT.danger,
          onTap: _exporting ? null : () => _export(excel: false),
        ),
      ],
    );
  }

  Future<void> _export({required bool excel}) async {
    final provider = context.read<FinanceReportProvider>();
    final user = context.read<AuthProvider>().user;
    setState(() => _exporting = true);
    AppSnackBar.showInfo(
      context,
      excel ? 'Preparing Excel file...' : 'Preparing PDF...',
    );
    try {
      final doc = provider.buildDocument(
        generatedBy: user?.actorLabel ?? 'Unknown',
      );
      final base = FinanceReportFileService.fileBaseName(doc);
      if (excel) {
        await saveFileBytes(
          bytes: FinanceReportFileService.buildExcel(doc),
          fileName: '$base.xlsx',
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
      } else {
        final bytes = await FinanceReportFileService.buildPdf(doc);
        await saveFileBytes(
          bytes: bytes,
          fileName: '$base.pdf',
          mimeType: 'application/pdf',
        );
      }
      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          excel ? 'Excel report downloaded' : 'PDF report downloaded',
        );
      }
    } catch (e) {
      debugPrint('Report export failed: $e');
      if (mounted) AppSnackBar.showError(context, 'Could not create the file: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ─── Ledger body ─────────────────────────────────────────────────────

  List<Widget> _buildLedgerBody(FinanceReportProvider provider) {
    final report = provider.ledgerReport;
    final isIncome = provider.filter.type == FinanceReportType.income;
    final f = NumberFormat('#,##0.00', 'en_US');
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

    return [
      _MetricRow(metrics: [
        if (!isIncome)
          _Metric('Opening balance', '${f.format(report.openingTotal)} SAR',
              Icons.flag_outlined, FinDT.textSecondary),
        _Metric('Money in', '${f.format(report.totalIn)} SAR',
            Icons.south_west_rounded, FinDT.success),
        if (!isIncome)
          _Metric('Money out', '${f.format(report.totalOut)} SAR',
              Icons.north_east_rounded, FinDT.danger),
        if (!isIncome)
          _Metric('Closing balance', '${f.format(report.closingTotal)} SAR',
              Icons.account_balance_rounded, FinDT.brand),
        if (isIncome)
          _Metric('Entries', '${report.rows.length}',
              Icons.receipt_long_outlined, FinDT.brand),
      ]),
      SizedBox(height: 16.h),
      _TableCard(
        title: 'Account balances for the period',
        subtitle:
            'All movements in the period, whatever the type and search filters.',
        columns: const [
          _Col('Account', 3),
          _Col('Opening', 1.4, numeric: true),
          _Col('Money in', 1.4, numeric: true),
          _Col('Money out', 1.4, numeric: true),
          _Col('Closing', 1.4, numeric: true),
          _Col('Entries', 0.8, numeric: true),
        ],
        rows: [
          for (final a in report.accounts)
            [
              _cellText(
                a.accountCode.isEmpty
                    ? a.accountName
                    : '${a.accountName} · ${a.accountCode}',
                bold: true,
              ),
              _cellText(f.format(a.opening), align: TextAlign.right),
              _cellText(f.format(a.moneyIn),
                  align: TextAlign.right, color: FinDT.success),
              _cellText(f.format(a.moneyOut),
                  align: TextAlign.right, color: FinDT.danger),
              _cellText(f.format(a.closing),
                  align: TextAlign.right, bold: true),
              _cellText('${a.entries}', align: TextAlign.right),
            ],
        ],
        emptyText: 'No accounts to show.',
      ),
      SizedBox(height: 16.h),
      _TableCard(
        title: isIncome ? 'Income entries' : 'Transactions',
        columns: const [
          _Col('Ref', 1.1),
          _Col('Date', 1.5),
          _Col('Account', 1.6),
          _Col('Type', 1.3),
          _Col('Description', 3),
          _Col('Money in', 1.2, numeric: true),
          _Col('Money out', 1.2, numeric: true),
          _Col('Balance', 1.2, numeric: true),
          _Col('By', 1.2),
        ],
        rows: [
          for (final r in report.rows.take(_visibleRows))
            [
              _cellText(r.tx.displayReference, mono: true),
              _cellText(dateFmt.format(r.tx.date)),
              _cellText(r.accountName, bold: true),
              _cellText(r.tx.type.displayName +
                  (r.tx.isReversed ? ' (reversed)' : '')),
              _cellText(
                r.counterpartyName == null
                    ? r.tx.description
                    : '${r.tx.description}\n↔ ${r.counterpartyName}',
                maxLines: 3,
              ),
              _cellText(r.moneyIn == 0 ? '' : f.format(r.moneyIn),
                  align: TextAlign.right, color: FinDT.success, bold: true),
              _cellText(r.moneyOut == 0 ? '' : f.format(r.moneyOut),
                  align: TextAlign.right, color: FinDT.danger, bold: true),
              _cellText(f.format(r.tx.balanceAfter), align: TextAlign.right),
              _cellText(r.tx.performedBy),
            ],
        ],
        totals: report.rows.isEmpty
            ? null
            : [
                _cellText('Total', bold: true),
                const SizedBox(),
                const SizedBox(),
                const SizedBox(),
                const SizedBox(),
                _cellText(f.format(report.totalIn),
                    align: TextAlign.right, bold: true, color: FinDT.success),
                _cellText(f.format(report.totalOut),
                    align: TextAlign.right, bold: true, color: FinDT.danger),
                const SizedBox(),
                const SizedBox(),
              ],
        emptyText: 'No transactions match the selected filters.',
        footer: _showMore(report.rows.length),
      ),
    ];
  }

  // ─── Expense body ────────────────────────────────────────────────────

  List<Widget> _buildExpenseBody(FinanceReportProvider provider) {
    final report = provider.expenseReport;
    final f = NumberFormat('#,##0.00', 'en_US');
    final dateFmt = DateFormat('dd MMM yyyy');
    final names = {for (final a in provider.accounts) a.id: a.name};

    Widget groupTable(String title, List<ReportGroupTotal> groups) =>
        _TableCard(
          title: title,
          columns: const [
            _Col('Name', 3),
            _Col('Count', 1, numeric: true),
            _Col('Amount (SAR)', 1.6, numeric: true),
          ],
          rows: [
            for (final g in groups)
              [
                _cellText(g.label, bold: true),
                _cellText('${g.count}', align: TextAlign.right),
                _cellText(f.format(g.amount), align: TextAlign.right),
              ],
          ],
          emptyText: 'Nothing to group.',
          maxHeight: 320.h,
        );

    return [
      _MetricRow(metrics: [
        _Metric('Total listed', '${f.format(report.total)} SAR',
            Icons.summarize_outlined, FinDT.brand),
        _Metric('Paid', '${f.format(report.paidTotal)} SAR',
            Icons.check_circle_outline_rounded, FinDT.success),
        _Metric('Not paid yet', '${f.format(report.outstandingTotal)} SAR',
            Icons.hourglass_bottom_rounded, FinDT.warning),
        _Metric('Rejected / voided',
            '${f.format(report.rejectedOrVoidedTotal)} SAR',
            Icons.block_rounded, FinDT.danger),
      ]),
      SizedBox(height: 16.h),
      LayoutBuilder(builder: (context, c) {
        final byCategory = groupTable('By category', report.byCategory);
        final byAccount = groupTable('By account', report.byAccount);
        if (c.maxWidth < 900) {
          return Column(children: [
            byCategory,
            SizedBox(height: 16.h),
            byAccount,
          ]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: byCategory),
            SizedBox(width: 16.w),
            Expanded(child: byAccount),
          ],
        );
      }),
      SizedBox(height: 16.h),
      _TableCard(
        title: 'Expenses',
        columns: const [
          _Col('Ref', 1.1),
          _Col('Date', 1.1),
          _Col('Status', 1),
          _Col('Category / Type', 2.2),
          _Col('Account', 1.4),
          _Col('Payment', 0.9),
          _Col('Employee', 1.4),
          _Col('Vehicle', 1.2),
          _Col('Amount (SAR)', 1.2, numeric: true),
        ],
        rows: [
          for (final e in report.rows.take(_visibleRows))
            [
              _cellText(e.referenceNumber, mono: true),
              _cellText(dateFmt.format(e.date)),
              Align(
                alignment: Alignment.centerLeft,
                child: ExpenseStatusBadge(status: e.status),
              ),
              _cellText('${e.expenseCategory}\n${e.expenseType}', maxLines: 3),
              _cellText(FinanceReportBuilder.accountNameOf(e, names)),
              _cellText(FinanceReportBuilder.paymentMethodLabel(e.paymentMethod)),
              _cellText(e.employeeName ?? '—'),
              _cellText(e.vehicleName ?? '—'),
              _cellText(f.format(e.amount), align: TextAlign.right, bold: true),
            ],
        ],
        totals: report.rows.isEmpty
            ? null
            : [
                _cellText('Total', bold: true),
                for (var i = 0; i < 7; i++) const SizedBox(),
                _cellText(f.format(report.total),
                    align: TextAlign.right, bold: true),
              ],
        emptyText: 'No expenses match the selected filters.',
        footer: _showMore(report.rows.length),
      ),
    ];
  }

  Widget? _showMore(int total) {
    if (total <= _visibleRows) return null;
    return Padding(
      padding: EdgeInsets.all(12.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Showing $_visibleRows of $total. The download includes all rows.',
            style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textSecondary),
          ),
          SizedBox(width: 12.w),
          TextButton(
            onPressed: () => setState(() => _visibleRows += _pageSize),
            child: Text(
              'Show more',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: FinDT.brand,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── States ──────────────────────────────────────────────────────────

  Widget _buildLoading() => _Card(
        padding: EdgeInsets.all(48.w),
        child: const Center(
          child: CircularProgressIndicator(color: FinDT.brand),
        ),
      );

  Widget _buildError(FinanceReportProvider provider) => _Card(
        padding: EdgeInsets.all(32.w),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 32.sp, color: FinDT.danger),
              SizedBox(height: 10.h),
              Text(
                'Could not load report data',
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: FinDT.textPrimary,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                provider.error ?? '',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  color: FinDT.textSecondary,
                ),
              ),
              SizedBox(height: 12.h),
              TextButton(onPressed: provider.load, child: const Text('Try again')),
            ],
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// Widgets
// ═══════════════════════════════════════════════════════════════════════════

Widget _cellText(
  String text, {
  TextAlign align = TextAlign.left,
  bool bold = false,
  Color? color,
  bool mono = false,
  int maxLines = 2,
}) {
  return Text(
    text,
    textAlign: align,
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
    style: (mono ? GoogleFonts.robotoMono : GoogleFonts.inter)(
      fontSize: 12.sp,
      fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
      color: color ?? FinDT.textPrimary,
    ),
  );
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const _Card({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: FinDT.bgCard,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: FinDT.border),
        boxShadow: const [
          BoxShadow(color: FinDT.shadow, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }
}

class _ReportTypeSelector extends StatelessWidget {
  final FinanceReportType selected;
  final ValueChanged<FinanceReportType> onChanged;

  const _ReportTypeSelector({required this.selected, required this.onChanged});

  static const _icons = {
    FinanceReportType.accountActivity: Icons.swap_vert_rounded,
    FinanceReportType.income: Icons.savings_outlined,
    FinanceReportType.expenses: Icons.receipt_long_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cards = [
        for (final t in FinanceReportType.values) _buildCard(t),
      ];
      if (c.maxWidth < 760) {
        return Column(
          children: [
            for (final card in cards) ...[card, SizedBox(height: 10.h)],
          ],
        );
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) SizedBox(width: 12.w),
              Expanded(child: cards[i]),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildCard(FinanceReportType t) {
    final isSelected = t == selected;
    return Material(
      color: isSelected ? FinDT.brandLight : Colors.white,
      borderRadius: BorderRadius.circular(14.r),
      child: InkWell(
        onTap: () => onChanged(t),
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: isSelected ? FinDT.brand : FinDT.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: isSelected
                      ? FinDT.brand
                      : FinDT.brand.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  _icons[t],
                  size: 18.sp,
                  color: isSelected ? Colors.white : FinDT.brand,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.displayName,
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: FinDT.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      t.description,
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        color: FinDT.textSecondary,
                        height: 1.35,
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
}

class _FilterLabel extends StatelessWidget {
  final String text;
  const _FilterLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: FinDT.textMuted,
        ),
      ),
    );
  }
}

/// Period presets plus a custom range picker.
class _PeriodPicker extends StatelessWidget {
  final DateTime? from;
  final DateTime? to;
  final void Function(DateTime? from, DateTime? to) onChanged;

  const _PeriodPicker({
    required this.from,
    required this.to,
    required this.onChanged,
  });

  static bool _sameDay(DateTime? a, DateTime? b) =>
      a == null && b == null ||
      (a != null &&
          b != null &&
          a.year == b.year &&
          a.month == b.month &&
          a.day == b.day);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final presets = <String, (DateTime?, DateTime?)>{
      'Today': (today, today),
      'This month': (DateTime(now.year, now.month, 1), today),
      'Last month': (
        DateTime(now.year, now.month - 1, 1),
        DateTime(now.year, now.month, 0),
      ),
      'Last 3 months': (DateTime(now.year, now.month - 2, 1), today),
      'This year': (DateTime(now.year, 1, 1), today),
      'Last year': (DateTime(now.year - 1, 1, 1), DateTime(now.year - 1, 12, 31)),
      'All time': (null, null),
    };
    String? active;
    presets.forEach((label, range) {
      if (active == null && _sameDay(range.$1, from) && _sameDay(range.$2, to)) {
        active = label;
      }
    });
    final dayFmt = DateFormat('dd MMM yyyy');
    final customLabel = active == null && from != null
        ? '${dayFmt.format(from!)} – ${to == null ? 'Today' : dayFmt.format(to!)}'
        : 'Custom range';

    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        for (final entry in presets.entries)
          _PillButton(
            label: entry.key,
            selected: active == entry.key,
            onTap: () => onChanged(entry.value.$1, entry.value.$2),
          ),
        _PillButton(
          label: customLabel,
          icon: Icons.date_range_rounded,
          selected: active == null,
          onTap: () async {
            final result = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime(now.year + 1, 12, 31),
              initialDateRange: from != null
                  ? DateTimeRange(start: from!, end: to ?? today)
                  : null,
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(primary: FinDT.brand),
                ),
                child: child!,
              ),
            );
            if (result != null) onChanged(result.start, result.end);
          },
        ),
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const _PillButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? FinDT.brand : FinDT.bgPage,
      borderRadius: BorderRadius.circular(20.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 14.sp,
                    color: selected ? Colors.white : FinDT.textSecondary),
                SizedBox(width: 6.w),
              ],
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? Colors.white : FinDT.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Multi-select filter chips; nothing selected means "all".
class _ChipSet<T> extends StatelessWidget {
  final List<T> values;
  final Set<T> selected;
  final String Function(T) label;
  final ValueChanged<Set<T>> onChanged;

  const _ChipSet({
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        _PillButton(
          label: 'All',
          selected: selected.isEmpty,
          onTap: () => onChanged(<T>{}),
        ),
        for (final v in values)
          _PillButton(
            label: label(v),
            icon: selected.contains(v) ? Icons.check_rounded : null,
            selected: selected.contains(v),
            onTap: () {
              final next = {...selected};
              if (!next.remove(v)) next.add(v);
              onChanged(next);
            },
          ),
      ],
    );
  }
}

class _SegmentedChoice<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  const _SegmentedChoice({
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: FinDT.bgPage,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final v in values)
            InkWell(
              onTap: () => onChanged(v),
              borderRadius: BorderRadius.circular(8.r),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
                decoration: BoxDecoration(
                  color: v == selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8.r),
                  boxShadow: v == selected
                      ? const [BoxShadow(color: FinDT.shadow, blurRadius: 4)]
                      : null,
                ),
                child: Text(
                  label(v),
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight:
                        v == selected ? FontWeight.w600 : FontWeight.w500,
                    color: v == selected
                        ? FinDT.textPrimary
                        : FinDT.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleChip({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: FinDT.bgPage,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 28.h,
              child: FittedBox(
                child: Switch(
                  value: value,
                  onChanged: onChanged,
                  activeTrackColor: FinDT.brand,
                ),
              ),
            ),
            SizedBox(width: 6.w),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: FinDT.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Button that opens a searchable multi-select dialog.
class _MultiSelectButton<T> extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<T> options;
  final String Function(T) optionLabel;
  final Set<T> selected;
  final ValueChanged<Set<T>> onChanged;

  const _MultiSelectButton({
    required this.label,
    required this.icon,
    required this.options,
    required this.optionLabel,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final active = selected.isNotEmpty;
    final summary = !active
        ? 'All'
        : selected.length == 1
            ? optionLabel(selected.first)
            : '${selected.length} selected';
    return Material(
      color: active ? FinDT.brand.withValues(alpha: 0.08) : FinDT.bgPage,
      borderRadius: BorderRadius.circular(10.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(10.r),
        onTap: () async {
          final result = await showDialog<Set<T>>(
            context: context,
            builder: (_) => _MultiSelectDialog<T>(
              title: label,
              options: options,
              optionLabel: optionLabel,
              initial: selected,
            ),
          );
          if (result != null) onChanged(result);
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 15.sp,
                  color: active ? FinDT.brand : FinDT.textMuted),
              SizedBox(width: 6.w),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 220.w),
                child: Text(
                  '$label: $summary',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: active ? FinDT.brand : FinDT.textSecondary,
                  ),
                ),
              ),
              SizedBox(width: 4.w),
              Icon(Icons.keyboard_arrow_down_rounded,
                  size: 16.sp,
                  color: active ? FinDT.brand : FinDT.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _MultiSelectDialog<T> extends StatefulWidget {
  final String title;
  final List<T> options;
  final String Function(T) optionLabel;
  final Set<T> initial;

  const _MultiSelectDialog({
    required this.title,
    required this.options,
    required this.optionLabel,
    required this.initial,
  });

  @override
  State<_MultiSelectDialog<T>> createState() => _MultiSelectDialogState<T>();
}

class _MultiSelectDialogState<T> extends State<_MultiSelectDialog<T>> {
  late final Set<T> _selected = {...widget.initial};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final visible = widget.options
        .where((o) => q.isEmpty || widget.optionLabel(o).toLowerCase().contains(q))
        .toList();

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      title: Text(
        'Select ${widget.title.toLowerCase()}',
        style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 420.w,
        height: 460.h,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search…',
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Text(
                  _selected.isEmpty
                      ? 'None selected = all'
                      : '${_selected.length} selected',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: FinDT.textSecondary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _selected.addAll(visible)),
                  child: const Text('Select shown'),
                ),
                TextButton(
                  onPressed: () => setState(_selected.clear),
                  child: const Text('Clear'),
                ),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: visible.isEmpty
                  ? Center(
                      child: Text(
                        widget.options.isEmpty
                            ? 'Nothing to choose from yet.'
                            : 'No matches.',
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          color: FinDT.textMuted,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, i) {
                        final o = visible[i];
                        return CheckboxListTile(
                          dense: true,
                          value: _selected.contains(o),
                          activeColor: FinDT.brand,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            widget.optionLabel(o),
                            style: GoogleFonts.inter(fontSize: 13.sp),
                          ),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selected.add(o);
                            } else {
                              _selected.remove(o);
                            }
                          }),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: FinDT.brand),
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final filled = color != null;
    final fg = filled ? Colors.white : FinDT.textPrimary;
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: filled ? color : Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.r),
              border: filled ? null : Border.all(color: FinDT.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16.sp, color: fg),
                SizedBox(width: 6.w),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Metric {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _Metric(this.label, this.value, this.icon, this.color);
}

class _MetricRow extends StatelessWidget {
  final List<_Metric> metrics;
  const _MetricRow({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final perRow = c.maxWidth < 700 ? 2 : metrics.length;
      final gap = 12.w;
      final width = (c.maxWidth - gap * (perRow - 1)) / perRow;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final m in metrics)
            SizedBox(width: width, child: _buildTile(m)),
        ],
      );
    });
  }

  Widget _buildTile(_Metric m) {
    return _Card(
      padding: EdgeInsets.all(16.w),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(9.w),
            decoration: BoxDecoration(
              color: m.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(m.icon, size: 18.sp, color: m.color),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.label,
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    color: FinDT.textSecondary,
                  ),
                ),
                SizedBox(height: 4.h),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    m.value,
                    style: GoogleFonts.inter(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w800,
                      color: FinDT.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Col {
  final String label;
  final double flex;
  final bool numeric;
  const _Col(this.label, this.flex, {this.numeric = false});
}

/// Simple flex table inside a card. Scrolls sideways on narrow screens.
class _TableCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<_Col> columns;
  final List<List<Widget>> rows;
  final List<Widget>? totals;
  final String emptyText;
  final Widget? footer;
  final double? maxHeight;

  const _TableCard({
    required this.title,
    this.subtitle,
    required this.columns,
    required this.rows,
    this.totals,
    required this.emptyText,
    this.footer,
    this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: FinDT.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  SizedBox(height: 2.h),
                  Text(
                    subtitle!,
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      color: FinDT.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          LayoutBuilder(builder: (context, c) {
            const minWidth = 900.0;
            final width = c.maxWidth < minWidth && columns.length > 4
                ? minWidth
                : c.maxWidth;
            Widget body = Column(
              children: [
                _row(
                  [
                    for (final col in columns)
                      Text(
                        col.label.toUpperCase(),
                        textAlign:
                            col.numeric ? TextAlign.right : TextAlign.left,
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: FinDT.textSecondary,
                        ),
                      ),
                  ],
                  color: FinDT.bgPage,
                ),
                if (rows.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(28.w),
                    child: Text(
                      emptyText,
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: FinDT.textMuted,
                      ),
                    ),
                  ),
                if (rows.isNotEmpty)
                  _scrollable(
                    Column(
                      children: [
                        for (var i = 0; i < rows.length; i++)
                          _row(
                            rows[i],
                            color: i.isOdd ? const Color(0xFFFAFAFB) : null,
                          ),
                      ],
                    ),
                  ),
                if (totals != null)
                  _row(totals!, color: FinDT.brandLight),
              ],
            );
            if (width > c.maxWidth) {
              body = SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(width: width, child: body),
              );
            }
            return body;
          }),
          if (footer != null) footer!,
          SizedBox(height: 6.h),
        ],
      ),
    );
  }

  Widget _scrollable(Widget child) {
    if (maxHeight == null) return child;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight!),
      child: SingleChildScrollView(child: child),
    );
  }

  Widget _row(List<Widget> cells, {Color? color}) {
    return Container(
      color: color,
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var c = 0; c < columns.length; c++)
            Expanded(
              flex: (columns[c].flex * 10).round(),
              child: Padding(
                padding: EdgeInsets.only(right: 10.w),
                child: c < cells.length ? cells[c] : const SizedBox(),
              ),
            ),
        ],
      ),
    );
  }
}
