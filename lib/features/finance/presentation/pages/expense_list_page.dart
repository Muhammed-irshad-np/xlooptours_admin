import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/fund_account_provider.dart';
import '../providers/petty_cash_provider.dart';
import '../widgets/expense_status_badge.dart';
import '../../domain/entities/expense_entity.dart';
import '../../domain/services/finance_export_service.dart';
import '../../domain/services/finance_permission_service.dart';
import 'expense_form_page.dart';
import '../widgets/finance_dialog_helpers.dart';
import 'finance_dashboard_page.dart';

/// Expense list page with filtering, search, and data table.
class ExpenseListPage extends StatelessWidget {
  const ExpenseListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<FinanceProvider, FundAccountProvider>(
      builder: (context, provider, accountProvider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Filters Bar ─────────────────────────────────
            _FiltersBar(
              provider: provider,
              accountProvider: accountProvider,
            ),
            SizedBox(height: 16.h),

            // ── Expense Table ───────────────────────────────
            _ExpenseDataTable(
              provider: provider,
              accountProvider: accountProvider,
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FILTERS BAR
// ═══════════════════════════════════════════════════════════════════════════════

class _FiltersBar extends StatelessWidget {
  final FinanceProvider provider;
  final FundAccountProvider accountProvider;
  const _FiltersBar({
    required this.provider,
    required this.accountProvider,
  });

  @override
  Widget build(BuildContext context) {
    final accounts = accountProvider.activeAccounts;
    // Keep dropdown value valid even if the selected account is inactive.
    final selectedAccountId = provider.accountFilter;
    final accountItems = accounts
        .map((a) => DropdownMenuItem(
              value: a.id,
              child: Text(a.name),
            ))
        .toList();
    if (selectedAccountId != null &&
        !accounts.any((a) => a.id == selectedAccountId)) {
      final inactive = accountProvider.accounts
          .where((a) => a.id == selectedAccountId)
          .toList();
      if (inactive.isNotEmpty) {
        accountItems.insert(
          0,
          DropdownMenuItem(
            value: inactive.first.id,
            child: Text(inactive.first.name),
          ),
        );
      }
    }

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: FinDT.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Search
            SizedBox(
              width: 280.w,
              child: _SearchField(provider: provider),
            ),
            SizedBox(width: 12.w),

            // Status filter
            _FilterDropdown<ExpenseStatus>(
              hint: 'Status',
              value: provider.statusFilter,
              items: ExpenseStatus.values
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.displayName),
                      ))
                  .toList(),
              onChanged: (s) => provider.setStatusFilter(s),
            ),
            SizedBox(width: 12.w),

            // Category filter
            _FilterDropdown<String>(
              hint: 'Category',
              value: provider.categoryFilter,
              items: provider.categories
                  .map((c) => DropdownMenuItem(
                        value: c.name,
                        child: Text(c.name),
                      ))
                  .toList(),
              onChanged: (c) => provider.setCategoryFilter(c),
            ),
            SizedBox(width: 12.w),

            // Fund account filter
            _FilterDropdown<String>(
              hint: 'Account',
              value: selectedAccountId,
              items: accountItems,
              onChanged: (id) => provider.setAccountFilter(id),
            ),
            SizedBox(width: 12.w),

            // Date range
            _DateRangeButton(provider: provider),

            if (provider.statusFilter != null ||
                provider.categoryFilter != null ||
                provider.accountFilter != null ||
                provider.searchQuery != null ||
                provider.dateFrom != null) ...[
              SizedBox(width: 12.w),
              _ClearFilterButton(provider: provider),
            ],
            SizedBox(width: 12.w),
            OutlinedButton.icon(
              onPressed: () async {
                final list = provider.filteredExpenses;
                if (list.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No expenses to export')),
                  );
                  return;
                }
                final name =
                    'expenses_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
                try {
                  await FinanceExportService.shareCsv(
                    fileName: name,
                    csvContent: FinanceExportService.expensesToCsv(list),
                  );
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Export failed: $e')),
                    );
                  }
                }
              },
              icon: Icon(Icons.download_rounded, size: 16.sp),
              label: Text(
                'Export CSV',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final FinanceProvider provider;
  const _SearchField({required this.provider});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: (value) => provider.setSearchQuery(value.isEmpty ? null : value),
      decoration: InputDecoration(
        hintText: 'Search by ref #, name, type...',
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
      style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  final String hint;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _FilterDropdown({
    required this.hint,
    this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        color: FinDT.bgPage,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(
            hint,
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              color: FinDT.textMuted,
            ),
          ),
          items: items,
          onChanged: onChanged,
          style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16.sp,
            color: FinDT.textMuted,
          ),
          isDense: true,
        ),
      ),
    );
  }
}

