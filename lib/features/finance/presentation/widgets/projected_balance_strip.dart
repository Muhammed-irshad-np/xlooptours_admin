import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/fund_account_entity.dart';
import '../pages/finance_dashboard_page.dart';
import '../providers/finance_provider.dart';
import '../providers/fund_account_provider.dart';

/// Shows the real ledger balance next to the projected ("estimated") balance
/// that would remain once every pending expense is approved.
///
/// The ledger figure only counts money already posted to a wallet. Pending
/// expenses are committed but unposted, so an approver looking purely at the
/// ledger can overspend a wallet. This strip makes that commitment visible.
class ProjectedBalanceStrip extends StatefulWidget {
  final FinanceProvider provider;
  final FundAccountProvider accountProvider;

  const ProjectedBalanceStrip({
    super.key,
    required this.provider,
    required this.accountProvider,
  });

  @override
  State<ProjectedBalanceStrip> createState() => _ProjectedBalanceStripState();
}

class _ProjectedBalanceStripState extends State<ProjectedBalanceStrip> {
  bool _expanded = false;

  static final _money = NumberFormat('#,##0.00', 'en_US');

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final accountProvider = widget.accountProvider;
    final filterId = provider.accountFilter;

    // Scope to the filtered wallet when the user has picked one.
    final scoped = filterId == null
        ? accountProvider.activeAccounts
        : accountProvider.accounts.where((a) => a.id == filterId).toList();

    final ledgerMinor =
        scoped.fold<int>(0, (sum, a) => sum + a.currentBalanceMinor);
    final pendingMinor = filterId == null
        ? scoped.fold<int>(
            0, (sum, a) => sum + provider.outstandingOutflowMinorFor(a.id))
        : provider.outstandingOutflowMinorFor(filterId);
    final pendingCount = filterId == null
        ? scoped.fold<int>(
            0, (sum, a) => sum + provider.outstandingCountFor(a.id))
        : provider.outstandingCountFor(filterId);
    final projectedMinor = ledgerMinor - pendingMinor;

    // Wallets carrying a commitment come first; they are the ones at risk.
    final rows = scoped
        .map((a) => _AccountProjection(
              account: a,
              pendingMinor: provider.outstandingOutflowMinorFor(a.id),
              pendingCount: provider.outstandingCountFor(a.id),
            ))
        .toList()
      ..sort((a, b) {
        if (a.pendingMinor != b.pendingMinor) {
          return b.pendingMinor.compareTo(a.pendingMinor);
        }
        return a.account.name.compareTo(b.account.name);
      });

