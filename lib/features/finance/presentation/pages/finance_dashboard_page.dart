import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:xloop_invoice/features/finance/presentation/providers/finance_provider.dart';
import 'package:xloop_invoice/features/finance/presentation/providers/fund_account_provider.dart';
import 'package:xloop_invoice/features/finance/presentation/providers/petty_cash_provider.dart';
import 'expense_list_page.dart';
import 'fund_accounts_page.dart';
import 'petty_cash_page.dart';
import 'expense_categories_page.dart';

/// Main finance module page with tabbed navigation.
///
/// Contains tabs for Expenses, Fund Accounts, Petty Cash, and Categories.
class FinanceDashboardPage extends StatefulWidget {
  const FinanceDashboardPage({super.key});

  @override
  State<FinanceDashboardPage> createState() => _FinanceDashboardPageState();
}

class _FinanceDashboardPageState extends State<FinanceDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _bgPage = Color(0xFFF4F6FB);

  final _tabs = const [
    _TabItem(icon: Icons.receipt_long_outlined, label: 'Expenses'),
    _TabItem(icon: Icons.account_balance_wallet_outlined, label: 'Fund Accounts'),
    _TabItem(icon: Icons.point_of_sale_outlined, label: 'Petty Cash'),
    _TabItem(icon: Icons.category_outlined, label: 'Categories'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);

    // Load initial data.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FinanceProvider>().fetchAllExpenses();
      context.read<FinanceProvider>().fetchCategories();
      context.read<FundAccountProvider>().fetchAllAccounts();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPage,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(28.w, 24.h, 28.w, 0),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                        ),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(
                        Icons.account_balance_outlined,
                        color: Colors.white,
                        size: 22.sp,
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Finance & Expenses',
                            style: GoogleFonts.inter(
                              fontSize: 22.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Consumer<FinanceProvider>(
                            builder: (_, fp, __) {
                              return Text(
                                fp.pendingCount > 0
                                    ? '${fp.pendingCount} expense${fp.pendingCount == 1 ? '' : 's'} pending approval'
                                    : 'All expenses up to date',
                                style: GoogleFonts.inter(
                                  fontSize: 13.sp,
                                  color: fp.pendingCount > 0
                                      ? const Color(0xFFD97706)
                                      : const Color(0xFF6B7280),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    // Quick stats
                    Consumer<FundAccountProvider>(
                      builder: (_, fap, __) {
                        return Container(
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.account_balance_wallet, size: 16.sp, color: const Color(0xFF16A34A)),
                              SizedBox(width: 8.w),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Total Balance',
                                    style: GoogleFonts.inter(
                                      fontSize: 10.sp,
                                      color: const Color(0xFF16A34A),
                                    ),
                                  ),
                                  Text(
                                    '${fap.totalBalance.toStringAsFixed(2)} SAR',
                                    style: GoogleFonts.inter(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF166534),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
                SizedBox(height: 18.h),
                // ── Tab bar ────────────────────────────────────
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: const Color(0xFF10B981),
                  unselectedLabelColor: const Color(0xFF6B7280),
                  indicatorColor: const Color(0xFF10B981),
                  indicatorSize: TabBarIndicatorSize.label,
                  indicatorWeight: 2.5,
                  tabAlignment: TabAlignment.start,
                  labelStyle: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: _tabs.map((t) {
                    return Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(t.icon, size: 16.sp),
                          SizedBox(width: 6.w),
                          Text(t.label),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          // ── Tab content ─────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                ExpenseListPage(),
                FundAccountsPage(),
                PettyCashPage(),
                ExpenseCategoriesPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final String label;
  const _TabItem({required this.icon, required this.label});
}
