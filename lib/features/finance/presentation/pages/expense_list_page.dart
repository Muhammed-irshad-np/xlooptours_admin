import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/fund_account_provider.dart';
import '../widgets/expense_status_badge.dart';
import '../../domain/entities/expense_entity.dart';
import '../../domain/services/finance_export_service.dart';
import 'expense_form_page.dart';
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
          else
            _buildTable(context, expenses, formatter),
        ],
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
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
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    expense.referenceNumber,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: FinDT.brand,
                      fontSize: 12.sp,
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
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
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

  Widget _buildActions(BuildContext context, ExpenseEntity expense) {
    final auth = context.read<AuthProvider>().user;
    final canApprove = auth?.canApproveExpense ?? false;
    final canReverse = auth?.canReverseMoney ?? false;

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
        if (expense.status.canHardDelete) ...[
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

    final postsMoney = !expense.isNonWallet;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(postsMoney ? 'Approve & pay from wallet?' : 'Approve?'),
        content: Text(
          postsMoney
              ? 'Approve ${expense.referenceNumber} — ${expense.expenseType} '
                  'for ${expense.amount} ${expense.currency}?\n\n'
                  'This will deduct the amount from ${expense.fundAccountName ?? 'the fund account'}.'
              : 'Approve ${expense.referenceNumber} as non-wallet (no balance change)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: FinDT.success),
            child: Text(postsMoney ? 'Approve & pay' : 'Approve'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      await context.read<FinanceProvider>().approveExpense(
            expenseId: expense.id,
            actorName: user.actorLabel,
            actorUserId: user.id,
            actorRole: user.role.name,
            allowSelfApprove: user.isAdmin,
          );
      if (context.mounted) {
        await context.read<FundAccountProvider>().fetchAllAccounts();
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
    }
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

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Expense?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Reject ${expense.referenceNumber}?'),
            SizedBox(height: 12.h),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Reason for rejection...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: FinDT.danger),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    if (controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rejection reason is required')),
      );
      return;
    }

    try {
      await context.read<FinanceProvider>().rejectExpense(
            expenseId: expense.id,
            actorName: user.actorLabel,
            actorUserId: user.id,
            reason: controller.text.trim(),
          );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: FinDT.danger),
        );
      }
    }
  }

  Future<void> _confirmVoid(
    BuildContext context,
    ExpenseEntity expense,
  ) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    final controller = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Void paid expense?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This reverses the wallet payment for ${expense.referenceNumber} '
              'and keeps full history (does not delete).',
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Reason for void...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
            ),
            child: const Text('Void & reverse'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    if (controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Void reason is required')),
      );
      return;
    }

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
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: FinDT.danger),
        );
      }
    }
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

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete draft/pending?'),
        content: Text(
          'Delete ${expense.referenceNumber}? Only allowed before payment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: FinDT.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      await context.read<FinanceProvider>().deleteExpense(expense.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: FinDT.danger),
        );
      }
    }
  }
}