    final atRisk = rows.where((r) => r.isOverdrawn).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: FinDT.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, scoped, filterId, pendingCount),
          Divider(height: 1, color: FinDT.borderLight),
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 16.h),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 720;
                final tiles = [
                  _MetricTile(
                    label: 'LEDGER BALANCE',
                    caption: 'Posted money — actual',
                    valueMinor: ledgerMinor,
                    icon: Icons.account_balance_wallet_outlined,
                    accent: FinDT.brand,
                    isNarrow: isNarrow,
                  ),
                  _MetricTile(
                    label: 'PENDING APPROVALS',
                    caption: pendingCount == 1
                        ? '1 expense awaiting approval'
                        : '$pendingCount expenses awaiting approval',
                    valueMinor: -pendingMinor,
                    signed: true,
                    icon: Icons.pending_actions_outlined,
                    accent: FinDT.warning,
                    isNarrow: isNarrow,
                  ),
                  _MetricTile(
                    label: 'PROJECTED BALANCE',
                    caption: 'If all pending are approved',
                    valueMinor: projectedMinor,
                    icon: Icons.trending_down_rounded,
                    accent: projectedMinor < 0 ? FinDT.danger : FinDT.success,
                    emphasize: true,
                    isNarrow: isNarrow,
                  ),
                ];

                if (isNarrow) {
                  return Column(
                    children: [
                      for (var i = 0; i < tiles.length; i++) ...[
                        if (i > 0) SizedBox(height: 10.h),
                        tiles[i],
                      ],
                    ],
                  );
                }
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: tiles[0]),
                      SizedBox(width: 12.w),
                      Expanded(child: tiles[1]),
                      SizedBox(width: 12.w),
                      Expanded(child: tiles[2]),
                    ],
                  ),
                );
              },
            ),
          ),

          if (atRisk.isNotEmpty && !_expanded)
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
              child: _OverdraftWarning(
                accounts: atRisk,
                onReview: () => setState(() => _expanded = true),
              ),
            ),

          if (_expanded) ...[
            Divider(height: 1, color: FinDT.borderLight),
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 18.h),
              child: rows.isEmpty
                  ? Text(
                      'No active wallets to project.',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: FinDT.textSecondary,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PER-WALLET PROJECTION',
                          style: GoogleFonts.inter(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: FinDT.textSecondary,
                          ),
                        ),
                        SizedBox(height: 10.h),
                        for (final row in rows) ...[
                          _AccountProjectionRow(
                            projection: row,
                            isSelected: row.account.id == filterId,
                            onTap: () => provider.setAccountFilter(
                              row.account.id == filterId ? null : row.account.id,
                            ),
                          ),
                          SizedBox(height: 8.h),
                        ],
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    List<FundAccountEntity> scoped,
    String? filterId,
    int pendingCount,
  ) {
    final scopeLabel = filterId == null
        ? '${scoped.length} active wallet${scoped.length == 1 ? '' : 's'}'
        : (scoped.isNotEmpty ? scoped.first.name : 'Selected wallet');

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 12.w, 14.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: FinDT.brandLight,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(
              Icons.insights_rounded,
              size: 18.sp,
              color: FinDT.brand,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Wallet Position',
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: FinDT.textPrimary,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Tooltip(
                      message:
                          'Ledger balance counts only money already posted.\n'
                          'Projected balance subtracts every pending / approved\n'
                          'expense that still has to be paid from the wallet.',
                      child: Icon(
                        Icons.help_outline_rounded,
                        size: 13.sp,
                        color: FinDT.textMuted,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  scopeLabel,
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    color: FinDT.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (widget.provider.isOutstandingLoading)
            Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: SizedBox(
                width: 14.w,
                height: 14.w,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: FinDT.brand,
                ),
              ),
            ),
          TextButton.icon(
            onPressed: () => setState(() => _expanded = !_expanded),
            icon: Icon(
              _expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 16.sp,
            ),
            label: Text(
              _expanded ? 'Hide wallets' : 'By wallet',
              style: GoogleFonts.inter(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(foregroundColor: FinDT.brand),
          ),
        ],
      ),
    );
  }

  static String money(int minor) => _money.format(minor / 100.0);
}

/// One wallet's ledger vs projected position.
class _AccountProjection {
  final FundAccountEntity account;
  final int pendingMinor;
  final int pendingCount;

  const _AccountProjection({
    required this.account,
    required this.pendingMinor,
    required this.pendingCount,
  });

  int get ledgerMinor => account.currentBalanceMinor;
  int get projectedMinor => ledgerMinor - pendingMinor;
  bool get isOverdrawn => projectedMinor < 0;

  /// True when approvals would leave under 20% of the wallet's ledger.
  bool get isTight =>
      !isOverdrawn && ledgerMinor > 0 && projectedMinor < ledgerMinor * 0.2;
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String caption;
  final int valueMinor;
  final IconData icon;
  final Color accent;
  final bool emphasize;
  final bool signed;
  final bool isNarrow;

  const _MetricTile({
    required this.label,
    required this.caption,
    required this.valueMinor,
    required this.icon,
    required this.accent,
    required this.isNarrow,
    this.emphasize = false,
    this.signed = false,
  });

