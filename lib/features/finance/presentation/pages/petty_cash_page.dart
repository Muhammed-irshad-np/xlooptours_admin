import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/petty_cash_provider.dart';
import '../providers/fund_account_provider.dart';
import '../../domain/entities/petty_cash_session_entity.dart';
import '../../domain/entities/fund_account_entity.dart';
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
          .where((a) => a.type == FundAccountType.pettyCash)
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
        .where((a) => a.type == FundAccountType.pettyCash)
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
                        child: _buildSessionKpiCard(
                          title: "TODAY'S EXPENSES",
                          value: '${formatter.format(expTotal)} SAR',
                          icon: Icons.arrow_upward_rounded,
                          accentColor: const Color(0xFFDC2626),
                          cashValue: '${formatter.format(cashExp)} SAR',
                          stcValue: '${formatter.format(stcExp)} SAR',
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

                  // Close Session Action Bar
                  Row(
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
                  ),
                ],
              );
            }),
          ] else ...[
            Container(
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
                          'Ready to start today\'s transactions?',
                          style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: FinDT.textPrimary),
                        ),
                        SizedBox(height: 3.h),
                        Text(
                          'Open the daily session to record physical cash in drawer and digital STC balance.',
                          style: GoogleFonts.inter(fontSize: 11.sp, color: FinDT.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showOpenSessionDialog(context, provider),
                    icon: Icon(Icons.storefront_outlined, size: 16.sp),
                    label: Text(
                      'Open Daily Session',
                      style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FinDT.brand,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
                            Row(
                              children: [
                                Text(
                                  'Opening: ${formatter.format(session.openingBalance)} SAR',
                                  style: GoogleFonts.inter(fontSize: 11.sp, color: FinDT.textSecondary),
                                ),
                                Text(' • ', style: TextStyle(color: FinDT.border)),
                                Text(
                                  'Expected: ${formatter.format(session.expectedClosingBalance)} SAR',
                                  style: GoogleFonts.inter(fontSize: 11.sp, color: FinDT.textSecondary),
                                ),
                                Text(' • ', style: TextStyle(color: FinDT.border)),
                                Text(
                                  'Declared: ${formatter.format(session.closingBalance)} SAR',
                                  style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w600, color: FinDT.textPrimary),
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
                          ],
                        ),
                      ),
                      SizedBox(width: 14.w),

                      // Discrepancy & Verification Action
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
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
                          if (isClosed) ...[
                            SizedBox(height: 8.h),
                            ElevatedButton(
                              onPressed: () => _confirmVerifySession(context, provider, session),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                              ),
                              child: Text(
                                'Verify & Lock Day',
                                style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w600),
                              ),
                            ),
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

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
          finDialogCancelButton(ctx),
          finDialogActionButton(
            onPressed: () async {
              final session = PettyCashSessionEntity(
                id: const Uuid().v4(),
                fundAccountId: _selectedAccountId!,
                date: DateTime.now(),
                openedBy: context.read<AuthProvider>().user?.actorLabel ?? 'Unknown',
                // Opening balances will be overwritten server-side from live account snapshot.
                // Values here are informational only.
                openingCashBalance: currentCash,
                openingStcPayBalance: currentStc,
                createdAt: DateTime.now(),
              );

              provider.openSession(session);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            label: 'Open Session',
            backgroundColor: FinDT.brand,
          ),
        ],
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
    final cashCtrl = TextEditingController(text: session.expectedCashClosing.toStringAsFixed(2));
    final digitalCtrl = TextEditingController(text: session.expectedStcPayClosing.toStringAsFixed(2));
    String? closingSheetUrl;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: finDialogShape,
          title: finDialogTitle('Close Daily Session', icon: Icons.lock_clock_outlined),
          content: SizedBox(
            width: 440.w,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                            'Expected Closing Breakdown:',
                            style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w600, color: FinDT.textSecondary),
                          ),
                          SizedBox(height: 4.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Cash: ${session.expectedCashClosing.toStringAsFixed(2)} SAR',
                                style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: FinDT.textPrimary),
                              ),
                              Text(
                                'STC Pay: ${session.expectedStcPayClosing.toStringAsFixed(2)} SAR',
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
                                '${session.expectedClosingBalance.toStringAsFixed(2)} SAR',
                                style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: FinDT.brand),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),
                    TextFormField(
                      controller: cashCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                      decoration: finDialogInputDecoration(
                        label: 'Physical Cash in Hand *',
                        hint: '0.00',
                        prefixIcon: Icons.payments_outlined,
                        suffixText: 'SAR',
                      ),
                      style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    SizedBox(height: 12.h),
                    TextFormField(
                      controller: digitalCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                      decoration: finDialogInputDecoration(
                        label: 'STC Pay Balance *',
                        hint: '0.00',
                        prefixIcon: Icons.phone_android_outlined,
                        suffixText: 'SAR',
                      ),
                      style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    SizedBox(height: 16.h),
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
            finDialogCancelButton(ctx),
            finDialogActionButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final cash = double.parse(cashCtrl.text);
                final digital = double.parse(digitalCtrl.text);
                final closing = cash + digital;

                final user = context.read<AuthProvider>().user;
                final closed = session.copyWith(
                  closingBalance: closing,
                  cashInHand: cash,
                  stcPayBalance: digital,
                  closingSheetUrl: closingSheetUrl,
                  closedBy: user?.actorLabel ?? 'Unknown',
                );

                Navigator.pop(ctx);
                provider
                    .closeSession(
                  session: closed,
                  closedBy: user?.actorLabel ?? 'Unknown',
                  closedByUserId: user?.id,
                )
                    .then((_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Session closed using ledger totals for the day',
                        ),
                      ),
                    );
                  }
                }).catchError((e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$e'), backgroundColor: FinDT.danger),
                    );
                  }
                });
              },
              label: 'Close Session',
              backgroundColor: FinDT.brand,
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
    final ok = await showFinConfirmationDialog(
      context: context,
      title: 'Verify & Lock Day?',
      message: 'Confirm closing ${session.closingBalance.toStringAsFixed(2)} SAR (discrepancy: ${session.discrepancy?.toStringAsFixed(2) ?? "0.00"}).',
      highlightNote: 'This LOCKS the day — no further deposits, withdrawals, or expense payments can be posted to this fund for this calendar day.',
      confirmLabel: 'Verify & Lock',
      confirmColor: FinDT.success,
      icon: Icons.verified_user_outlined,
    );
    if (ok != true || !context.mounted) return;
    try {
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
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: FinDT.danger),
        );
      }
    }
  }
}
