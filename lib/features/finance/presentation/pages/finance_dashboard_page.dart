import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:xloop_invoice/features/finance/presentation/pages/expense_form_page.dart';
import '../providers/finance_provider.dart';
import '../providers/fund_account_provider.dart';
import '../widgets/expense_summary_card.dart';
import '../widgets/finance_nav_tabs.dart';
import 'expense_list_page.dart';
import 'fund_accounts_page.dart';
import 'petty_cash_page.dart';
import 'expense_categories_page.dart';
import '../../domain/entities/expense_entity.dart';
import '../../domain/entities/fund_account_entity.dart';

// ── Design tokens for Finance module ─────────────────────────────────────────
class FinDT {
  static const bgPage = Color(0xFFF4F6FB);
  static const bgCard = Colors.white;
  static const brand = Color(0xFF4F46E5);
  static const brandLight = Color(0xFFEEF2FF);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);
  static const border = Color(0xFFE5E7EB);
  static const borderLight = Color(0xFFF3F4F6);
  static const shadow = Color(0x0A000000);
  static const danger = Color(0xFFDC2626);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFD97706);
}

/// The main Finance & Expense Management screen.
///
/// Contains a tabbed interface:
/// - Overview (dashboard summary)
/// - Expenses (list with filters)
/// - Fund Accounts
/// - Petty Cash Sessions
/// - Expense Categories
class FinanceDashboardPage extends StatefulWidget {
  const FinanceDashboardPage({super.key});

  @override
  State<FinanceDashboardPage> createState() => _FinanceDashboardPageState();
}