  @override
  Widget build(BuildContext context) {
    final display = signed && valueMinor != 0
        ? '− ${_ProjectedBalanceStripState.money(valueMinor.abs())}'
        : _ProjectedBalanceStripState.money(valueMinor);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: emphasize ? accent.withValues(alpha: 0.06) : FinDT.bgPage,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: emphasize ? accent.withValues(alpha: 0.28) : FinDT.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 13.sp, color: accent),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: FinDT.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$display SAR',
              style: GoogleFonts.inter(
                fontSize: emphasize ? 20.sp : 18.sp,
                fontWeight: FontWeight.w800,
                color: emphasize ? accent : FinDT.textPrimary,
              ),
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            caption,
            style: GoogleFonts.inter(
              fontSize: 10.sp,
              color: FinDT.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountProjectionRow extends StatelessWidget {
  final _AccountProjection projection;
  final bool isSelected;
  final VoidCallback onTap;

  const _AccountProjectionRow({
    required this.projection,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final account = projection.account;
    final statusColor = projection.isOverdrawn
        ? FinDT.danger
        : projection.isTight
            ? FinDT.warning
            : FinDT.success;
    final statusLabel = projection.isOverdrawn
        ? 'Overdraft'
        : projection.isTight
            ? 'Tight'
            : 'Healthy';

    // Share of the wallet that pending approvals would consume.
    final ratio = projection.ledgerMinor <= 0
        ? (projection.pendingMinor > 0 ? 1.0 : 0.0)
        : (projection.pendingMinor / projection.ledgerMinor).clamp(0.0, 1.0);

    return Material(
      color: isSelected ? FinDT.brandLight : FinDT.bgPage,
      borderRadius: BorderRadius.circular(10.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: isSelected
                  ? FinDT.brand.withValues(alpha: 0.4)
                  : FinDT.border,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          account.name,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: FinDT.textPrimary,
                          ),
                        ),
                        SizedBox(height: 1.h),
                        Text(
                          '${account.code} • ${projection.pendingCount} pending',
                          style: GoogleFonts.inter(
                            fontSize: 10.sp,
                            color: FinDT.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _figure(
                      'Ledger',
                      _ProjectedBalanceStripState.money(
                          projection.ledgerMinor),
                      FinDT.textPrimary,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _figure(
                      'Pending',
                      projection.pendingMinor == 0
                          ? '—'
                          : '− ${_ProjectedBalanceStripState.money(projection.pendingMinor)}',
                      projection.pendingMinor == 0
                          ? FinDT.textMuted
                          : FinDT.warning,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _figure(
                      'Projected',
                      _ProjectedBalanceStripState.money(
                          projection.projectedMinor),
                      statusColor,
                      bold: true,
                    ),
                  ),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      statusLabel,
                      style: GoogleFonts.inter(
                        fontSize: 9.5.sp,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (projection.pendingMinor > 0) ...[
                SizedBox(height: 8.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3.r),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 4.h,
                    backgroundColor: FinDT.border,
                    valueColor: AlwaysStoppedAnimation(statusColor),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _figure(String label, String value, Color color,
      {bool bold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 9.sp, color: FinDT.textMuted),
        ),
        SizedBox(height: 1.h),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 11.5.sp,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _OverdraftWarning extends StatelessWidget {
  final List<_AccountProjection> accounts;
  final VoidCallback onReview;

  const _OverdraftWarning({required this.accounts, required this.onReview});

  @override
  Widget build(BuildContext context) {
    final names = accounts.map((a) => a.account.name).take(3).join(', ');
    final extra = accounts.length > 3 ? ' +${accounts.length - 3} more' : '';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: FinDT.danger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: FinDT.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 16.sp, color: FinDT.danger),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              accounts.length == 1
                  ? '$names would go negative if its pending expenses are all approved.'
                  : '${accounts.length} wallets would go negative if all pending expenses are approved: $names$extra.',
              style: GoogleFonts.inter(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: FinDT.danger,
                height: 1.35,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          TextButton(
            onPressed: onReview,
            style: TextButton.styleFrom(
              foregroundColor: FinDT.danger,
              padding: EdgeInsets.symmetric(horizontal: 10.w),
            ),
            child: Text(
              'Review',
              style: GoogleFonts.inter(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