class _DateRangeButton extends StatelessWidget {
  final FinanceProvider provider;
  const _DateRangeButton({required this.provider});

  @override
  Widget build(BuildContext context) {
    final hasDateFilter = provider.dateFrom != null;
    final label = hasDateFilter
        ? '${DateFormat('dd/MM').format(provider.dateFrom!)} - ${DateFormat('dd/MM').format(provider.dateTo!)}'
        : 'Date Range';

    return Material(
      color: hasDateFilter
          ? FinDT.brand.withValues(alpha: 0.08)
          : FinDT.bgPage,
      borderRadius: BorderRadius.circular(10.r),
      child: InkWell(
        onTap: () => _pickDateRange(context),
        borderRadius: BorderRadius.circular(10.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.date_range_rounded,
                size: 14.sp,
                color: hasDateFilter ? FinDT.brand : FinDT.textMuted,
              ),
              SizedBox(width: 6.w),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: hasDateFilter ? FontWeight.w600 : FontWeight.w400,
                  color: hasDateFilter ? FinDT.brand : FinDT.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: provider.dateFrom != null
          ? DateTimeRange(start: provider.dateFrom!, end: provider.dateTo!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: FinDT.brand),
          ),
          child: child!,
        );
      },
    );

    if (result != null) {
      provider.fetchExpensesByDateRange(result.start, result.end);
    }
  }
}