class _FinanceDashboardPageState extends State<FinanceDashboardPage>
    with SingleTickerProviderStateMixin {
  int _selectedTab = 0;
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  bool _dataFetched = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);

    // Defer data fetching to avoid setState-during-build errors.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_dataFetched) {
        _dataFetched = true;
        _loadData();
      }
    });
  }

  Future<void> _loadData() async {
    final financeProvider = context.read<FinanceProvider>();
    final accountProvider = context.read<FundAccountProvider>();

    await Future.wait([
      financeProvider.fetchAllExpenses(),
      financeProvider.fetchCategories(),
      accountProvider.fetchAllAccounts(),
    ]);

    if (mounted) {
      _animController.forward();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinDT.bgPage,
      body: FadeTransition(
        opacity: _fadeIn,
        child: RefreshIndicator(
          color: FinDT.brand,
          onRefresh: _loadData,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Header ──────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(28.w, 28.h, 28.w, 0),
                  child: _buildHeader(),
                ),
              ),

              // ── Tab Navigation ──────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(28.w, 20.h, 28.w, 0),
                  child: FinanceNavTabs(
                    selectedIndex: _selectedTab,
                    onChanged: (index) {
                      setState(() => _selectedTab = index);
                    },
                  ),
                ),
              ),

              // ── Tab Content ─────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(28.w, 20.h, 28.w, 28.h),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildTabContent(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, MMMM d, y').format(now);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Finance & Expenses',
                style: GoogleFonts.inter(
                  fontSize: 26.sp,
                  fontWeight: FontWeight.w800,
                  color: FinDT.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                dateStr,
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w400,
                  color: FinDT.textSecondary,
                ),
              ),
            ],
          ),
        ),
        _buildActionButton(
          icon: Icons.add_rounded,
          label: 'New Expense',
          onTap: () => _navigateToExpenseForm(),
        ),
        SizedBox(width: 10.w),
        _buildActionButton(
          icon: Icons.refresh_rounded,
          label: 'Refresh',
          isPrimary: false,
          onTap: _loadData,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = true,
  }) {
    return Material(
      color: isPrimary ? FinDT.brand : Colors.white,
      borderRadius: BorderRadius.circular(12.r),
      elevation: isPrimary ? 0 : 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            border: isPrimary ? null : Border.all(color: FinDT.border),
            boxShadow: isPrimary
                ? [
                    BoxShadow(
                      color: FinDT.brand.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16.sp,
                color: isPrimary ? Colors.white : FinDT.textSecondary,
              ),
              SizedBox(width: 6.w),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: isPrimary ? Colors.white : FinDT.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _OverviewTab(key: const ValueKey('overview'));
      case 1:
        return const ExpenseListPage(key: ValueKey('expenses'));
      case 2:
        return const FundAccountsPage(key: ValueKey('accounts'));
      case 3:
        return const PettyCashPage(key: ValueKey('petty'));
      case 4:
        return const ExpenseCategoriesPage(key: ValueKey('categories'));
      default:
        return const SizedBox.shrink();
    }
  }

  void _navigateToExpenseForm() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ExpenseFormPage()),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// OVERVIEW TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<FinanceProvider, FundAccountProvider>(
      builder: (context, finProv, accProv, _) {
        if (finProv.isLoading || accProv.isLoading) {
          return _buildLoadingState();
        }

        final formatter = NumberFormat('#,##0.00', 'en_US');
        final expenses = finProv.expenses;
        final totalExpenses = expenses.fold(0.0, (sum, e) => sum + e.amount);
        final pendingCount = expenses
            .where((e) => e.status == ExpenseStatus.pending)
            .length;
        final thisMonthExpenses = expenses
            .where(
              (e) =>
                  e.date.month == DateTime.now().month &&
                  e.date.year == DateTime.now().year,
            )
            .fold(0.0, (sum, e) => sum + e.amount);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Stat Cards ──────────────────────────────────
            GridView.count(
              crossAxisCount: 4,
              mainAxisSpacing: 16.h,
              crossAxisSpacing: 16.w,
              childAspectRatio: 1.6,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                ExpenseSummaryCard(
                  label: 'Total Expenses',
                  value: '${formatter.format(totalExpenses)} SAR',
                  icon: Icons.payments_outlined,
                  startColor: const Color(0xFF4F46E5),
                  endColor: const Color(0xFF7C3AED),
                  subtitle: '${expenses.length} records',
                ),
                ExpenseSummaryCard(
                  label: 'This Month',
                  value: '${formatter.format(thisMonthExpenses)} SAR',
                  icon: Icons.calendar_month_outlined,
                  startColor: const Color(0xFF0891B2),
                  endColor: const Color(0xFF06B6D4),
                  subtitle: DateFormat('MMMM y').format(DateTime.now()),
                ),
                ExpenseSummaryCard(
                  label: 'Pending Approval',
                  value: '$pendingCount',
                  icon: Icons.pending_actions_outlined,
                  startColor: const Color(0xFFD97706),
                  endColor: const Color(0xFFF59E0B),
                  subtitle: 'Requires review',
                ),
                ExpenseSummaryCard(
                  label: 'Total Accounts',
                  value: '${formatter.format(accProv.totalBalance)} SAR',
                  icon: Icons.account_balance_wallet_outlined,
                  startColor: const Color(0xFF16A34A),
                  endColor: const Color(0xFF22C55E),
                  subtitle: '${accProv.activeAccounts.length} active',
                ),
              ],
            ),

            SizedBox(height: 24.h),

            // ── Recent Expenses ─────────────────────────────
            _SectionCard(
              title: 'Recent Expenses',
              subtitle:
                  'Last ${expenses.length > 10 ? 10 : expenses.length} records',
              actionLabel: 'View All',
              onAction: () {},
              child: expenses.isEmpty
                  ? _buildEmptyState(
                      'No expenses recorded yet',
                      'Start by adding your first expense record',
                      Icons.receipt_long_outlined,
                    )
                  : _RecentExpensesList(
                      expenses: expenses.take(10).toList(),
                      accounts: accProv.accounts,
                    ),
            ),

            SizedBox(height: 16.h),

            // ── Fund Account Summary ────────────────────────
            _SectionCard(
              title: 'Fund Accounts',
              subtitle: '${accProv.activeAccounts.length} active accounts',
              actionLabel: 'Manage',
              onAction: () {},
              child: accProv.accounts.isEmpty
                  ? _buildEmptyState(
                      'No fund accounts yet',
                      'Create your first virtual account to start tracking',
                      Icons.account_balance_outlined,
                    )
                  : _FundAccountsSummary(accounts: accProv.activeAccounts),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        GridView.count(
          crossAxisCount: 4,
          mainAxisSpacing: 16.h,
          crossAxisSpacing: 16.w,
          childAspectRatio: 1.6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(
            4,
            (_) => Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Center(
                child: SizedBox(
                  width: 24.w,
                  height: 24.w,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: FinDT.brand,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 40.h),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: FinDT.brandLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32.sp, color: FinDT.brand),
            ),
            SizedBox(height: 16.h),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: FinDT.textPrimary,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              subtitle,
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
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION CARD WRAPPER
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget child;

  const _SectionCard({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: FinDT.border),
        boxShadow: [
          BoxShadow(
            color: FinDT.shadow,
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(20.w),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          color: FinDT.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        SizedBox(height: 2.h),
                        Text(
                          subtitle!,
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            color: FinDT.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (actionLabel != null && onAction != null)
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      foregroundColor: FinDT.brand,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 6.h,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    child: Text(
                      actionLabel!,
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: FinDT.borderLight),
          child,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// RECENT EXPENSES LIST
// ═══════════════════════════════════════════════════════════════════════════════

class _RecentExpensesList extends StatelessWidget {
  final List<ExpenseEntity> expenses;
  final List<FundAccountEntity> accounts;

  const _RecentExpensesList({
    required this.expenses,
    required this.accounts,
  });

  String _resolveAccountName(ExpenseEntity expense) {
    if (expense.fundAccountName != null &&
        expense.fundAccountName!.trim().isNotEmpty) {
      return expense.fundAccountName!;
    }
    try {
      return accounts
          .firstWhere((a) => a.id == expense.fundAccountId)
          .name;
    } catch (_) {
      return expense.fundAccountId.isEmpty ? '—' : expense.fundAccountId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: expenses.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: FinDT.borderLight),
      itemBuilder: (context, index) {
        final expense = expenses[index];
        final statusColor = _statusColor(expense.status);
        final accountName = _resolveAccountName(expense);

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
          child: Row(
            children: [
              // Type icon
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  _categoryIcon(expense.expenseCategory),
                  color: statusColor,
                  size: 18.sp,
                ),
              ),
              SizedBox(width: 14.w),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            expense.expenseType,
                            style: GoogleFonts.inter(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: FinDT.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            expense.status.displayName,
                            style: GoogleFonts.inter(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      '${expense.referenceNumber} • ${expense.submittedBy} • ${DateFormat('dd MMM yyyy').format(expense.date)}',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        color: FinDT.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: FinDT.brandLight,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 10.sp,
                            color: FinDT.brand,
                          ),
                          SizedBox(width: 4.w),
                          Flexible(
                            child: Text(
                              accountName,
                              style: GoogleFonts.inter(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w600,
                                color: FinDT.brand,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Amount
              Text(
                '${formatter.format(expense.amount)} ${expense.currency}',
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: FinDT.textPrimary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _statusColor(ExpenseStatus status) {
    switch (status) {
      case ExpenseStatus.pending:
        return FinDT.warning;
      case ExpenseStatus.approved:
        return FinDT.success;
      case ExpenseStatus.rejected:
        return FinDT.danger;
      case ExpenseStatus.closed:
        return FinDT.textSecondary;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category.toUpperCase()) {
      case 'COMPANY':
        return Icons.business_outlined;
      case 'EMPLOYEES':
        return Icons.badge_outlined;
      case 'VEHICLES':
        return Icons.directions_car_outlined;
      default:
        return Icons.receipt_outlined;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FUND ACCOUNTS SUMMARY
// ═══════════════════════════════════════════════════════════════════════════════

class _FundAccountsSummary extends StatelessWidget {
  final List accounts;

  const _FundAccountsSummary({required this.accounts});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: accounts.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: FinDT.borderLight),
      itemBuilder: (context, index) {
        final account = accounts[index];
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: FinDT.brand.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: FinDT.brand,
                  size: 18.sp,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: FinDT.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      account.code,
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        color: FinDT.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${formatter.format(account.currentBalance)} ${account.currency}',
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: account.currentBalance >= 0
                      ? FinDT.textPrimary
                      : FinDT.danger,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
