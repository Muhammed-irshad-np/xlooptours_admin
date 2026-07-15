import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:xloop_invoice/features/finance/domain/entities/expense_entity.dart';
import 'package:xloop_invoice/features/finance/presentation/providers/finance_provider.dart';
import 'package:xloop_invoice/features/finance/presentation/providers/fund_account_provider.dart';
import 'package:xloop_invoice/features/finance/presentation/widgets/expense_status_badge.dart';
import 'expense_form_page.dart';

/// Expense listing page with filtering, search, and approval actions.
class ExpenseListPage extends StatefulWidget {
  const ExpenseListPage({super.key});

  @override
  State<ExpenseListPage> createState() => _ExpenseListPageState();
}

class _ExpenseListPageState extends State<ExpenseListPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceProvider>(
      builder: (context, fp, _) {
        final expenses = fp.filteredExpenses;
        return Column(
          children: [
            // ── Action bar ────────────────────────────────────
            Container(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
              color: Colors.white,
              child: Row(
                children: [
                  // Search
                  Expanded(
                    flex: 3,
                    child: Container(
                      height: 38.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => fp.setSearchQuery(v),
                        style: GoogleFonts.inter(fontSize: 12.sp),
                        decoration: InputDecoration(
                          hintText: 'Search by ref, name, type, vehicle...',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 12.sp,
                            color: const Color(0xFF9CA3AF),
                          ),
                          prefixIcon: Icon(Icons.search, size: 18.sp, color: const Color(0xFF9CA3AF)),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  // Status filter chips
                  _FilterChip(
                    label: 'All',
                    isSelected: fp.statusFilter == null,
                    onTap: () => fp.setStatusFilter(null),
                  ),
                  SizedBox(width: 6.w),
                  _FilterChip(
                    label: 'Pending',
                    isSelected: fp.statusFilter == ExpenseStatus.pending,
                    color: const Color(0xFFF59E0B),
                    onTap: () => fp.setStatusFilter(ExpenseStatus.pending),
                  ),
                  SizedBox(width: 6.w),
                  _FilterChip(
                    label: 'Approved',
                    isSelected: fp.statusFilter == ExpenseStatus.approved,
                    color: const Color(0xFF22C55E),
                    onTap: () => fp.setStatusFilter(ExpenseStatus.approved),
                  ),
                  SizedBox(width: 6.w),
                  _FilterChip(
                    label: 'Rejected',
                    isSelected: fp.statusFilter == ExpenseStatus.rejected,
                    color: const Color(0xFFEF4444),
                    onTap: () => fp.setStatusFilter(ExpenseStatus.rejected),
                  ),
                  const Spacer(),
                  // Add expense button
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ExpenseFormPage()),
                      );
                    },
                    icon: Icon(Icons.add, size: 16.sp),
                    label: Text(
                      'Add Expense',
                      style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── Stats row ──────────────────────────────────────
            Container(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 10.h),
              color: const Color(0xFFF9FAFB),
              child: Row(
                children: [
                  _MiniStat(
                    label: 'Total',
                    value: '${expenses.length}',
                    color: const Color(0xFF6366F1),
                  ),
                  SizedBox(width: 20.w),
                  _MiniStat(
                    label: 'Amount',
                    value: '${fp.totalFilteredAmount.toStringAsFixed(2)} SAR',
                    color: const Color(0xFF10B981),
                  ),
                  SizedBox(width: 20.w),
                  _MiniStat(
                    label: 'Pending',
                    value: '${fp.pendingCount}',
                    color: const Color(0xFFF59E0B),
                  ),
                ],
              ),
            ),
            // ── Data table ─────────────────────────────────────
            Expanded(
              child: fp.isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
                  : expenses.isEmpty
                      ? _buildEmptyState()
                      : _buildExpenseTable(expenses, fp),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64.sp, color: const Color(0xFFD1D5DB)),
          SizedBox(height: 16.h),
          Text(
            'No expenses found',
            style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w600, color: const Color(0xFF6B7280)),
          ),
          SizedBox(height: 6.h),
          Text(
            'Add your first expense to get started',
            style: GoogleFonts.inter(fontSize: 13.sp, color: const Color(0xFF9CA3AF)),
          ),
          SizedBox(height: 20.h),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseFormPage()));
            },
            icon: const Icon(Icons.add, size: 18),
            label: Text('Add Expense', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseTable(List<ExpenseEntity> expenses, FinanceProvider fp) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
          headingRowHeight: 44.h,
          dataRowMinHeight: 52.h,
          dataRowMaxHeight: 60.h,
          columnSpacing: 16.w,
          horizontalMargin: 16.w,
          columns: [
            _col('Ref #'),
            _col('Date'),
            _col('Type'),
            _col('Submitted By'),
            _col('Account'),
            _col('Amount'),
            _col('Status'),
            _col('Actions'),
          ],
          rows: expenses.map((e) => _buildRow(e, fp)).toList(),
        ),
      ),
    );
  }

  DataColumn _col(String label) {
    return DataColumn(
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF6B7280),
        ),
      ),
    );
  }

  DataRow _buildRow(ExpenseEntity expense, FinanceProvider fp) {
    return DataRow(
      cells: [
        DataCell(Text(
          expense.referenceNumber,
          style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: const Color(0xFF4F46E5)),
        )),
        DataCell(Text(
          DateFormat('dd MMM yyyy').format(expense.date),
          style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF374151)),
        )),
        DataCell(Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              expense.expenseType,
              style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w500, color: const Color(0xFF111827)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              expense.expenseCategory,
              style: GoogleFonts.inter(fontSize: 10.sp, color: const Color(0xFF9CA3AF)),
            ),
          ],
        )),
        DataCell(Text(
          expense.submittedBy,
          style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF374151)),
        )),
        DataCell(Text(
          expense.fundAccountName ?? '—',
          style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF374151)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        )),
        DataCell(Text(
          '${expense.amount.toStringAsFixed(2)} ${expense.currency}',
          style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: const Color(0xFF111827)),
        )),
        DataCell(ExpenseStatusBadge(status: expense.status)),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (expense.status == ExpenseStatus.pending) ...[
              _ActionBtn(
                icon: Icons.check_circle_outline,
                color: const Color(0xFF22C55E),
                tooltip: 'Approve',
                onTap: () => _approveExpense(expense, fp),
              ),
              SizedBox(width: 4.w),
              _ActionBtn(
                icon: Icons.cancel_outlined,
                color: const Color(0xFFEF4444),
                tooltip: 'Reject',
                onTap: () => _rejectExpense(expense, fp),
              ),
              SizedBox(width: 4.w),
            ],
            _ActionBtn(
              icon: Icons.edit_outlined,
              color: const Color(0xFF6B7280),
              tooltip: 'Edit',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ExpenseFormPage(expense: expense)),
                );
              },
            ),
            SizedBox(width: 4.w),
            _ActionBtn(
              icon: Icons.delete_outline,
              color: const Color(0xFFEF4444),
              tooltip: 'Delete',
              onTap: () => _deleteExpense(expense, fp),
            ),
          ],
        )),
      ],
    );
  }

  void _approveExpense(ExpenseEntity expense, FinanceProvider fp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
        title: Text('Approve Expense', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Text(
          'Approve ${expense.referenceNumber} — ${expense.amount.toStringAsFixed(2)} ${expense.currency} for ${expense.expenseType}?',
          style: GoogleFonts.inter(fontSize: 13.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () {
              fp.approveExpense(expense, 'ADMIN');
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
            ),
            child: Text('Approve', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _rejectExpense(ExpenseEntity expense, FinanceProvider fp) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
        title: Text('Reject Expense', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rejecting ${expense.referenceNumber} — ${expense.amount.toStringAsFixed(2)} ${expense.currency}',
              style: GoogleFonts.inter(fontSize: 13.sp),
            ),
            SizedBox(height: 14.h),
            TextField(
              controller: reasonController,
              maxLines: 3,
              style: GoogleFonts.inter(fontSize: 13.sp),
              decoration: InputDecoration(
                labelText: 'Reason for rejection',
                hintText: 'Enter reason...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () {
              fp.rejectExpense(expense, 'ADMIN', reasonController.text);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
            ),
            child: Text('Reject', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _deleteExpense(ExpenseEntity expense, FinanceProvider fp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
        title: Text('Delete Expense', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Text(
          'Are you sure you want to delete ${expense.referenceNumber}? This action cannot be undone.',
          style: GoogleFonts.inter(fontSize: 13.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () {
              fp.deleteExpense(expense.id);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
            ),
            child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF6366F1);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isSelected ? c.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected ? c : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.sp,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? c : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8.w,
          height: 8.w,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 6.w),
        Text(
          '$label: ',
          style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF6B7280)),
        ),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w600, color: const Color(0xFF111827)),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6.r),
        child: Padding(
          padding: EdgeInsets.all(4.w),
          child: Icon(icon, size: 18.sp, color: color),
        ),
      ),
    );
  }
}