class _ClearFilterButton extends StatelessWidget {
  final FinanceProvider provider;
  const _ClearFilterButton({required this.provider});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        provider.clearFilters();
        provider.fetchAllExpenses();
      },
      icon: Icon(
        Icons.filter_alt_off_outlined,
        size: 18.sp,
        color: FinDT.danger,
      ),
      tooltip: 'Clear all filters',
      style: IconButton.styleFrom(
        backgroundColor: FinDT.danger.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DATA TABLE
// ═══════════════════════════════════════════════════════════════════════════════

class _ExpenseDataTable extends StatelessWidget {
  final FinanceProvider provider;
  final FundAccountProvider accountProvider;
  const _ExpenseDataTable({
    required this.provider,
    required this.accountProvider,
  });

  String _resolveAccountName(ExpenseEntity expense) {
    if (expense.fundAccountName != null &&
        expense.fundAccountName!.trim().isNotEmpty) {
      return expense.fundAccountName!;
    }
    try {
      return accountProvider.accounts
          .firstWhere((a) => a.id == expense.fundAccountId)
          .name;
    } catch (_) {
      return expense.fundAccountId.isEmpty ? '—' : expense.fundAccountId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenses = provider.filteredExpenses;
    final formatter = NumberFormat('#,##0.00', 'en_US');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: FinDT.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table header info
          Padding(
            padding: EdgeInsets.all(20.w),
            child: Row(
              children: [
                Text(
                  '${expenses.length} expense${expenses.length != 1 ? 's' : ''}',
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: FinDT.textPrimary,
                  ),
                ),
                SizedBox(width: 8.w),
                if (provider.totalFilteredAmount > 0)
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: FinDT.brandLight,
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      'Total: ${formatter.format(provider.totalFilteredAmount)} SAR',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: FinDT.brand,
                      ),
                    ),
                  ),
                const Spacer(),
                _buildAddButton(context),
              ],
            ),
          ),

          Divider(height: 1, color: FinDT.borderLight),

          if (provider.isLoading)
            Padding(
              padding: EdgeInsets.all(40.w),
              child: const Center(
                child: CircularProgressIndicator(color: FinDT.brand),
              ),
            )
          else if (expenses.isEmpty)
            _buildEmpty()
          else ...[
            _buildTable(context, expenses, formatter),
            if (provider.hasMore) ...[
              Divider(height: 1, color: FinDT.borderLight),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 20.w),
                child: Center(
                  child: provider.isLoadingMore
                      ? SizedBox(
                          height: 22.h,
                          width: 22.h,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: FinDT.brand,
                          ),
                        )
                      : OutlinedButton.icon(
                          onPressed: () => provider.fetchNextPage(),
                          icon: Icon(Icons.arrow_downward_rounded, size: 15.sp),
                          label: Text(
                            'Load More Expenses',
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: FinDT.brand,
                            side: BorderSide(
                              color: FinDT.brand.withValues(alpha: 0.35),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 10.h,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    final auth = context.read<AuthProvider>().user;
    final policy = context.read<FinanceProvider>().policy;
    final canSubmit = FinancePermissionService.canSubmitExpense(user: auth, policy: policy);
    if (!canSubmit) return const SizedBox.shrink();

    return Material(
      color: FinDT.brand,
      borderRadius: BorderRadius.circular(10.r),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ExpenseFormPage()),
        ),
        borderRadius: BorderRadius.circular(10.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 14.sp, color: Colors.white),
              SizedBox(width: 4.w),
              Text(
                'Add Expense',
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 48.h),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 40.sp,
              color: FinDT.textMuted,
            ),
            SizedBox(height: 12.h),
            Text(
              'No expenses found',
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: FinDT.textPrimary,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Try adjusting your filters or add a new expense',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: FinDT.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(
    BuildContext context,
    List<ExpenseEntity> expenses,
    NumberFormat formatter,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(14.r),
        bottomRight: Radius.circular(14.r),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            const Color(0xFFF9FAFB),
          ),
          headingTextStyle: GoogleFonts.inter(
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            color: FinDT.textSecondary,
          ),
          dataTextStyle: GoogleFonts.inter(
            fontSize: 12.sp,
            color: FinDT.textPrimary,
          ),
          columnSpacing: 20.w,
          horizontalMargin: 20.w,
          dataRowMinHeight: 52.h,
          dataRowMaxHeight: 52.h,
          columns: const [
            DataColumn(label: Text('REF #')),
            DataColumn(label: Text('DATE')),
            DataColumn(label: Text('TYPE')),
            DataColumn(label: Text('CATEGORY')),
            DataColumn(label: Text('ACCOUNT')),
            DataColumn(label: Text('SUBMITTED BY')),
            DataColumn(label: Text('AMOUNT'), numeric: true),
            DataColumn(label: Text('STATUS')),
            DataColumn(label: Text('ACTIONS')),
          ],
          rows: expenses.map((expense) {
            final accountName = _resolveAccountName(expense);
            final isVoidedOrRejected = expense.status == ExpenseStatus.voided ||
                expense.status == ExpenseStatus.rejected;
            return DataRow(
              cells: [
                DataCell(
                  InkWell(
                    onTap: () =>
                        _showExpenseLifecycleTimeline(context, expense),
                    borderRadius: BorderRadius.circular(4.r),
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: 4.h, horizontal: 2.w),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            expense.referenceNumber,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              color: FinDT.brand,
                              fontSize: 12.sp,
                              decoration: TextDecoration.underline,
                              decorationColor:
                                  FinDT.brand.withValues(alpha: 0.4),
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Icon(
                            Icons.info_outline_rounded,
                            size: 13.sp,
                            color: FinDT.brand.withValues(alpha: 0.6),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Text(DateFormat('dd MMM yy').format(expense.date)),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        expense.expenseType,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: FinDT.bgPage,
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      expense.expenseCategory,
                      style: GoogleFonts.inter(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: FinDT.textSecondary,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: FinDT.brandLight,
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      accountName,
                      style: GoogleFonts.inter(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: FinDT.brand,
                      ),
                    ),
                  ),
                ),
                DataCell(Text(expense.submittedBy)),
                DataCell(
                  Text(
                    '${formatter.format(expense.amount)} ${expense.currency}',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.sp,
                      color: isVoidedOrRejected
                          ? FinDT.textMuted
                          : FinDT.textPrimary,
                      decoration: isVoidedOrRejected
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor:
                          isVoidedOrRejected ? FinDT.textMuted : null,
                    ),
                  ),
                ),
                DataCell(ExpenseStatusBadge(status: expense.status)),
                DataCell(_buildActions(context, expense)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showExpenseLifecycleTimeline(
    BuildContext context,
    ExpenseEntity expense,
  ) {
    final formatter = NumberFormat('#,##0.00');
    final isVoided = expense.status == ExpenseStatus.voided;
    final isRejected = expense.status == ExpenseStatus.rejected;
    final accountName = _resolveAccountName(expense);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: finDialogShape,
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: FinDT.brand.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                color: FinDT.brand,
                size: 20.sp,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Expense ${expense.referenceNumber}',
                    style: GoogleFonts.inter(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: FinDT.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '${expense.expenseCategory} • ${expense.expenseType}',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      color: FinDT.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            ExpenseStatusBadge(status: expense.status),
          ],
        ),
        content: SizedBox(
          width: 480.w,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top overview card
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: FinDT.bgPage,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: FinDT.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Amount',
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              color: FinDT.textSecondary,
                            ),
                          ),
                          Text(
                            '${formatter.format(expense.amount)} ${expense.currency}',
                            style: GoogleFonts.inter(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                              color: (isVoided || isRejected)
                                  ? FinDT.textMuted
                                  : FinDT.textPrimary,
                              decoration: (isVoided || isRejected)
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      Divider(height: 16.h, color: FinDT.border),
                      _detailRow('Payment Method',
                          expense.paymentMethod.toUpperCase()),
                      SizedBox(height: 6.h),
                      _detailRow('Fund Account', accountName),
                      if (expense.employeeName != null &&
                          expense.employeeName!.isNotEmpty) ...[
                        SizedBox(height: 6.h),
                        _detailRow('Employee', expense.employeeName!),
                      ],
                      if (expense.vehicleName != null &&
                          expense.vehicleName!.isNotEmpty) ...[
                        SizedBox(height: 6.h),
                        _detailRow(
                          'Vehicle',
                          '${expense.vehicleName!}${expense.mileageKm != null ? " (${expense.mileageKm} km)" : ""}',
                        ),
                      ],
                      if (expense.description != null &&
                          expense.description!.isNotEmpty) ...[
                        SizedBox(height: 6.h),
                        _detailRow('Description', expense.description!),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 18.h),

                // Lifecycle & Audit Trail Header
                Text(
                  'LIFECYCLE & AUDIT TRAIL',
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: FinDT.textSecondary,
                  ),
                ),
                SizedBox(height: 12.h),

                // Timeline events
                _buildTimelineItem(
                  icon: Icons.edit_note_rounded,
                  iconColor: FinDT.brand,
                  title: 'Expense Submitted',
                  timestamp: DateFormat('dd MMM yyyy, hh:mm a')
                      .format(expense.createdAt),
                  subtitle:
                      'Submitted by ${expense.submittedBy} (${expense.submittedByRole.toUpperCase()})',
                  isFirst: true,
                  isLast: expense.status == ExpenseStatus.draft ||
                      expense.status == ExpenseStatus.pending,
                ),

                if (expense.approvedAt != null ||
                    expense.paidAt != null ||
                    expense.status == ExpenseStatus.paid ||
                    expense.status == ExpenseStatus.voided) ...[
                  _buildTimelineItem(
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: FinDT.success,
                    title: 'Approved & Paid',
                    timestamp: DateFormat('dd MMM yyyy, hh:mm a').format(
                      expense.paidAt ?? expense.approvedAt ?? expense.date,
                    ),
                    subtitle:
                        'Paid by ${expense.paidBy ?? expense.approvedBy ?? "Admin"} from $accountName',
                    extraNote: expense.ledgerEntryId != null
                        ? 'Ledger Entry: ${expense.ledgerEntryId}'
                        : null,
                    isLast: !isVoided,
                  ),
                ],

                if (isVoided) ...[
                  _buildTimelineItem(
                    icon: Icons.undo_rounded,
                    iconColor: const Color(0xFF7C3AED),
                    title: 'Payment Voided & Reversed',
                    timestamp: expense.voidedAt != null
                        ? DateFormat('dd MMM yyyy, hh:mm a')
                            .format(expense.voidedAt!)
                        : 'Recorded',
                    subtitle: 'Voided by ${expense.voidedBy ?? "Admin"}',
                    extraNote: expense.voidReason != null
                        ? 'Reason: "${expense.voidReason}"\nFunds refunded (+${formatter.format(expense.amount)} ${expense.currency}) to $accountName.'
                        : 'Funds refunded to $accountName.',
                    isAlert: true,
                    alertColor: const Color(0xFF7C3AED),
                    isLast: true,
                  ),
                ],

                if (isRejected) ...[
                  _buildTimelineItem(
                    icon: Icons.cancel_outlined,
                    iconColor: FinDT.danger,
                    title: 'Expense Rejected',
                    timestamp: expense.updatedAt != null
                        ? DateFormat('dd MMM yyyy, hh:mm a')
                            .format(expense.updatedAt!)
                        : 'Recorded',
                    subtitle:
                        'Rejected by ${expense.approvedBy ?? "Admin"}',
                    extraNote: expense.rejectionReason != null
                        ? 'Reason: "${expense.rejectionReason}"'
                        : null,
                    isAlert: true,
                    alertColor: FinDT.danger,
                    isLast: true,
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          finDialogCancelButton(
            ctx,
            onPressed: () => Navigator.pop(ctx),
            label: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.sp,
            color: FinDT.textSecondary,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: FinDT.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String timestamp,
    required String subtitle,
    String? extraNote,
    bool isFirst = false,
    bool isLast = false,
    bool isAlert = false,
    Color? alertColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              padding: EdgeInsets.all(6.w),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 14.sp, color: iconColor),
            ),
            if (!isLast)
              Container(
                width: 2.w,
                height: 38.h,
                color: FinDT.border,
              ),
          ],
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: FinDT.textPrimary,
                      ),
                    ),
                    Text(
                      timestamp,
                      style: GoogleFonts.inter(
                        fontSize: 10.sp,
                        color: FinDT.textMuted,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    color: FinDT.textSecondary,
                  ),
                ),
                if (extraNote != null) ...[
                  SizedBox(height: 6.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: isAlert && alertColor != null
                          ? alertColor.withValues(alpha: 0.08)
                          : FinDT.bgPage,
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(
                        color: isAlert && alertColor != null
                            ? alertColor.withValues(alpha: 0.25)
                            : FinDT.border,
                      ),
                    ),
                    child: Text(
                      extraNote,
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        color: isAlert && alertColor != null
                            ? alertColor
                            : FinDT.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context, ExpenseEntity expense) {
    final auth = context.read<AuthProvider>().user;
    final isSuperAdmin = auth?.isSuperAdmin ?? false;
    final policy = context.read<FinanceProvider>().policy;
    final canApprove = FinancePermissionService.canApproveExpense(
      user: auth,
      policy: policy,
      amount: expense.amount,
    );
    final canReverse = FinancePermissionService.canVoidExpense(
      user: auth,
      policy: policy,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (expense.status.canApprove && canApprove) ...[
          _actionIcon(
            icon: Icons.check_circle_outline,
            color: FinDT.success,
            tooltip: expense.isNonWallet
                ? 'Approve'
                : 'Approve & post to wallet',
            onTap: () => _confirmApprove(context, expense),
          ),
          SizedBox(width: 4.w),
          _actionIcon(
            icon: Icons.cancel_outlined,
            color: FinDT.danger,
            tooltip: 'Reject',
            onTap: () => _confirmReject(context, expense),
          ),
          SizedBox(width: 4.w),
        ],
        if (expense.status.canVoid && canReverse) ...[
          _actionIcon(
            icon: Icons.undo_rounded,
            color: const Color(0xFF7C3AED),
            tooltip: 'Void & reverse payment',
            onTap: () => _confirmVoid(context, expense),
          ),
          SizedBox(width: 4.w),
        ],
        if (expense.status.canEdit)
          _actionIcon(
            icon: Icons.edit_outlined,
            color: FinDT.brand,
            tooltip: 'Edit',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ExpenseFormPage(expense: expense),
              ),
            ),
          ),
        if (isSuperAdmin && expense.status.canHardDelete) ...[
          SizedBox(width: 4.w),
          _actionIcon(
            icon: Icons.delete_outline,
            color: FinDT.danger,
            tooltip: 'Delete draft/pending',
            onTap: () => _confirmDelete(context, expense),
          ),
        ],
      ],
    );
  }

  Widget _actionIcon({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6.r),
        child: Padding(
          padding: EdgeInsets.all(4.w),
          child: Icon(icon, size: 16.sp, color: color),
        ),
      ),
    );
  }

  Future<void> _confirmApprove(
    BuildContext context,
    ExpenseEntity expense,
  ) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    if (expense.amount >= 100 && expense.receiptUrls.isEmpty) {
      final attach = await showFinConfirmationDialog(
        context: context,
        title: 'Receipt Required to Approve',
        icon: Icons.receipt_long_outlined,
        iconColor: FinDT.warning,
        message:
            'Company policy requires an attached receipt or bill document for any expense of 100.00 SAR or more.\n\n'
            'Expense ${expense.referenceNumber} (${expense.amount.toStringAsFixed(2)} ${expense.currency}) has no receipt attached yet.\n\n'
            'Would you like to edit this expense and attach the receipt now?',
        confirmLabel: 'Edit & Attach Receipt',
        confirmColor: FinDT.brand,
        cancelLabel: 'Cancel',
      );
      if (attach == true && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExpenseFormPage(expense: expense),
          ),
        );
      }
      return;
    }

    final postsMoney = !expense.isNonWallet;
    final fundProv = context.read<FundAccountProvider>();
    final account = fundProv.getAccountById(expense.fundAccountId);

    if (postsMoney && account?.isPettyCash == true) {
      final pettyProv = context.read<PettyCashProvider>();
      final openSession = await pettyProv.getOpenSessionUseCase(account!.id);
      if (openSession == null) {
        if (!context.mounted) return;
        showFinConfirmationDialog(
          context: context,
          title: 'Petty Cash Session Closed',
          icon: Icons.lock_clock_outlined,
          iconColor: FinDT.warning,
          message:
              'Cannot pay from "${account.name}" because no petty cash session is currently open today.\n\n'
              'Financial Safety Rule: You must open a Petty Cash session before paying expenses out of this cash drawer.',
          confirmLabel: 'Understood',
          confirmColor: FinDT.brand,
        );
        return;
      }
    }

    if (!context.mounted) return;
    await showFinConfirmationDialog(
      context: context,
      title: postsMoney ? 'Approve & Pay Expense?' : 'Approve Expense?',
      message: postsMoney
          ? 'Approve ${expense.referenceNumber} — ${expense.expenseType} for ${expense.amount} ${expense.currency}?'
          : 'Approve ${expense.referenceNumber} as non-wallet (no balance change)?',
      highlightNote: postsMoney
          ? 'This will deduct ${expense.amount} ${expense.currency} from ${expense.fundAccountName ?? "the fund account"}.'
          : null,
      confirmLabel: postsMoney ? 'Approve & Pay' : 'Approve',
      confirmColor: FinDT.success,
      icon: Icons.check_circle_outline_rounded,
      onConfirm: () async {
        final finProv = context.read<FinanceProvider>();
        try {
          await finProv.approveExpense(
            expenseId: expense.id,
            actorName: user.actorLabel,
            actorUserId: user.id,
            actorRole: user.role.name,
            allowSelfApprove: user.isAdmin,
          );
          await fundProv.fetchAllAccounts();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  postsMoney
                      ? 'Approved and paid from wallet'
                      : 'Expense approved',
                ),
                backgroundColor: FinDT.success,
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            final msg = _friendlyError(e);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(msg),
                backgroundColor: FinDT.danger,
                duration: const Duration(seconds: 6),
              ),
            );
          }
          rethrow;
        }
      },
    );
  }

  String _friendlyError(Object e) {
    final raw = e.toString();
    if (raw.contains('failed-precondition') && raw.contains('index')) {
      return 'Firestore needs an index for this query. Hot-restart after deploy, '
          'or the app will use a fallback query on next build.';
    }
    return raw
        .replaceFirst('StateError: ', '')
        .replaceFirst('Exception: ', '')
        .replaceFirst('Error: ', '');
  }

  Future<void> _confirmReject(
    BuildContext context,
    ExpenseEntity expense,
  ) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    final controller = TextEditingController();
    bool isRejecting = false;

    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: finDialogShape,
          title: finDialogTitle('Reject Expense?', icon: Icons.cancel_outlined, iconColor: FinDT.danger),
          content: SizedBox(
            width: 420.w,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reject expense ${expense.referenceNumber} (${expense.expenseType} - ${expense.amount} ${expense.currency})?',
                  style: GoogleFonts.inter(fontSize: 13.sp, color: FinDT.textSecondary, height: 1.4),
                ),
                SizedBox(height: 14.h),
                TextField(
                  controller: controller,
                  maxLines: 2,
                  decoration: finDialogInputDecoration(
                    label: 'Rejection Reason *',
                    hint: 'Explain why this expense is being rejected...',
                    prefixIcon: Icons.edit_note_rounded,
                  ),
                  style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
                ),
              ],
            ),
          ),
          actions: [
            finDialogCancelButton(
              ctx,
              onPressed: isRejecting ? () {} : null,
            ),
            finDialogActionButton(
              onPressed: () async {
                if (controller.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Rejection reason is required')),
                  );
                  return;
                }

                setDialogState(() => isRejecting = true);
                try {
                  await context.read<FinanceProvider>().rejectExpense(
                        expenseId: expense.id,
                        actorName: user.actorLabel,
                        actorUserId: user.id,
                        reason: controller.text.trim(),
                      );
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) {
                    setDialogState(() => isRejecting = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$e'), backgroundColor: FinDT.danger),
                    );
                  }
                }
              },
              label: 'Reject Expense',
              backgroundColor: FinDT.danger,
              isLoading: isRejecting,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmVoid(
    BuildContext context,
    ExpenseEntity expense,
  ) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    final controller = TextEditingController();
    bool isVoiding = false;

    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: finDialogShape,
          title: finDialogTitle('Void Paid Expense?', icon: Icons.restart_alt_rounded, iconColor: const Color(0xFF7C3AED)),
          content: SizedBox(
            width: 420.w,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    'This reverses the wallet payment for ${expense.referenceNumber} (${expense.amount} ${expense.currency}) and keeps full audit history.',
                    style: GoogleFonts.inter(fontSize: 12.sp, color: const Color(0xFF7C3AED), height: 1.4),
                  ),
                ),
                SizedBox(height: 14.h),
                TextField(
                  controller: controller,
                  maxLines: 2,
                  decoration: finDialogInputDecoration(
                    label: 'Void Reason *',
                    hint: 'Explain why this payment is being voided...',
                    prefixIcon: Icons.edit_note_rounded,
                  ),
                  style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
                ),
              ],
            ),
          ),
          actions: [
            finDialogCancelButton(
              ctx,
              onPressed: isVoiding ? () {} : null,
            ),
            finDialogActionButton(
              onPressed: () async {
                if (controller.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Void reason is required')),
                  );
                  return;
                }

                setDialogState(() => isVoiding = true);
                try {
                  await context.read<FinanceProvider>().voidExpense(
                        expenseId: expense.id,
                        actorName: user.actorLabel,
                        actorUserId: user.id,
                        reason: controller.text.trim(),
                      );
                  if (context.mounted) {
                    await context.read<FundAccountProvider>().fetchAllAccounts();
                  }
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) {
                    setDialogState(() => isVoiding = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$e'), backgroundColor: FinDT.danger),
                    );
                  }
                }
              },
              label: 'Void & Reverse',
              backgroundColor: const Color(0xFF7C3AED),
              isLoading: isVoiding,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ExpenseEntity expense,
  ) async {
    if (!expense.status.canHardDelete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Posted expenses cannot be deleted. Void them instead.'),
        ),
      );
      return;
    }

    await showFinConfirmationDialog(
      context: context,
      title: 'Delete Draft Expense?',
      message: 'Delete ${expense.referenceNumber}? Only draft and pending expenses can be deleted before payment.',
      confirmLabel: 'Delete Expense',
      confirmColor: FinDT.danger,
      icon: Icons.delete_outline_rounded,
      onConfirm: () async {
        await context.read<FinanceProvider>().deleteExpense(expense.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense deleted')),
          );
        }
      },
    );
  }
}
