import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../employee/domain/entities/employee_entity.dart';
import '../../../employee/presentation/providers/employee_provider.dart';
import '../providers/petty_cash_provider.dart';
import '../providers/fund_account_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/cash_advance_provider.dart';
import '../../domain/entities/cash_advance_entity.dart';
import '../../domain/entities/fund_transaction_entity.dart';
import '../../domain/entities/petty_cash_session_entity.dart';
import '../../domain/entities/session_expense_item.dart';
import '../../domain/entities/fund_account_entity.dart';
import '../../domain/services/finance_permission_service.dart';
import '../widgets/expense_review_dialog.dart';
import '../widgets/finance_dialog_helpers.dart';
import 'finance_dashboard_page.dart';

/// Screen for managing daily petty cash open/close flows and verification.
class PettyCashPage extends StatefulWidget {
  const PettyCashPage({super.key});

  @override
  State<PettyCashPage> createState() => _PettyCashPageState();
}

class _PettyCashPageState extends State<PettyCashPage> {
  String? _selectedAccountId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final accProv = context.read<FundAccountProvider>();
      final pettyAccounts = accProv.activeAccounts
          .where((a) => a.isPettyCash)
          .toList();

      if (pettyAccounts.isNotEmpty) {
        setState(() => _selectedAccountId = pettyAccounts.first.id);
        context.read<PettyCashProvider>().loadSessions(pettyAccounts.first.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final accProv = context.watch<FundAccountProvider>();
    final pettyAccounts = accProv.activeAccounts
        .where((a) => a.isPettyCash)
        .toList();

    return Consumer<PettyCashProvider>(
      builder: (context, provider, _) {
        final selectedAcc = accProv.getAccountById(_selectedAccountId ?? '');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Petty Cash & Daily Register',
                      style: GoogleFonts.inter(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: FinDT.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Daily drawer sessions, cash counting, live ledger totals, and closing audit',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: FinDT.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (provider.currentSession != null)
                  OutlinedButton.icon(
                    onPressed: () => provider.refreshDayTotals(),
                    icon: Icon(Icons.sync_rounded, size: 16.sp),
                    label: Text(
                      'Sync Ledger',
                      style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FinDT.brand,
                      side: BorderSide(color: FinDT.brand.withValues(alpha: 0.4)),
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 16.h),

            // Account selection bar
            _buildAccountSelector(pettyAccounts, provider, selectedAcc),
            SizedBox(height: 20.h),

            if (_selectedAccountId == null)
              _buildNoPettyAccounts()
            else ...[
              // Current Session Status Card & KPI Metrics
              _buildCurrentSessionCard(context, provider, selectedAcc),
              SizedBox(height: 24.h),

              // Sessions History
              _buildSessionsHistory(context, provider),
            ],
          ],
        );
      },
    );
  }

  Widget _buildAccountSelector(
    List<FundAccountEntity> accounts,
    PettyCashProvider provider,
    FundAccountEntity? selectedAcc,
  ) {
    final formatter = NumberFormat('#,##0.00', 'en_US');

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: FinDT.border),
        boxShadow: [
          BoxShadow(
            color: FinDT.shadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(Icons.storefront_outlined, color: const Color(0xFF16A34A), size: 22.sp),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ACTIVE PETTY CASH DRAWER',
                  style: GoogleFonts.inter(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: FinDT.textSecondary,
                  ),
                ),
                SizedBox(height: 2.h),
                Row(
                  children: [
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedAccountId,
                        items: accounts
                            .map((a) => DropdownMenuItem(
                                  value: a.id,
                                  child: Text(
                                    '${a.name} (${a.code})',
                                    style: GoogleFonts.inter(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w700,
                                      color: FinDT.textPrimary,
                                    ),
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _selectedAccountId = v);
                            provider.loadSessions(v);
                          }
                        },
                      ),
                    ),
                    if (selectedAcc?.assignedTo != null && selectedAcc!.assignedTo!.isNotEmpty) ...[
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: FinDT.bgPage,
                          borderRadius: BorderRadius.circular(6.r),
                          border: Border.all(color: FinDT.border),
                        ),
                        child: Text(
                          'Coordinator: ${selectedAcc.assignedTo}',
                          style: GoogleFonts.inter(fontSize: 10.sp, color: FinDT.textSecondary),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Drawer Balance Pill
          if (selectedAcc != null) ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: FinDT.bgPage,
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: FinDT.border),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Total Balance',
                        style: GoogleFonts.inter(fontSize: 9.sp, color: FinDT.textSecondary, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 1.h),
                      Text(
                        '${formatter.format(selectedAcc.currentBalance)} SAR',
                        style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w800, color: FinDT.textPrimary),
                      ),
                    ],
                  ),
                  SizedBox(width: 12.w),
                  Container(height: 24.h, width: 1, color: FinDT.border),
                  SizedBox(width: 12.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.payments_outlined, size: 11.sp, color: const Color(0xFF16A34A)),
                          SizedBox(width: 3.w),
                          Text('Cash: ${formatter.format(selectedAcc.cashBalance)}', style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w600, color: FinDT.textPrimary)),
                        ],
                      ),
                      SizedBox(height: 2.h),
                      Row(
                        children: [
                          Icon(Icons.phone_android_outlined, size: 11.sp, color: const Color(0xFF7C3AED)),
                          SizedBox(width: 3.w),
                          Text('STC: ${formatter.format(selectedAcc.stcPayBalance)}', style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w600, color: FinDT.textPrimary)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoPettyAccounts() {
    return Container(
      padding: EdgeInsets.all(40.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: FinDT.border),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 40.sp, color: FinDT.textMuted),
            SizedBox(height: 12.h),
            Text(
              'No Petty Cash Accounts Configured',
              style: GoogleFonts.inter(fontSize: 15.sp, fontWeight: FontWeight.w700, color: FinDT.textPrimary),
            ),
            SizedBox(height: 4.h),
            Text(
              'Please create a Petty Cash account in the Virtual Accounts tab first.',
              style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentSessionCard(
    BuildContext context,
    PettyCashProvider provider,
    FundAccountEntity? selectedAcc,
  ) {
    final session = provider.currentSession;
    final formatter = NumberFormat('#,##0.00', 'en_US');

    return Container(
      padding: EdgeInsets.all(22.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: FinDT.border),
        boxShadow: [
          BoxShadow(
            color: FinDT.shadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Session Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10.w,
                    height: 10.w,
                    decoration: BoxDecoration(
                      color: session != null ? const Color(0xFF16A34A) : FinDT.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session != null ? 'Active Daily Session' : 'No Open Session for Today',
                        style: GoogleFonts.inter(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          color: FinDT.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        session != null
                            ? 'Opened on ${DateFormat('dd MMMM yyyy, hh:mm a').format(session.date)} • By ${session.openedBy}'
                            : 'Open the drawer to set starting cash & digital balances and enable daily spending',
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          color: FinDT.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (session != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: const Color(0xFF16A34A), size: 14.sp),
                      SizedBox(width: 4.w),
                      Text(
                        'Live & Open',
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: FinDT.textSecondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    'Drawer Closed',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: FinDT.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 20.h),

          if (session != null) ...[
            Builder(builder: (_) {
              final live = provider.previewTotals;
              final cashExp = live?.cashExpenses ?? session.cashExpenses;
              final stcExp = live?.stcPayExpenses ?? session.stcPayExpenses;
              final cashDep = live?.cashDeposits ?? session.cashDeposits;
              final stcDep = live?.stcPayDeposits ?? session.stcPayDeposits;
              final expTotal = cashExp + stcExp;
              final depTotal = cashDep + stcDep;
              final expectedCash =
                  session.openingCashBalance + cashDep - cashExp;
              final expectedStc =
                  session.openingStcPayBalance + stcDep - stcExp;
              final expected = expectedCash + expectedStc;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 4 Hero KPI Cards in a row
                  Row(
                    children: [
                      // 1. Opening Total
                      Expanded(
                        child: _buildSessionKpiCard(
                          title: 'OPENING BALANCE',
                          value: '${formatter.format(session.openingBalance)} SAR',
                          icon: Icons.storefront_outlined,
                          accentColor: FinDT.brand,
                          cashValue: '${formatter.format(session.openingCashBalance)} SAR',
                          stcValue: '${formatter.format(session.openingStcPayBalance)} SAR',
                        ),
                      ),
                      SizedBox(width: 12.w),

                      // 2. Today's Expenses
                      Expanded(
                        child: InkWell(
                          onTap: () => _showSessionExpensesDialog(context, provider, session),
                          borderRadius: BorderRadius.circular(16.r),
                          child: _buildSessionKpiCard(
                            title: "TODAY'S EXPENSES",
                            value: '${formatter.format(expTotal)} SAR',
                            icon: Icons.arrow_upward_rounded,
                            accentColor: const Color(0xFFDC2626),
                            cashValue: '${formatter.format(cashExp)} SAR',
                            stcValue: '${formatter.format(stcExp)} SAR',
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),

                      // 3. Today's Deposits
                      Expanded(
                        child: _buildSessionKpiCard(
                          title: "TODAY'S DEPOSITS",
                          value: '${formatter.format(depTotal)} SAR',
                          icon: Icons.arrow_downward_rounded,
                          accentColor: const Color(0xFF16A34A),
                          cashValue: '${formatter.format(cashDep)} SAR',
                          stcValue: '${formatter.format(stcDep)} SAR',
                        ),
                      ),
                      SizedBox(width: 12.w),

                      // 4. Expected Closing
                      Expanded(
                        child: _buildSessionKpiCard(
                          title: 'EXPECTED CLOSING',
                          value: '${formatter.format(expected)} SAR',
                          icon: Icons.lock_clock_outlined,
                          accentColor: FinDT.brand,
                          highlight: true,
                          cashValue: '${formatter.format(expectedCash)} SAR',
                          stcValue: '${formatter.format(expectedStc)} SAR',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),

                  // Close Session Action Bar (permission-gated)
                  Builder(builder: (_) {
                    final user = context.read<AuthProvider>().user;
                    final selectedAcc = context.read<FundAccountProvider>().getAccountById(_selectedAccountId ?? '');
                    final policy = context.read<FinanceProvider>().policy;
                    final canClose = selectedAcc != null &&
                        FinancePermissionService.canCloseSession(
                          user: user,
                          account: selectedAcc,
                          policy: policy,
                        );
                    if (!canClose) return const SizedBox.shrink();
                    return Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showCloseSessionDialog(context, provider, session),
                            icon: Icon(Icons.lock_clock_outlined, size: 18.sp),
                            label: Text(
                              'Close Daily Session & Declare Cash Count',
                              style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: FinDT.brand,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              );
            }),
          ] else ...[
            Builder(builder: (_) {
              final now = DateTime.now();
              final todayDate = DateTime(now.year, now.month, now.day);
              final todaySession = provider.sessions.where((s) {
                final sDate = DateTime(s.date.year, s.date.month, s.date.day);
                return sDate == todayDate;
              }).firstOrNull;

              if (todaySession != null &&
                  todaySession.status == PettyCashSessionStatus.verified) {
                return Container(
                  padding: EdgeInsets.all(18.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Icon(
                          Icons.verified_user_rounded,
                          color: const Color(0xFF16A34A),
                          size: 22.sp,
                        ),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Today\'s Register is Verified & Locked',
                                  style: GoogleFonts.inter(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w700,
                                    color: FinDT.textPrimary,
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 2.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6.r),
                                  ),
                                  child: Text(
                                    'LOCKED',
                                    style: GoogleFonts.inter(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF16A34A),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 3.h),
                            Text(
                              'The register for today (${DateFormat('dd MMMM yyyy').format(todaySession.date)}) was verified by ${todaySession.verifiedBy ?? 'Admin'} and day is locked. A new session can be opened tomorrow.',
                              style: GoogleFonts.inter(
                                fontSize: 11.sp,
                                color: FinDT.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (todaySession != null &&
                  todaySession.status == PettyCashSessionStatus.closed) {
                return Container(
                  padding: EdgeInsets.all(18.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: const Color(0xFFD97706).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Icon(
                          Icons.lock_clock_outlined,
                          color: const Color(0xFFD97706),
                          size: 22.sp,
                        ),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Today\'s Register is Closed (Pending Verification)',
                                  style: GoogleFonts.inter(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w700,
                                    color: FinDT.textPrimary,
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 2.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD97706).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6.r),
                                  ),
                                  child: Text(
                                    'PENDING AUDIT',
                                    style: GoogleFonts.inter(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFFD97706),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 3.h),
                            Text(
                              'Closed by ${todaySession.closedBy ?? 'Coordinator'} with declared closing balance of ${formatter.format(todaySession.closingBalance)} SAR. Please review and verify the session in the list below to lock the day.',
                              style: GoogleFonts.inter(
                                fontSize: 11.sp,
                                color: FinDT.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              final user = context.read<AuthProvider>().user;
              final selectedAcc = context.read<FundAccountProvider>().getAccountById(_selectedAccountId ?? '');
              final policy = context.read<FinanceProvider>().policy;
              final canOpen = selectedAcc != null &&
                  FinancePermissionService.canOpenSession(
                    user: user,
                    account: selectedAcc,
                    policy: policy,
                  );

              return Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: FinDT.bgPage,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: FinDT.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            canOpen
                                ? 'Ready to start today\'s transactions?'
                                : 'Session Not Opened Yet',
                            style: GoogleFonts.inter(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: FinDT.textPrimary,
                            ),
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            canOpen
                                ? 'Open the daily session to record physical cash in drawer and digital STC balance.'
                                : (selectedAcc?.assignedTo != null && selectedAcc!.assignedTo!.isNotEmpty
                                    ? 'Assigned to ${selectedAcc.assignedTo}. Only assigned coordinator or admin can open the daily session.'
                                    : 'Only authorized personnel or admin can open the daily session for this account.'),
                            style: GoogleFonts.inter(
                              fontSize: 11.sp,
                              color: FinDT.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canOpen)
                      ElevatedButton.icon(
                        onPressed: () => _showOpenSessionDialog(context, provider),
                        icon: Icon(Icons.storefront_outlined, size: 16.sp),
                        label: Text(
                          'Open Daily Session',
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FinDT.brand,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(
                            horizontal: 20.w,
                            vertical: 12.h,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildSessionKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
    required String cashValue,
    required String stcValue,
    bool highlight = false,
  }) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: highlight ? FinDT.brand.withValues(alpha: 0.05) : FinDT.bgPage,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: highlight ? FinDT.brand.withValues(alpha: 0.3) : FinDT.border,
          width: highlight ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: highlight ? FinDT.brand : FinDT.textSecondary,
                ),
              ),
              Icon(icon, size: 14.sp, color: accentColor),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: highlight ? FinDT.brand : FinDT.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 8.h),
          Divider(height: 1, color: FinDT.border),
          SizedBox(height: 6.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Cash: $cashValue', style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w500, color: FinDT.textSecondary)),
              Text('STC: $stcValue', style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w500, color: const Color(0xFF7C3AED))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsHistory(BuildContext context, PettyCashProvider provider) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: FinDT.border),
        boxShadow: [
          BoxShadow(
            color: FinDT.shadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(18.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session Logs & Closing Reconciliation',
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: FinDT.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Audit trail of declared closing balances, discrepancies, and manager verifications',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        color: FinDT.textSecondary,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${provider.sessions.length} recorded sessions',
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    color: FinDT.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: FinDT.borderLight),
          if (provider.sessions.isEmpty)
            Padding(
              padding: EdgeInsets.all(40.w),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.history_toggle_off_rounded, size: 36.sp, color: FinDT.textMuted),
                    SizedBox(height: 8.h),
                    Text(
                      'No historical sessions recorded for this account',
                      style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: provider.sessions.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: FinDT.borderLight),
              itemBuilder: (context, index) {
                final session = provider.sessions[index];
                final isClosed = session.status == PettyCashSessionStatus.closed;
                final isVerified = session.status == PettyCashSessionStatus.verified;
                final discrepancy = session.discrepancy ?? 0.0;
                final isBalanced = discrepancy.abs() < 0.01;

                final live = (session.id == provider.currentSession?.id) ? provider.previewTotals : null;
                final cashExp = live?.cashExpenses ?? session.cashExpenses;
                final stcExp = live?.stcPayExpenses ?? session.stcPayExpenses;
                final totalExp = cashExp + stcExp;
                final cashDep = live?.cashDeposits ?? session.cashDeposits;
                final stcDep = live?.stcPayDeposits ?? session.stcPayDeposits;
                final totalDep = cashDep + stcDep;
                final expectedBal = live != null
                    ? (session.openingBalance + totalDep - totalExp)
                    : session.expectedClosingBalance;

                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 14.h),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: isVerified
                              ? const Color(0xFF16A34A).withValues(alpha: 0.1)
                              : (isClosed ? const Color(0xFFD97706).withValues(alpha: 0.1) : FinDT.brand.withValues(alpha: 0.1)),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Icon(
                          isVerified
                              ? Icons.verified_user_outlined
                              : (isClosed ? Icons.pending_actions_rounded : Icons.storefront_outlined),
                          color: isVerified
                              ? const Color(0xFF16A34A)
                              : (isClosed ? const Color(0xFFD97706) : FinDT.brand),
                          size: 20.sp,
                        ),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  DateFormat('EEEE, dd MMMM yyyy').format(session.date),
                                  style: GoogleFonts.inter(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w700,
                                    color: FinDT.textPrimary,
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                if (isVerified)
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6.r),
                                    ),
                                    child: Text(
                                      'VERIFIED & LOCKED',
                                      style: GoogleFonts.inter(
                                        fontSize: 9.sp,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF16A34A),
                                      ),
                                    ),
                                  )
                                else if (isClosed)
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD97706).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6.r),
                                    ),
                                    child: Text(
                                      'CLOSED • PENDING VERIFICATION',
                                      style: GoogleFonts.inter(
                                        fontSize: 9.sp,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFFD97706),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: 4.h),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6.w,
                              runSpacing: 4.h,
                              children: [
                                Text(
                                  'Opening: ${formatter.format(session.openingBalance)} SAR',
                                  style: GoogleFonts.inter(fontSize: 11.sp, color: FinDT.textSecondary),
                                ),
                                Text('•', style: TextStyle(color: FinDT.border, fontSize: 11.sp)),
                                InkWell(
                                  onTap: () => _showSessionExpensesDialog(context, provider, session),
                                  borderRadius: BorderRadius.circular(6.r),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                    decoration: BoxDecoration(
                                      color: totalExp > 0
                                          ? const Color(0xFFDC2626).withValues(alpha: 0.08)
                                          : FinDT.bgPage,
                                      borderRadius: BorderRadius.circular(6.r),
                                      border: Border.all(
                                        color: totalExp > 0
                                            ? const Color(0xFFDC2626).withValues(alpha: 0.25)
                                            : FinDT.border,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.arrow_upward_rounded,
                                          size: 11.sp,
                                          color: totalExp > 0 ? const Color(0xFFDC2626) : FinDT.textSecondary,
                                        ),
                                        SizedBox(width: 3.w),
                                        Text(
                                          'Expenses: ${formatter.format(totalExp)} SAR',
                                          style: GoogleFonts.inter(
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.w700,
                                            color: totalExp > 0 ? const Color(0xFFDC2626) : FinDT.textSecondary,
                                          ),
                                        ),
                                        if (cashExp > 0 || stcExp > 0) ...[
                                          SizedBox(width: 4.w),
                                          Text(
                                            '(${formatter.format(cashExp)} cash • ${formatter.format(stcExp)} stc)',
                                            style: GoogleFonts.inter(
                                              fontSize: 10.sp,
                                              fontWeight: FontWeight.w500,
                                              color: totalExp > 0
                                                  ? const Color(0xFFDC2626).withValues(alpha: 0.85)
                                                  : FinDT.textMuted,
                                            ),
                                          ),
                                        ],
                                        SizedBox(width: 4.w),
                                        Icon(
                                          Icons.open_in_new_rounded,
                                          size: 10.sp,
                                          color: totalExp > 0
                                              ? const Color(0xFFDC2626).withValues(alpha: 0.7)
                                              : FinDT.textMuted,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (totalDep > 0) ...[
                                  Text('•', style: TextStyle(color: FinDT.border, fontSize: 11.sp)),
                                  Text(
                                    'Deposits: +${formatter.format(totalDep)} SAR',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF16A34A),
                                    ),
                                  ),
                                ],
                                Text('•', style: TextStyle(color: FinDT.border, fontSize: 11.sp)),
                                Text(
                                  'Expected: ${formatter.format(expectedBal)} SAR',
                                  style: GoogleFonts.inter(fontSize: 11.sp, color: FinDT.textSecondary),
                                ),
                                Text('•', style: TextStyle(color: FinDT.border, fontSize: 11.sp)),
                                Text(
                                  'Declared: ${formatter.format(session.closingBalance)} SAR',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w600,
                                    color: FinDT.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 3.h),
                            Row(
                              children: [
                                Text(
                                  'Closed by ${(session.closedBy != null && session.closedBy!.isNotEmpty) ? session.closedBy! : session.openedBy}',
                                  style: GoogleFonts.inter(fontSize: 10.sp, color: FinDT.textMuted),
                                ),
                                if (session.verifiedBy != null && session.verifiedBy!.isNotEmpty) ...[
                                  Text(
                                    ' • Verified by ${session.verifiedBy}',
                                    style: GoogleFonts.inter(fontSize: 10.sp, color: const Color(0xFF16A34A)),
                                  ),
                                ],
                              ],
                            ),
                            if (session.notes != null && session.notes!.trim().isNotEmpty) ...[
                              SizedBox(height: 3.h),
                              Text(
                                'Note: ${session.notes!.trim()}',
                                style: GoogleFonts.inter(
                                  fontSize: 10.sp,
                                  fontStyle: FontStyle.italic,
                                  color: FinDT.textSecondary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(width: 14.w),

                      // Discrepancy & Verification Action
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _showSessionExpensesDialog(context, provider, session),
                                icon: Icon(Icons.receipt_long_rounded, size: 13.sp),
                                label: Text(
                                  'View Expenses',
                                  style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w600),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: FinDT.brand,
                                  side: BorderSide(color: FinDT.brand.withValues(alpha: 0.3)),
                                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  color: isBalanced
                                      ? const Color(0xFF16A34A).withValues(alpha: 0.1)
                                      : (discrepancy > 0
                                          ? const Color(0xFF16A34A).withValues(alpha: 0.1)
                                          : const Color(0xFFDC2626).withValues(alpha: 0.1)),
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Text(
                                  isBalanced
                                      ? 'Balanced'
                                      : (discrepancy > 0
                                          ? '+${formatter.format(discrepancy)} SAR Overage'
                                          : '${formatter.format(discrepancy)} SAR Shortage'),
                                  style: GoogleFonts.inter(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w700,
                                    color: isBalanced
                                        ? const Color(0xFF16A34A)
                                        : (discrepancy > 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (isClosed) ...[
                            Builder(builder: (_) {
                              final user = context.read<AuthProvider>().user;
                              final policy = context.read<FinanceProvider>().policy;
                              final canVerify = FinancePermissionService.canVerifySession(
                                user: user,
                                policy: policy,
                              );
                              if (!canVerify) return const SizedBox.shrink();
                              final hasDiscrepancy = discrepancy.abs() >= 0.01;
                              return Padding(
                                padding: EdgeInsets.only(top: 8.h),
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    if (hasDiscrepancy) {
                                      _showDiscrepancyResolutionDialog(context, provider, session);
                                    } else {
                                      _confirmVerifySession(context, provider, session);
                                    }
                                  },
                                  icon: Icon(
                                    hasDiscrepancy ? Icons.gavel_rounded : Icons.verified_user_outlined,
                                    size: 13.sp,
                                  ),
                                  label: Text(
                                    hasDiscrepancy ? 'Resolve Discrepancy' : 'Verify & Lock Day',
                                    style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w600),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: hasDiscrepancy
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFF16A34A),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ─── Daily Open / Close Dialogs ─────────────────────────────

  void _showOpenSessionDialog(BuildContext context, PettyCashProvider provider) {
    final accProv = context.read<FundAccountProvider>();
    final selectedAcc = accProv.getAccountById(_selectedAccountId ?? '');
    final currentCash = selectedAcc?.cashBalance ?? 0.0;
    final currentStc = selectedAcc?.stcPayBalance ?? 0.0;
    final currentTotal = selectedAcc?.currentBalance ?? (currentCash + currentStc);
    final formatter = NumberFormat('#,##0.00', 'en');
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: finDialogShape,
          title: finDialogTitle('Open Daily Session', icon: Icons.storefront_outlined),
          content: SizedBox(
            width: 440.w,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info banner
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: FinDT.brand.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: FinDT.brand.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16.sp, color: FinDT.brand),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'Opening balances are automatically snapshotted from the live ledger. You cannot edit them.',
                          style: GoogleFonts.inter(fontSize: 11.sp, color: FinDT.brand),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),

                // Read-only balance display
                _balanceSnapshotRow('Cash Balance', currentCash, Icons.payments_outlined, formatter),
                SizedBox(height: 10.h),
                _balanceSnapshotRow('STC Pay Balance', currentStc, Icons.phone_android_outlined, formatter),
                SizedBox(height: 14.h),

                // Total
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                  decoration: BoxDecoration(
                    color: FinDT.brand.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Opening Balance:',
                        style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: FinDT.textPrimary),
                      ),
                      Text(
                        '${formatter.format(currentTotal)} SAR',
                        style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w700, color: FinDT.brand),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            finDialogCancelButton(
              ctx,
              onPressed: isSubmitting ? () {} : null,
            ),
            finDialogActionButton(
              onPressed: () async {
                setDialogState(() => isSubmitting = true);
                final session = PettyCashSessionEntity(
                  id: const Uuid().v4(),
                  fundAccountId: _selectedAccountId!,
                  date: DateTime.now(),
                  openedBy: context.read<AuthProvider>().user?.actorLabel ?? 'Unknown',
                  openingCashBalance: currentCash,
                  openingStcPayBalance: currentStc,
                  createdAt: DateTime.now(),
                );

                try {
                  await provider.openSession(session);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    setDialogState(() => isSubmitting = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e
                            .toString()
                            .replaceAll('Exception: ', '')
                            .replaceAll('StateError: ', '')),
                        backgroundColor: const Color(0xFFDC2626),
                      ),
                    );
                  }
                }
              },
              label: 'Open Session',
              backgroundColor: FinDT.brand,
              isLoading: isSubmitting,
            ),
          ],
        ),
      ),
    );
  }

  Widget _balanceSnapshotRow(String label, double amount, IconData icon, NumberFormat formatter) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: FinDT.bgPage,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: FinDT.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16.sp, color: FinDT.textSecondary),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textSecondary),
            ),
          ),
          Text(
            '${formatter.format(amount)} SAR',
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: FinDT.textPrimary,
            ),
          ),
          SizedBox(width: 6.w),
          Icon(Icons.lock_outline_rounded, size: 13.sp, color: FinDT.textSecondary),
        ],
      ),
    );
  }

  void _showCloseSessionDialog(
    BuildContext context,
    PettyCashProvider provider,
    PettyCashSessionEntity session,
  ) {
    final formKey = GlobalKey<FormState>();
    final live = provider.previewTotals;
    final liveCashDep = live?.cashDeposits ?? session.cashDeposits;
    final liveStcDep = live?.stcPayDeposits ?? session.stcPayDeposits;
    final liveCashExp = live?.cashExpenses ?? session.cashExpenses;
    final liveStcExp = live?.stcPayExpenses ?? session.stcPayExpenses;
    final expectedCash = session.openingCashBalance + liveCashDep - liveCashExp;
    final expectedStc = session.openingStcPayBalance + liveStcDep - liveStcExp;
    final expectedTotal = expectedCash + expectedStc;
    final cashCtrl = TextEditingController(text: expectedCash.toStringAsFixed(2));
    final digitalCtrl = TextEditingController(text: expectedStc.toStringAsFixed(2));
    final notesCtrl = TextEditingController();
    final formatter = NumberFormat('#,##0.00', 'en_US');
    String? closingSheetUrl;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          final enteredCash = double.tryParse(cashCtrl.text.trim()) ?? 0.0;
          final enteredStc = double.tryParse(digitalCtrl.text.trim()) ?? 0.0;
          final enteredTotal = enteredCash + enteredStc;

          final cashDiff = enteredCash - expectedCash;
          final stcDiff = enteredStc - expectedStc;
          final totalDiff = enteredTotal - expectedTotal;

          final isBalanced = totalDiff.abs() < 0.01;
          final isShortage = totalDiff < -0.01;

          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: finDialogShape,
            title: finDialogTitle('Close Daily Register', icon: Icons.lock_clock_outlined),
            content: SizedBox(
              width: 460.w,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Expected Closing Breakdown Card
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: FinDT.brand.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(color: FinDT.brand.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Expected Closing Breakdown (Live Ledger):',
                              style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w600, color: FinDT.textSecondary),
                            ),
                            SizedBox(height: 4.h),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Cash: ${formatter.format(expectedCash)} SAR',
                                  style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: FinDT.textPrimary),
                                ),
                                Text(
                                  'STC Pay: ${formatter.format(expectedStc)} SAR',
                                  style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: const Color(0xFF6D28D9)),
                                ),
                              ],
                            ),
                            Divider(height: 12.h, color: FinDT.border),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total Expected:',
                                  style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: FinDT.textPrimary),
                                ),
                                Text(
                                  '${formatter.format(expectedTotal)} SAR',
                                  style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: FinDT.brand),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // Count Input Fields
                      TextFormField(
                        controller: cashCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        onChanged: (_) => setStateDialog(() {}),
                        decoration: finDialogInputDecoration(
                          label: 'Physical Cash in Hand *',
                          hint: '0.00',
                          prefixIcon: Icons.payments_outlined,
                          suffixText: 'SAR',
                        ),
                        style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      SizedBox(height: 12.h),
                      TextFormField(
                        controller: digitalCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        onChanged: (_) => setStateDialog(() {}),
                        decoration: finDialogInputDecoration(
                          label: 'STC Pay Balance *',
                          hint: '0.00',
                          prefixIcon: Icons.phone_android_outlined,
                          suffixText: 'SAR',
                        ),
                        style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      SizedBox(height: 14.h),

                      // LIVE RECONCILIATION & DISCREPANCY STATUS CARD
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: isBalanced
                              ? const Color(0xFF10B981).withValues(alpha: 0.08)
                              : (isShortage
                                  ? const Color(0xFFEF4444).withValues(alpha: 0.08)
                                  : const Color(0xFF3B82F6).withValues(alpha: 0.08)),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                            color: isBalanced
                                ? const Color(0xFF10B981).withValues(alpha: 0.35)
                                : (isShortage
                                    ? const Color(0xFFEF4444).withValues(alpha: 0.35)
                                    : const Color(0xFF3B82F6).withValues(alpha: 0.35)),
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(6.w),
                                  decoration: BoxDecoration(
                                    color: isBalanced
                                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                        : (isShortage
                                            ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                                            : const Color(0xFF3B82F6).withValues(alpha: 0.15)),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isBalanced
                                        ? Icons.check_circle_rounded
                                        : (isShortage
                                            ? Icons.warning_amber_rounded
                                            : Icons.info_outline_rounded),
                                    size: 18.sp,
                                    color: isBalanced
                                        ? const Color(0xFF059669)
                                        : (isShortage ? const Color(0xFFDC2626) : const Color(0xFF2563EB)),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isBalanced
                                            ? 'Balanced (0.00 SAR Discrepancy)'
                                            : (isShortage
                                                ? 'Shortage Detected: -${formatter.format(totalDiff.abs())} SAR'
                                                : 'Overage Detected: +${formatter.format(totalDiff)} SAR'),
                                        style: GoogleFonts.inter(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w700,
                                          color: isBalanced
                                              ? const Color(0xFF065F46)
                                              : (isShortage
                                                  ? const Color(0xFF991B1B)
                                                  : const Color(0xFF1E40AF)),
                                        ),
                                      ),
                                      SizedBox(height: 2.h),
                                      Text(
                                        isBalanced
                                            ? 'Declared counts match expected balances exactly.'
                                            : (isShortage
                                                ? 'Count is LESS than expected. Recount drawer. Note: Admin will review this to either issue a salary deduction advance or write it off.'
                                                : 'Count exceeds expected drawer balance. Please verify counts.'),
                                        style: GoogleFonts.inter(
                                          fontSize: 10.sp,
                                          color: isBalanced
                                              ? const Color(0xFF047857)
                                              : (isShortage
                                                  ? const Color(0xFFB91C1C)
                                                  : const Color(0xFF1D4ED8)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10.h),
                            Divider(height: 1, color: FinDT.border.withValues(alpha: 0.5)),
                            SizedBox(height: 8.h),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _miniDiffChip(label: 'Cash Diff', diff: cashDiff, formatter: formatter),
                                _miniDiffChip(label: 'STC Pay Diff', diff: stcDiff, formatter: formatter),
                                _miniTotalChip(label: 'Declared Total', amount: enteredTotal, formatter: formatter),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 14.h),

                      // Notes / Reason Field
                      TextFormField(
                        controller: notesCtrl,
                        maxLines: 2,
                        decoration: finDialogInputDecoration(
                          label: isBalanced ? 'Closing Remarks (Optional)' : 'Discrepancy Explanation / Reason *',
                          hint: isBalanced
                              ? 'Any closing remarks'
                              : 'Explain reason for variance (e.g. coin rounding, damaged note, unrecorded voucher)',
                          prefixIcon: Icons.notes_rounded,
                        ),
                        style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
                        validator: (v) {
                          if (!isBalanced && (v == null || v.trim().isEmpty)) {
                            return 'Please explain the cause of the discrepancy';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 14.h),

                      // Closing Sheet Upload
                      if (closingSheetUrl != null)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                          decoration: BoxDecoration(
                            color: FinDT.bgPage,
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(color: FinDT.border),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.insert_drive_file_outlined, color: FinDT.brand, size: 16.sp),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Text(
                                  'Closing Sheet Attached',
                                  style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: FinDT.textPrimary),
                                ),
                              ),
                              IconButton(
                                onPressed: () => setStateDialog(() => closingSheetUrl = null),
                                icon: Icon(Icons.close, color: FinDT.danger, size: 16.sp),
                              ),
                            ],
                          ),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picker = ImagePicker();
                            final file = await picker.pickImage(source: ImageSource.gallery);
                            if (file != null) {
                              final url = await provider.uploadClosingSheet(file, session.id);
                              setStateDialog(() => closingSheetUrl = url);
                            }
                          },
                          icon: Icon(Icons.upload_file_rounded, size: 16.sp),
                          label: Text(
                            'Upload Daily Sheet',
                            style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: FinDT.brand,
                            side: BorderSide(color: FinDT.brand.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            minimumSize: Size(double.infinity, 44.h),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              finDialogCancelButton(
                ctx,
                onPressed: isSubmitting ? () {} : null,
              ),
              finDialogActionButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;

                  final cash = double.parse(cashCtrl.text);
                  final digital = double.parse(digitalCtrl.text);
                  final closing = cash + digital;

                  final user = context.read<AuthProvider>().user;

                  // Submitter safeguard: confirm when discrepancy exists
                  if (!isBalanced) {
                    final proceed = await showDialog<bool>(
                      context: ctx,
                      builder: (alertCtx) => AlertDialog(
                        backgroundColor: Colors.white,
                        shape: finDialogShape,
                        title: finDialogTitle(
                          'Confirm Discrepancy Closing',
                          icon: Icons.warning_amber_rounded,
                          iconColor: isShortage ? FinDT.danger : const Color(0xFF2563EB),
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'A discrepancy of ${totalDiff > 0 ? "+" : ""}${formatter.format(totalDiff)} SAR will be recorded for this session.',
                              style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w600, color: FinDT.textPrimary),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              isShortage
                                  ? 'The Admin will review this session upon verification to decide whether to create a salary-deductible advance against the coordinator or approve a write-off as loss.\n\nPlease ensure you have counted your physical cash accurately before proceeding.'
                                  : 'An overage will be audited by the Admin upon verification. Please confirm counts.',
                              style: GoogleFonts.inter(fontSize: 11.sp, color: FinDT.textSecondary, height: 1.4),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(alertCtx, false),
                            child: Text(
                              'Recount & Correct',
                              style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: FinDT.brand),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(alertCtx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isShortage ? FinDT.danger : FinDT.brand,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                            ),
                            child: Text(
                              'Proceed & Submit',
                              style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (proceed != true) return;
                  }

                  if (!context.mounted) return;
                  final submittedNotes = notesCtrl.text.trim();
                  final closed = session.copyWith(
                    closingBalance: closing,
                    cashInHand: cash,
                    stcPayBalance: digital,
                    closingSheetUrl: closingSheetUrl,
                    closedBy: user?.actorLabel ?? 'Unknown',
                    notes: submittedNotes.isNotEmpty ? submittedNotes : null,
                  );

                  setStateDialog(() => isSubmitting = true);
                  try {
                    await provider.closeSession(
                      session: closed,
                      closedBy: user?.actorLabel ?? 'Unknown',
                      closedByUserId: user?.id,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isBalanced
                                ? 'Session closed successfully (Balanced)'
                                : 'Session closed with discrepancy (${formatter.format(totalDiff)} SAR). Awaiting Admin verification.',
                          ),
                          backgroundColor: isBalanced ? FinDT.success : const Color(0xFFD97706),
                        ),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      setStateDialog(() => isSubmitting = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$e'), backgroundColor: FinDT.danger),
                      );
                    }
                  }
                },
                label: 'Close Session',
                backgroundColor: isBalanced ? FinDT.brand : (isShortage ? const Color(0xFFDC2626) : FinDT.brand),
                isLoading: isSubmitting,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _miniDiffChip({
    required String label,
    required double diff,
    required NumberFormat formatter,
  }) {
    final isZero = diff.abs() < 0.01;
    final isNeg = diff < -0.01;
    final color = isZero
        ? const Color(0xFF16A34A)
        : (isNeg ? const Color(0xFFDC2626) : const Color(0xFF2563EB));
    final sign = diff > 0 ? '+' : '';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 9.sp, color: FinDT.textSecondary)),
          SizedBox(height: 1.h),
          Text(
            isZero ? '0.00' : '$sign${formatter.format(diff)}',
            style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  Widget _miniTotalChip({
    required String label,
    required double amount,
    required NumberFormat formatter,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: FinDT.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 9.sp, color: FinDT.textSecondary)),
          SizedBox(height: 1.h),
          Text(
            '${formatter.format(amount)} SAR',
            style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w700, color: FinDT.textPrimary),
          ),
        ],
      ),
    );
  }

  /// Interactive resolution dialog for Admin to decide discrepancy outcome:
  /// Option 1: Create an advance against coordinator and settle it in salary.
  /// Option 2: Write off as loss with Admin justification.
  Future<void> _showDiscrepancyResolutionDialog(
    BuildContext context,
    PettyCashProvider provider,
    PettyCashSessionEntity session,
  ) async {
    final user = context.read<AuthProvider>().user;
    final empProv = context.read<EmployeeProvider>();
    final advProv = context.read<CashAdvanceProvider>();
    final fundAccProv = context.read<FundAccountProvider>();
    final employees = empProv.employees;
    final fundAccount = fundAccProv.getAccountById(session.fundAccountId);
    final formatter = NumberFormat('#,##0.00', 'en_US');

    final discrepancy = session.discrepancy ?? 0.0;
    final isShortage = discrepancy < -0.01;
    final absDiscrepancy = discrepancy.abs();

    // Match coordinator to employee record if possible
    final coordinatorName = (session.closedBy ?? session.openedBy ?? '').trim().toLowerCase();
    EmployeeEntity? selectedEmployee;
    if (employees.isNotEmpty) {
      selectedEmployee = employees.firstWhere(
        (e) =>
            coordinatorName.isNotEmpty &&
            (e.fullName.toLowerCase().contains(coordinatorName) ||
                coordinatorName.contains(e.fullName.toLowerCase())),
        orElse: () => employees.first,
      );
    }

    // 0 = Settle in Salary (Advance), 1 = Write Off as Loss
    int resolutionOption = isShortage ? 0 : 1;
    final amountCtrl = TextEditingController(text: absDiscrepancy.toStringAsFixed(2));
    final writeOffReasonCtrl = TextEditingController();
    final advancePurposeCtrl = TextEditingController(
      text: 'Petty cash shortage deduction - Settle in salary (${DateFormat('yyyy-MM-dd').format(session.date)})',
    );
    final formKey = GlobalKey<FormState>();
    bool isProcessing = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInnerState) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: finDialogShape,
          title: finDialogTitle('Resolve Discrepancy & Lock Day', icon: Icons.gavel_rounded, iconColor: const Color(0xFFD97706)),
          content: SizedBox(
            width: 480.w,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Session Details Summary Box
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: FinDT.bgPage,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(color: FinDT.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Session: ${DateFormat('EEE, MMM d, yyyy').format(session.date)}',
                                style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: FinDT.textPrimary),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                decoration: BoxDecoration(
                                  color: isShortage
                                      ? const Color(0xFFDC2626).withValues(alpha: 0.1)
                                      : const Color(0xFF16A34A).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Text(
                                  isShortage
                                      ? '-${formatter.format(absDiscrepancy)} SAR Shortage'
                                      : '+${formatter.format(discrepancy)} SAR Overage',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w700,
                                    color: isShortage ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Expected: ${formatter.format(session.expectedClosingBalance)} SAR',
                                  style: GoogleFonts.inter(fontSize: 11.sp, color: FinDT.textSecondary)),
                              Text('Declared: ${formatter.format(session.closingBalance)} SAR',
                                  style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w600, color: FinDT.textPrimary)),
                            ],
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Coordinator: ${session.closedBy ?? session.openedBy ?? 'Unknown'}',
                            style: GoogleFonts.inter(fontSize: 11.sp, color: FinDT.textMuted),
                          ),
                          if (session.notes != null && session.notes!.trim().isNotEmpty) ...[
                            SizedBox(height: 6.h),
                            Container(
                              padding: EdgeInsets.all(8.w),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6.r),
                                border: Border.all(color: FinDT.border),
                              ),
                              child: Text(
                                'Coordinator remarks: ${session.notes!.trim()}',
                                style: GoogleFonts.inter(fontSize: 11.sp, fontStyle: FontStyle.italic, color: FinDT.textPrimary),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Admin Resolution Decision Toggle
                    Text(
                      'Admin Resolution Decision *',
                      style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: FinDT.textPrimary),
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: isProcessing ? null : () => setInnerState(() => resolutionOption = 0),
                            borderRadius: BorderRadius.circular(10.r),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
                              decoration: BoxDecoration(
                                color: resolutionOption == 0 ? FinDT.brand.withValues(alpha: 0.1) : FinDT.bgPage,
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(
                                  color: resolutionOption == 0 ? FinDT.brand : FinDT.border,
                                  width: resolutionOption == 0 ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        resolutionOption == 0 ? Icons.radio_button_checked : Icons.radio_button_off,
                                        size: 16.sp,
                                        color: resolutionOption == 0 ? FinDT.brand : FinDT.textMuted,
                                      ),
                                      SizedBox(width: 6.w),
                                      Expanded(
                                        child: Text(
                                          'Settle in Salary',
                                          style: GoogleFonts.inter(
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w700,
                                            color: resolutionOption == 0 ? FinDT.brand : FinDT.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    'Create advance against coordinator',
                                    style: GoogleFonts.inter(fontSize: 10.sp, color: FinDT.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: InkWell(
                            onTap: isProcessing ? null : () => setInnerState(() => resolutionOption = 1),
                            borderRadius: BorderRadius.circular(10.r),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
                              decoration: BoxDecoration(
                                color: resolutionOption == 1 ? const Color(0xFFDC2626).withValues(alpha: 0.08) : FinDT.bgPage,
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(
                                  color: resolutionOption == 1 ? const Color(0xFFDC2626) : FinDT.border,
                                  width: resolutionOption == 1 ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        resolutionOption == 1 ? Icons.radio_button_checked : Icons.radio_button_off,
                                        size: 16.sp,
                                        color: resolutionOption == 1 ? const Color(0xFFDC2626) : FinDT.textMuted,
                                      ),
                                      SizedBox(width: 6.w),
                                      Expanded(
                                        child: Text(
                                          'Write Off as Loss',
                                          style: GoogleFonts.inter(
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w700,
                                            color: resolutionOption == 1 ? const Color(0xFFDC2626) : FinDT.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    'Absorb shortage as company loss',
                                    style: GoogleFonts.inter(fontSize: 10.sp, color: FinDT.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),

                    // Option Form Fields
                    if (resolutionOption == 0) ...[
                      // Salary Advance Option
                      if (employees.isEmpty)
                        Text(
                          'No employee records found. Please add the coordinator in Employees module or select Write Off.',
                          style: GoogleFonts.inter(fontSize: 11.sp, color: FinDT.danger),
                        )
                      else ...[
                        DropdownButtonFormField<EmployeeEntity>(
                          initialValue: selectedEmployee,
                          decoration: finDialogInputDecoration(
                            label: 'Coordinator Employee Recipient *',
                            hint: 'Select staff member',
                            prefixIcon: Icons.person_outline,
                          ),
                          style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
                          items: employees
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e.fullName),
                                ),
                              )
                              .toList(),
                          onChanged: isProcessing ? null : (v) => setInnerState(() => selectedEmployee = v),
                          validator: (v) => v == null ? 'Employee is required' : null,
                        ),
                        SizedBox(height: 12.h),
                        TextFormField(
                          controller: amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                          ],
                          decoration: finDialogInputDecoration(
                            label: 'Advance Amount *',
                            hint: '0.00',
                            prefixIcon: Icons.payments_outlined,
                            suffixText: fundAccount?.currency ?? 'SAR',
                          ),
                          style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
                          validator: (v) {
                            final n = double.tryParse(v ?? '');
                            if (n == null || n <= 0) return 'Enter a valid positive amount';
                            return null;
                          },
                        ),
                        SizedBox(height: 12.h),
                        TextFormField(
                          controller: advancePurposeCtrl,
                          decoration: finDialogInputDecoration(
                            label: 'Purpose / Note *',
                            hint: 'Reason for advance deduction',
                            prefixIcon: Icons.description_outlined,
                          ),
                          style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Purpose required' : null,
                        ),
                      ],
                    ] else ...[
                      // Write Off Option
                      TextFormField(
                        controller: writeOffReasonCtrl,
                        maxLines: 2,
                        decoration: finDialogInputDecoration(
                          label: 'Write Off Justification *',
                          hint: 'e.g. Counter drawer rounding tolerance, unrecoverable operational loss approved by Admin',
                          prefixIcon: Icons.rate_review_outlined,
                        ),
                        style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Reason is required to write off a discrepancy'
                            : null,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            finDialogCancelButton(ctx, onPressed: isProcessing ? () {} : null),
            finDialogActionButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                setInnerState(() => isProcessing = true);
                try {
                  if (resolutionOption == 0) {
                    if (selectedEmployee == null) {
                      throw StateError('Please select an employee recipient');
                    }
                    final advAmount = double.parse(amountCtrl.text.trim());
                    final adv = CashAdvanceEntity(
                      id: const Uuid().v4(),
                      fundAccountId: session.fundAccountId,
                      fundAccountName: fundAccount?.name ?? 'Petty Cash Fund',
                      employeeId: selectedEmployee!.id,
                      employeeName: selectedEmployee!.fullName,
                      amount: advAmount,
                      amountMinor: (advAmount * 100).round(),
                      currency: fundAccount?.currency ?? 'SAR',
                      purpose: advancePurposeCtrl.text.trim(),
                      notes: 'Petty cash session ${session.id} discrepancy settlement. Deduct from salary.',
                      issuedBy: user?.actorLabel ?? 'Admin',
                      issuedByUserId: user?.id,
                      issuedAt: DateTime.now(),
                      createdAt: DateTime.now(),
                    );
                    await advProv.issue(adv);
                    await fundAccProv.fetchAllAccounts();
                    await provider.verifySession(
                      sessionId: session.id,
                      verifiedBy: user?.actorLabel ?? 'Admin',
                      verifiedByUserId: user?.id,
                      resolutionNotes: 'Discrepancy of ${formatter.format(advAmount)} SAR settled via Cash Advance to ${selectedEmployee!.fullName} (to be deducted from salary)',
                    );
                    if (ctx.mounted) finSafePop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Salary advance issued to ${selectedEmployee!.fullName} & day locked',
                          ),
                          backgroundColor: FinDT.success,
                        ),
                      );
                    }
                  } else {
                    final reason = writeOffReasonCtrl.text.trim();
                    await provider.verifySession(
                      sessionId: session.id,
                      verifiedBy: user?.actorLabel ?? 'Admin',
                      verifiedByUserId: user?.id,
                      resolutionNotes: 'Discrepancy of ${formatter.format(absDiscrepancy)} SAR written off as loss by Admin: $reason',
                    );
                    if (ctx.mounted) finSafePop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Discrepancy written off as loss & day locked'),
                          backgroundColor: FinDT.success,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    setInnerState(() => isProcessing = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$e'), backgroundColor: FinDT.danger),
                    );
                  }
                }
              },
              label: resolutionOption == 0 ? 'Issue Advance & Lock Day' : 'Write Off as Loss & Lock',
              backgroundColor: resolutionOption == 0 ? FinDT.brand : const Color(0xFFDC2626),
              isLoading: isProcessing,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmVerifySession(
    BuildContext context,
    PettyCashProvider provider,
    PettyCashSessionEntity session,
  ) async {
    final user = context.read<AuthProvider>().user;
    await showFinConfirmationDialog(
      context: context,
      title: 'Verify & Lock Day?',
      message: 'Confirm closing ${session.closingBalance.toStringAsFixed(2)} SAR (discrepancy: ${session.discrepancy?.toStringAsFixed(2) ?? "0.00"}).',
      highlightNote: 'This LOCKS the day — no further deposits, withdrawals, or expense payments can be posted to this fund for this calendar day.',
      confirmLabel: 'Verify & Lock',
      confirmColor: FinDT.success,
      icon: Icons.verified_user_outlined,
      onConfirm: () async {
        await provider.verifySession(
          sessionId: session.id,
          verifiedBy: user?.actorLabel ?? 'Unknown',
          verifiedByUserId: user?.id,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Day verified and locked'),
              backgroundColor: FinDT.success,
            ),
          );
        }
      },
    );
  }

  void _showSessionExpensesDialog(
    BuildContext context,
    PettyCashProvider provider,
    PettyCashSessionEntity session,
  ) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    final accProv = context.read<FundAccountProvider>();
    final account = accProv.getAccountById(session.fundAccountId);
    final accountName = account?.name ?? 'Petty Cash Drawer';

    showDialog(
      context: context,
      builder: (ctx) {
        String filterBucket = 'ALL';
        String searchQuery = '';
        final future = provider.getSessionExpenses(session);

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final size = MediaQuery.of(dialogCtx).size;
            final dialogWidth = (size.width * 0.78).clamp(440.0, 920.0);
            final dialogHeight = (size.height * 0.85).clamp(480.0, 780.0);

            return Dialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: finDialogShape,
              insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
              child: SizedBox(
                width: dialogWidth,
                height: dialogHeight,
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: FinDT.borderLight)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(10.w),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Icon(
                              Icons.receipt_long_rounded,
                              color: const Color(0xFFDC2626),
                              size: 22.sp,
                            ),
                          ),
                          SizedBox(width: 14.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Session Expenses & Outflows',
                                      style: GoogleFonts.inter(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w700,
                                        color: FinDT.textPrimary,
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                      decoration: BoxDecoration(
                                        color: session.status == PettyCashSessionStatus.verified
                                            ? const Color(0xFF16A34A).withValues(alpha: 0.1)
                                            : (session.status == PettyCashSessionStatus.closed
                                                ? const Color(0xFFD97706).withValues(alpha: 0.1)
                                                : FinDT.brand.withValues(alpha: 0.1)),
                                        borderRadius: BorderRadius.circular(6.r),
                                      ),
                                      child: Text(
                                        session.status.displayName.toUpperCase(),
                                        style: GoogleFonts.inter(
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.w700,
                                          color: session.status == PettyCashSessionStatus.verified
                                              ? const Color(0xFF16A34A)
                                              : (session.status == PettyCashSessionStatus.closed
                                                  ? const Color(0xFFD97706)
                                                  : FinDT.brand),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  '${DateFormat('EEEE, dd MMMM yyyy').format(session.date)} • $accountName',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.sp,
                                    color: FinDT.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            icon: Icon(Icons.close_rounded, size: 20.sp, color: FinDT.textSecondary),
                            splashRadius: 18.r,
                          ),
                        ],
                      ),
                    ),

                    // Body
                    Expanded(
                      child: FutureBuilder<List<SessionExpenseItem>>(
                        future: future,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return Center(
                              child: Padding(
                                padding: EdgeInsets.all(24.w),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.error_outline_rounded, size: 40.sp, color: Colors.red),
                                    SizedBox(height: 12.h),
                                    Text(
                                      'Failed to load expenses',
                                      style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w700),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      '${snapshot.error}',
                                      style: GoogleFonts.inter(fontSize: 11.sp, color: FinDT.textSecondary),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          final allItems = snapshot.data ?? [];

                          // Calculate totals
                          double cashSpent = 0;
                          double stcSpent = 0;
                          for (final it in allItems) {
                            if (it.bucket == FundBucket.cash) {
                              cashSpent += it.amount;
                            } else if (it.bucket == FundBucket.stcPay) {
                              stcSpent += it.amount;
                            } else {
                              cashSpent += it.amount;
                            }
                          }
                          final totalSpent = cashSpent + stcSpent;

                          // Apply search & bucket filter
                          final filtered = allItems.where((it) {
                            if (filterBucket == 'CASH' && it.bucket != FundBucket.cash) return false;
                            if (filterBucket == 'STC_PAY' && it.bucket != FundBucket.stcPay) return false;
                            if (searchQuery.isNotEmpty) {
                              final q = searchQuery.toLowerCase();
                              final matchesRef = it.referenceNumber.toLowerCase().contains(q);
                              final matchesTitle = it.title.toLowerCase().contains(q);
                              final matchesCat = it.category.toLowerCase().contains(q);
                              final matchesType = it.expenseType.toLowerCase().contains(q);
                              final matchesUser = it.performedBy.toLowerCase().contains(q);
                              final matchesVehicle = (it.vehicleName ?? '').toLowerCase().contains(q);
                              if (!matchesRef && !matchesTitle && !matchesCat && !matchesType && !matchesUser && !matchesVehicle) {
                                return false;
                              }
                            }
                            return true;
                          }).toList();

                          return Column(
                            children: [
                              // KPI Summary strip
                              Container(
                                padding: EdgeInsets.all(14.w),
                                color: FinDT.bgPage,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildExpenseSummaryCard(
                                        title: 'TOTAL EXPENSES',
                                        amount: '${formatter.format(totalSpent)} SAR',
                                        icon: Icons.arrow_upward_rounded,
                                        color: const Color(0xFFDC2626),
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: _buildExpenseSummaryCard(
                                        title: 'CASH PAID',
                                        amount: '${formatter.format(cashSpent)} SAR',
                                        icon: Icons.payments_outlined,
                                        color: const Color(0xFFD97706),
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: _buildExpenseSummaryCard(
                                        title: 'STC PAY PAID',
                                        amount: '${formatter.format(stcSpent)} SAR',
                                        icon: Icons.account_balance_wallet_outlined,
                                        color: FinDT.brand,
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: _buildExpenseSummaryCard(
                                        title: 'TRANSACTIONS',
                                        amount: '${allItems.length}',
                                        icon: Icons.receipt_outlined,
                                        color: FinDT.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Divider(height: 1, color: FinDT.borderLight),

                              // Filter & Search bar
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                                child: Row(
                                  children: [
                                    // Search field
                                    Expanded(
                                      child: SizedBox(
                                        height: 36.h,
                                        child: TextField(
                                          onChanged: (val) => setDialogState(() => searchQuery = val.trim()),
                                          decoration: InputDecoration(
                                            hintText: 'Search by reference, category, driver, or notes...',
                                            hintStyle: GoogleFonts.inter(fontSize: 11.sp, color: FinDT.textMuted),
                                            prefixIcon: Icon(Icons.search, size: 16.sp, color: FinDT.textMuted),
                                            filled: true,
                                            fillColor: FinDT.bgPage,
                                            contentPadding: EdgeInsets.symmetric(vertical: 6.h),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8.r),
                                              borderSide: BorderSide(color: FinDT.borderLight),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8.r),
                                              borderSide: BorderSide(color: FinDT.borderLight),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12.w),

                                    // Filter pills
                                    _buildFilterTab(
                                      label: 'All (${allItems.length})',
                                      isSelected: filterBucket == 'ALL',
                                      onTap: () => setDialogState(() => filterBucket = 'ALL'),
                                    ),
                                    SizedBox(width: 6.w),
                                    _buildFilterTab(
                                      label: 'Cash (${allItems.where((i) => i.bucket == FundBucket.cash).length})',
                                      isSelected: filterBucket == 'CASH',
                                      onTap: () => setDialogState(() => filterBucket = 'CASH'),
                                    ),
                                    SizedBox(width: 6.w),
                                    _buildFilterTab(
                                      label: 'STC Pay (${allItems.where((i) => i.bucket == FundBucket.stcPay).length})',
                                      isSelected: filterBucket == 'STC_PAY',
                                      onTap: () => setDialogState(() => filterBucket = 'STC_PAY'),
                                    ),
                                  ],
                                ),
                              ),
                              Divider(height: 1, color: FinDT.borderLight),

                              // Items List
                              Expanded(
                                child: filtered.isEmpty
                                    ? Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(24.w),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.receipt_long_outlined,
                                                size: 44.sp,
                                                color: FinDT.textMuted,
                                              ),
                                              SizedBox(height: 10.h),
                                              Text(
                                                allItems.isEmpty
                                                    ? 'No expenses recorded for this session'
                                                    : 'No expenses match the current filter',
                                                style: GoogleFonts.inter(
                                                  fontSize: 13.sp,
                                                  fontWeight: FontWeight.w600,
                                                  color: FinDT.textSecondary,
                                                ),
                                              ),
                                              SizedBox(height: 4.h),
                                              Text(
                                                allItems.isEmpty
                                                    ? 'Opening balance remained unspent or only received deposits.'
                                                    : 'Try clearing the search query or switching filter tabs.',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11.sp,
                                                  color: FinDT.textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    : ListView.separated(
                                        padding: EdgeInsets.all(14.w),
                                        itemCount: filtered.length,
                                        separatorBuilder: (_, __) => SizedBox(height: 8.h),
                                        itemBuilder: (ctx, i) {
                                          final item = filtered[i];
                                          final isCash = item.bucket == FundBucket.cash;

                                          return Container(
                                            padding: EdgeInsets.all(12.w),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(10.r),
                                              border: Border.all(color: FinDT.borderLight),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: FinDT.shadow.withValues(alpha: 0.04),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              children: [
                                                // Icon
                                                Container(
                                                  padding: EdgeInsets.all(8.w),
                                                  decoration: BoxDecoration(
                                                    color: isCash
                                                        ? const Color(0xFFD97706).withValues(alpha: 0.1)
                                                        : FinDT.brand.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(8.r),
                                                  ),
                                                  child: Icon(
                                                    isCash
                                                        ? Icons.payments_outlined
                                                        : Icons.account_balance_wallet_outlined,
                                                    color: isCash ? const Color(0xFFD97706) : FinDT.brand,
                                                    size: 18.sp,
                                                  ),
                                                ),
                                                SizedBox(width: 12.w),

                                                // Details
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          // Ref chip
                                                          Container(
                                                            padding: EdgeInsets.symmetric(
                                                              horizontal: 6.w,
                                                              vertical: 2.h,
                                                            ),
                                                            decoration: BoxDecoration(
                                                              color: FinDT.bgPage,
                                                              borderRadius: BorderRadius.circular(4.r),
                                                              border: Border.all(color: FinDT.border),
                                                            ),
                                                            child: Text(
                                                              item.referenceNumber,
                                                              style: GoogleFonts.inter(
                                                                fontSize: 10.sp,
                                                                fontWeight: FontWeight.w700,
                                                                color: FinDT.textPrimary,
                                                              ),
                                                            ),
                                                          ),
                                                          SizedBox(width: 6.w),

                                                          // Bucket badge
                                                          Container(
                                                            padding: EdgeInsets.symmetric(
                                                              horizontal: 6.w,
                                                              vertical: 2.h,
                                                            ),
                                                            decoration: BoxDecoration(
                                                              color: isCash
                                                                  ? const Color(0xFFD97706).withValues(alpha: 0.1)
                                                                  : FinDT.brand.withValues(alpha: 0.1),
                                                              borderRadius: BorderRadius.circular(4.r),
                                                            ),
                                                            child: Text(
                                                              isCash ? 'CASH' : 'STC PAY',
                                                              style: GoogleFonts.inter(
                                                                fontSize: 9.sp,
                                                                fontWeight: FontWeight.w700,
                                                                color: isCash ? const Color(0xFFD97706) : FinDT.brand,
                                                              ),
                                                            ),
                                                          ),
                                                          SizedBox(width: 8.w),

                                                          // Title
                                                          Expanded(
                                                            child: Text(
                                                              item.title,
                                                              style: GoogleFonts.inter(
                                                                fontSize: 12.sp,
                                                                fontWeight: FontWeight.w700,
                                                                color: FinDT.textPrimary,
                                                              ),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                          SizedBox(width: 6.w),

                                                          // Time
                                                          Text(
                                                            DateFormat('hh:mm a').format(item.date),
                                                            style: GoogleFonts.inter(
                                                              fontSize: 10.sp,
                                                              color: FinDT.textMuted,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      SizedBox(height: 4.h),
                                                      Wrap(
                                                        crossAxisAlignment: WrapCrossAlignment.center,
                                                        spacing: 4.w,
                                                        children: [
                                                          Text(
                                                            '${item.category} • ${item.expenseType}',
                                                            style: GoogleFonts.inter(
                                                              fontSize: 11.sp,
                                                              color: FinDT.textSecondary,
                                                            ),
                                                          ),
                                                          if (item.vehicleName != null && item.vehicleName!.isNotEmpty) ...[
                                                            Text('•', style: TextStyle(color: FinDT.border, fontSize: 10.sp)),
                                                            Icon(Icons.directions_car_outlined, size: 11.sp, color: FinDT.textMuted),
                                                            Text(
                                                              item.vehicleName!,
                                                              style: GoogleFonts.inter(fontSize: 10.sp, color: FinDT.textSecondary),
                                                            ),
                                                          ],
                                                          if (item.employeeName != null && item.employeeName!.isNotEmpty) ...[
                                                            Text('•', style: TextStyle(color: FinDT.border, fontSize: 10.sp)),
                                                            Icon(Icons.person_outline, size: 11.sp, color: FinDT.textMuted),
                                                            Text(
                                                              item.employeeName!,
                                                              style: GoogleFonts.inter(fontSize: 10.sp, color: FinDT.textSecondary),
                                                            ),
                                                          ],
                                                          Text('•', style: TextStyle(color: FinDT.border, fontSize: 10.sp)),
                                                          Text(
                                                            'By ${item.performedBy}',
                                                            style: GoogleFonts.inter(fontSize: 10.sp, color: FinDT.textMuted),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                SizedBox(width: 14.w),

                                                // Amount
                                                Text(
                                                  '-${formatter.format(item.amount)} SAR',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13.sp,
                                                    fontWeight: FontWeight.w700,
                                                    color: const Color(0xFFDC2626),
                                                  ),
                                                ),
                                                SizedBox(width: 10.w),

                                                // Actions
                                                if (item.receiptUrls.isNotEmpty) ...[
                                                  IconButton(
                                                    tooltip: 'View Receipt',
                                                    onPressed: () => _previewReceipt(dialogCtx, item.receiptUrls.first),
                                                    icon: Icon(Icons.receipt_outlined, size: 18.sp, color: FinDT.brand),
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                  ),
                                                  SizedBox(width: 8.w),
                                                ],
                                                if (item.originalExpense != null) ...[
                                                  OutlinedButton(
                                                    onPressed: () {
                                                      showExpenseReviewDialog(
                                                        context: dialogCtx,
                                                        expense: item.originalExpense!,
                                                        accountName: accountName,
                                                        readOnly: true,
                                                      );
                                                    },
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor: FinDT.brand,
                                                      side: BorderSide(color: FinDT.brand.withValues(alpha: 0.3)),
                                                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(6.r),
                                                      ),
                                                      minimumSize: Size.zero,
                                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                    ),
                                                    child: Text(
                                                      'Details',
                                                      style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w600),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    // Footer
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: FinDT.borderLight)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'All figures in Saudi Riyal (SAR)',
                            style: GoogleFonts.inter(fontSize: 11.sp, color: FinDT.textMuted),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: FinDT.brand,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                            ),
                            child: Text(
                              'Close',
                              style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildExpenseSummaryCard({
    required String title,
    required String amount,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: FinDT.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12.sp, color: color),
              SizedBox(width: 4.w),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: FinDT.textMuted,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            amount,
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isSelected ? FinDT.brand : FinDT.bgPage,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: isSelected ? FinDT.brand : FinDT.borderLight,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : FinDT.textSecondary,
          ),
        ),
      ),
    );
  }

  void _previewReceipt(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black.withValues(alpha: 0.85),
        insetPadding: EdgeInsets.all(20.w),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.r),
                child: InteractiveViewer(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.white,
                      padding: EdgeInsets.all(24.w),
                      child: Text(
                        'Failed to load receipt image',
                        style: GoogleFonts.inter(color: Colors.red),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10.h,
              right: 10.w,
              child: IconButton(
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
