import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../employee/domain/entities/employee_entity.dart';
import '../../../employee/presentation/providers/employee_provider.dart';
import '../../domain/entities/cash_advance_entity.dart';
import '../../domain/services/finance_export_service.dart';
import '../providers/cash_advance_provider.dart';
import '../providers/fund_account_provider.dart';
import '../widgets/finance_dialog_helpers.dart';
import 'finance_dashboard_page.dart';

/// Issue, monitor, and settle staff cash advances / operational floats.
class CashAdvancesPage extends StatefulWidget {
  const CashAdvancesPage({super.key});

  @override
  State<CashAdvancesPage> createState() => _CashAdvancesPageState();
}

class _CashAdvancesPageState extends State<CashAdvancesPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedStatusFilter = 'ALL';
  String? _selectedFundAccountFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CashAdvanceProvider>().load();
      context.read<EmployeeProvider>().fetchAllEmployees();
      context.read<FundAccountProvider>().fetchAllAccounts();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<CashAdvanceEntity> _filterAdvances(List<CashAdvanceEntity> advances) {
    return advances.where((a) {
      // Status filter
      if (_selectedStatusFilter == 'OPEN' && a.status != CashAdvanceStatus.open) {
        return false;
      }
      if (_selectedStatusFilter == 'PARTIALLY_SETTLED' &&
          a.status != CashAdvanceStatus.partiallySettled) {
        return false;
      }
      if (_selectedStatusFilter == 'SETTLED' &&
          a.status != CashAdvanceStatus.settled) {
        return false;
      }
      if (_selectedStatusFilter == 'WRITTEN_OFF' &&
          a.status != CashAdvanceStatus.writtenOff) {
        return false;
      }
      if (_selectedStatusFilter == 'ACTIVE' && !a.isOpen) {
        return false;
      }

      // Fund account filter
      if (_selectedFundAccountFilter != null &&
          _selectedFundAccountFilter!.isNotEmpty &&
          a.fundAccountId != _selectedFundAccountFilter) {
        return false;
      }

      // Search query
      final q = _searchCtrl.text.trim().toLowerCase();
      if (q.isNotEmpty) {
        final empMatch = a.employeeName.toLowerCase().contains(q);
        final purpMatch = a.purpose.toLowerCase().contains(q);
        final accMatch = (a.fundAccountName ?? '').toLowerCase().contains(q);
        final issuerMatch = a.issuedBy.toLowerCase().contains(q);
        if (!empMatch && !purpMatch && !accMatch && !issuerMatch) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');

    return Consumer<CashAdvanceProvider>(
      builder: (context, provider, _) {
        final allAdvances = provider.advances;
        final filteredAdvances = _filterAdvances(allAdvances);

        final totalIssued = allAdvances.fold(0.0, (sum, a) => sum + a.amount);
        final totalOutstanding =
            allAdvances.fold(0.0, (sum, a) => sum + a.outstanding);
        final totalSettled =
            allAdvances.fold(0.0, (sum, a) => sum + a.settledAmount);
        final activeCount = allAdvances.where((a) => a.isOpen).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Action & Summary Bar ────────────────────────────
            Container(
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: FinDT.brand.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Icon(
                          Icons.payments_outlined,
                          size: 20.sp,
                          color: FinDT.brand,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cash Advances & Floats',
                            style: GoogleFonts.inter(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                              color: FinDT.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            'Issue staff operational floats, track settlements, and manage outstanding balances',
                            style: GoogleFonts.inter(
                              fontSize: 11.sp,
                              color: FinDT.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: allAdvances.isEmpty
                            ? null
                            : () async {
                                final name =
                                    'advances_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
                                await FinanceExportService.shareCsv(
                                  fileName: name,
                                  csvContent:
                                      FinanceExportService.advancesToCsv(allAdvances),
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
                          side: BorderSide(
                            color: FinDT.brand.withValues(alpha: 0.4),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 14.w,
                            vertical: 10.h,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      ElevatedButton.icon(
                        onPressed: () => _showIssueDialog(context),
                        icon: Icon(Icons.add_rounded, size: 16.sp),
                        label: Text(
                          'Issue Advance',
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: FinDT.brand,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 10.h,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),

            // ── KPI Summary Cards ───────────────────────────────────
            GridView.count(
              crossAxisCount: 4,
              mainAxisSpacing: 14.h,
              crossAxisSpacing: 14.w,
              childAspectRatio: 1.8,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildKpiCard(
                  title: 'Total Advances Issued',
                  value: '${fmt.format(totalIssued)} SAR',
                  subtitle: '${allAdvances.length} total advances',
                  icon: Icons.payments_outlined,
                  color: FinDT.brand,
                ),
                _buildKpiCard(
                  title: 'Outstanding Float',
                  value: '${fmt.format(totalOutstanding)} SAR',
                  subtitle: '$activeCount active float(s)',
                  icon: Icons.pending_actions_rounded,
                  color: totalOutstanding > 0 ? FinDT.warning : FinDT.success,
                ),
                _buildKpiCard(
                  title: 'Settled to Date',
                  value: '${fmt.format(totalSettled)} SAR',
                  subtitle: 'Returned / liquidated',
                  icon: Icons.check_circle_outline_rounded,
                  color: FinDT.success,
                ),
                _buildKpiCard(
                  title: 'Active Open Advances',
                  value: '$activeCount',
                  subtitle: 'Awaiting settlement',
                  icon: Icons.person_outline_rounded,
                  color: activeCount > 0 ? const Color(0xFF0891B2) : FinDT.textSecondary,
                ),
              ],
            ),
            SizedBox(height: 16.h),

            // ── Search & Filter Controls ────────────────────────────
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: FinDT.border),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Search input
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (_) => setState(() {}),
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            color: FinDT.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search by employee, purpose, or fund account...',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 12.sp,
                              color: FinDT.textMuted,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              size: 18.sp,
                              color: FinDT.textSecondary,
                            ),
                            suffixIcon: _searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear, size: 16.sp),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: FinDT.bgPage,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 14.w,
                              vertical: 10.h,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.r),
                              borderSide: const BorderSide(color: FinDT.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.r),
                              borderSide: const BorderSide(color: FinDT.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.r),
                              borderSide: const BorderSide(
                                color: FinDT.brand,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),

                      // Fund account filter
                      Consumer<FundAccountProvider>(
                        builder: (context, fundProv, _) {
                          final accounts = fundProv.accounts;
                          return SizedBox(
                            width: 220.w,
                            child: DropdownButtonFormField<String?>(
                              initialValue: _selectedFundAccountFilter,
                              decoration: InputDecoration(
                                hintText: 'All Fund Sources',
                                hintStyle: GoogleFonts.inter(
                                  fontSize: 12.sp,
                                  color: FinDT.textSecondary,
                                ),
                                prefixIcon: Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 16.sp,
                                  color: FinDT.brand,
                                ),
                                filled: true,
                                fillColor: FinDT.bgPage,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 10.h,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                  borderSide:
                                      const BorderSide(color: FinDT.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                  borderSide:
                                      const BorderSide(color: FinDT.border),
                                ),
                              ),
                              style: GoogleFonts.inter(
                                fontSize: 12.sp,
                                color: FinDT.textPrimary,
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('All Fund Sources'),
                                ),
                                ...accounts.map(
                                  (a) => DropdownMenuItem<String?>(
                                    value: a.id,
                                    child: Text(
                                      a.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _selectedFundAccountFilter = v),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),

                  // Status Filter Pills
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildStatusPill(
                          label: 'All Advances',
                          count: allAdvances.length,
                          value: 'ALL',
                        ),
                        SizedBox(width: 8.w),
                        _buildStatusPill(
                          label: 'Active / Open',
                          count: allAdvances.where((a) => a.isOpen).length,
                          value: 'ACTIVE',
                          color: FinDT.warning,
                        ),
                        SizedBox(width: 8.w),
                        _buildStatusPill(
                          label: 'Partially Settled',
                          count: allAdvances
                              .where(
                                (a) =>
                                    a.status ==
                                    CashAdvanceStatus.partiallySettled,
                              )
                              .length,
                          value: 'PARTIALLY_SETTLED',
                          color: const Color(0xFF0891B2),
                        ),
                        SizedBox(width: 8.w),
                        _buildStatusPill(
                          label: 'Fully Settled',
                          count: allAdvances
                              .where(
                                (a) => a.status == CashAdvanceStatus.settled,
                              )
                              .length,
                          value: 'SETTLED',
                          color: FinDT.success,
                        ),
                        SizedBox(width: 8.w),
                        _buildStatusPill(
                          label: 'Written Off',
                          count: allAdvances
                              .where(
                                (a) => a.status == CashAdvanceStatus.writtenOff,
                              )
                              .length,
                          value: 'WRITTEN_OFF',
                          color: FinDT.danger,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),

            // ── Advances List ───────────────────────────────────────
            if (provider.isLoading)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 40.h),
                child: const Center(
                  child: CircularProgressIndicator(color: FinDT.brand),
                ),
              )
            else if (filteredAdvances.isEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(40.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: FinDT.border),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: FinDT.brandLight,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.payments_outlined,
                        size: 32.sp,
                        color: FinDT.brand,
                      ),
                    ),
                    SizedBox(height: 14.h),
                    Text(
                      allAdvances.isEmpty
                          ? 'No cash advances issued yet'
                          : 'No advances match your filter',
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: FinDT.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      allAdvances.isEmpty
                          ? 'Click "Issue Advance" to grant a float to a staff member.'
                          : 'Try resetting your search or selecting a different status filter.',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: FinDT.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredAdvances.length,
                separatorBuilder: (_, __) => SizedBox(height: 10.h),
                itemBuilder: (context, i) {
                  final a = filteredAdvances[i];
                  return _buildAdvanceCard(context, a, fmt);
                },
              ),
          ],
        );
      },
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

  Widget _buildStatusPill({
    required String label,
    required int count,
    required String value,
    Color? color,
  }) {
    final isSelected = _selectedStatusFilter == value;
    final activeColor = color ?? FinDT.brand;

    return InkWell(
      onTap: () => setState(() => _selectedStatusFilter = value),
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.12)
              : FinDT.bgPage,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: isSelected
                ? activeColor.withValues(alpha: 0.5)
                : FinDT.border,
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

  Widget _buildAdvanceCard(
    BuildContext context,
    CashAdvanceEntity advance,
    NumberFormat fmt,
  ) {
    final statusColor = _resolveStatusColor(advance.status);
    final isSettled = advance.status == CashAdvanceStatus.settled;
    final isWrittenOff = advance.status == CashAdvanceStatus.writtenOff;
    final progress = advance.amount > 0
        ? (advance.settledAmount / advance.amount).clamp(0.0, 1.0)
        : 0.0;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Staff Avatar Circle
              CircleAvatar(
                radius: 20.r,
                backgroundColor: FinDT.brand.withValues(alpha: 0.1),
                child: Text(
                  advance.employeeName.isNotEmpty
                      ? advance.employeeName.substring(0, 1).toUpperCase()
                      : 'E',
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: FinDT.brand,
                  ),
                ),
              ),
              SizedBox(width: 14.w),

              // Staff & Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          advance.employeeName,
                          style: GoogleFonts.inter(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: FinDT.textPrimary,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 7.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            advance.status.displayName,
                            style: GoogleFonts.inter(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      advance.purpose,
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: FinDT.textSecondary,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      children: [
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 11.sp,
                                color: FinDT.brand,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                advance.fundAccountName ?? advance.fundAccountId,
                                style: GoogleFonts.inter(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w600,
                                  color: FinDT.brand,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 12.sp,
                          color: FinDT.textMuted,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          DateFormat('dd MMM yyyy').format(advance.issuedAt),
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            color: FinDT.textMuted,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          '• Issued by ${advance.issuedBy}',
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            color: FinDT.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Amount & Actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${fmt.format(advance.amount)} ${advance.currency}',
                    style: GoogleFonts.inter(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      color: FinDT.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  if (advance.isOpen)
                    Text(
                      'Outstanding: ${fmt.format(advance.outstanding)} ${advance.currency}',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: FinDT.warning,
                      ),
                    )
                  else if (isSettled)
                    Text(
                      'Fully Settled',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: FinDT.success,
                      ),
                    )
                  else if (isWrittenOff)
                    Text(
                      'Written Off as Loss',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: FinDT.danger,
                      ),
                    ),
                  SizedBox(height: 8.h),
                  if (advance.isOpen)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _showSettleDialog(context, advance),
                          icon: Icon(Icons.receipt_long_rounded, size: 13.sp),
                          label: Text(
                            'Settle',
                            style: GoogleFonts.inter(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: FinDT.brand,
                            elevation: 0,
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 6.h,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                        ),
                        SizedBox(width: 6.w),
                        OutlinedButton(
                          onPressed: () => _showWriteOffDialog(context, advance),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: FinDT.danger,
                            side: BorderSide(
                              color: FinDT.danger.withValues(alpha: 0.4),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 6.h,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                          child: Text(
                            'Write off',
                            style: GoogleFonts.inter(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),

          // Settlement Progress Bar
          if (advance.settledAmount > 0 && advance.isOpen) ...[
            SizedBox(height: 12.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(4.r),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5.h,
                backgroundColor: const Color(0xFFF3F4F6),
                valueColor: const AlwaysStoppedAnimation<Color>(FinDT.success),
              ),
            ),
            SizedBox(height: 4.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Settled: ${fmt.format(advance.settledAmount)} ${advance.currency} (${(progress * 100).toStringAsFixed(0)}%)',
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    color: FinDT.textSecondary,
                  ),
                ),
                Text(
                  'Remaining: ${fmt.format(advance.outstanding)} ${advance.currency}',
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: FinDT.warning,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _resolveStatusColor(CashAdvanceStatus status) {
    switch (status) {
      case CashAdvanceStatus.open:
        return FinDT.warning;
      case CashAdvanceStatus.partiallySettled:
        return const Color(0xFF0891B2);
      case CashAdvanceStatus.settled:
        return FinDT.success;
      case CashAdvanceStatus.writtenOff:
        return FinDT.danger;
    }
  }

  Future<void> _showIssueDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final amountCtrl = TextEditingController();
    final purposeCtrl = TextEditingController();
    String? accountId;
    EmployeeEntity? employee;
    final accounts = context.read<FundAccountProvider>().activeAccounts;
    final employees = context.read<EmployeeProvider>().employees;

    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No active fund accounts available. Create or activate an account in the Accounts tab first.',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: FinDT.danger,
        ),
      );
      return;
    }

    if (employees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No employee records found. Add employees in the Employee module first.',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: FinDT.danger,
        ),
      );
      return;
    }

    // Default to first account
    accountId = accounts.first.id;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final selectedAccount = accounts.firstWhere(
            (a) => a.id == accountId,
            orElse: () => accounts.first,
          );

          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: finDialogShape,
            title: finDialogTitle(
              'Issue Cash Advance / Float',
              icon: Icons.payments_outlined,
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
                      DropdownButtonFormField<String>(
                        initialValue: accountId,
                        decoration: finDialogInputDecoration(
                          label: 'Fund Account Source *',
                          hint: 'Select fund account',
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
                                  '${a.name} (${a.currentBalance.toStringAsFixed(2)} ${a.currency})',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setLocal(() => accountId = v),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      SizedBox(height: 14.h),
                      DropdownButtonFormField<EmployeeEntity>(
                        initialValue: employee,
                        decoration: finDialogInputDecoration(
                          label: 'Employee Recipient *',
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
                                child: Text(e.fullName),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setLocal(() => employee = v),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      SizedBox(height: 14.h),
                      TextFormField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'),
                          ),
                        ],
                        decoration: finDialogInputDecoration(
                          label: 'Advance Amount *',
                          hint: '0.00',
                          prefixIcon: Icons.attach_money_rounded,
                          suffixText: selectedAccount.currency,
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
                          if (n > selectedAccount.currentBalance) {
                            return 'Exceeds current balance (${selectedAccount.currentBalance.toStringAsFixed(2)} ${selectedAccount.currency})';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 14.h),
                      TextFormField(
                        controller: purposeCtrl,
                        decoration: finDialogInputDecoration(
                          label: 'Purpose *',
                          hint: 'e.g. Fuel float, driver emergency trip expenses',
                          prefixIcon: Icons.description_outlined,
                        ),
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          color: FinDT.textPrimary,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Purpose required'
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              finDialogCancelButton(ctx),
              finDialogActionButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final user = context.read<AuthProvider>().user;
                  final acc = accounts.firstWhere((a) => a.id == accountId);
                  final amount = double.parse(amountCtrl.text);

                  final advance = CashAdvanceEntity(
                    id: const Uuid().v4(),
                    fundAccountId: acc.id,
                    fundAccountName: acc.name,
                    employeeId: employee!.id,
                    employeeName: employee!.fullName,
                    amount: amount,
                    amountMinor: (amount * 100).round(),
                    currency: acc.currency,
                    purpose: purposeCtrl.text.trim(),
                    issuedBy: user?.actorLabel ?? 'Admin',
                    issuedByUserId: user?.id,
                    issuedAt: DateTime.now(),
                    createdAt: DateTime.now(),
                  );

                  final advProv = context.read<CashAdvanceProvider>();
                  final fundProv = context.read<FundAccountProvider>();

                  finSafePop(ctx);

                  try {
                    await advProv.issue(advance);
                    await fundProv.fetchAllAccounts();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Successfully issued ${advance.amount.toStringAsFixed(2)} ${advance.currency} float to ${advance.employeeName}',
                          ),
                          backgroundColor: FinDT.success,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to issue advance: $e'),
                          backgroundColor: FinDT.danger,
                        ),
                      );
                    }
                  }
                },
                label: 'Issue Advance',
                backgroundColor: FinDT.brand,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showWriteOffDialog(
    BuildContext context,
    CashAdvanceEntity advance,
  ) async {
    final reasonCtrl = TextEditingController();

    final confirm = await showFinConfirmationDialog(
      context: context,
      title: 'Write Off Advance?',
      message:
          'Mark remaining ${advance.outstanding.toStringAsFixed(2)} ${advance.currency} for ${advance.employeeName} as an unrecoverable operational loss.',
      highlightNote:
          'Cash does NOT return to the fund account. This action permanently closes the outstanding advance.',
      confirmLabel: 'Write Off as Loss',
      confirmColor: FinDT.danger,
      icon: Icons.warning_amber_rounded,
      iconColor: FinDT.danger,
      customContent: TextField(
        controller: reasonCtrl,
        maxLines: 2,
        decoration: finDialogInputDecoration(
          label: 'Reason for Write Off *',
          hint: 'e.g. Employee left company, unrecoverable discrepancy',
          prefixIcon: Icons.edit_note_rounded,
        ),
        style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
      ),
    );

    if (confirm != true || !context.mounted) return;

    if (reasonCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reason is required to write off an advance'),
          backgroundColor: FinDT.danger,
        ),
      );
      return;
    }

    final user = context.read<AuthProvider>().user;
    try {
      await context.read<CashAdvanceProvider>().writeOff(
            advanceId: advance.id,
            reason: reasonCtrl.text.trim(),
            actorName: user?.actorLabel ?? 'Admin',
            actorUserId: user?.id ?? '',
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Advance marked as written off'),
            backgroundColor: FinDT.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error writing off advance: $e'),
            backgroundColor: FinDT.danger,
          ),
        );
      }
    }
  }

  Future<void> _showSettleDialog(
    BuildContext context,
    CashAdvanceEntity advance,
  ) async {
    final formKey = GlobalKey<FormState>();
    final ctrl = TextEditingController(
      text: advance.outstanding.toStringAsFixed(2),
    );
    var returnToFund = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: finDialogShape,
          title: finDialogTitle(
            'Settle Cash Advance',
            icon: Icons.receipt_long_rounded,
          ),
          content: SizedBox(
            width: 420.w,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: FinDT.bgPage,
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: FinDT.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Recipient Staff:',
                              style: GoogleFonts.inter(
                                fontSize: 12.sp,
                                color: FinDT.textSecondary,
                              ),
                            ),
                            Text(
                              advance.employeeName,
                              style: GoogleFonts.inter(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                color: FinDT.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Current Outstanding:',
                              style: GoogleFonts.inter(
                                fontSize: 12.sp,
                                color: FinDT.textSecondary,
                              ),
                            ),
                            Text(
                              '${advance.outstanding.toStringAsFixed(2)} ${advance.currency}',
                              style: GoogleFonts.inter(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                                color: FinDT.warning,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 14.h),
                  TextFormField(
                    controller: ctrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d*'),
                      ),
                    ],
                    decoration: finDialogInputDecoration(
                      label: 'Settlement Amount *',
                      prefixIcon: Icons.payments_outlined,
                      suffixText: advance.currency,
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: FinDT.textPrimary,
                    ),
                    validator: (v) {
                      final val = double.tryParse(v ?? '');
                      if (val == null || val <= 0) {
                        return 'Enter a valid positive amount';
                      }
                      if (val > advance.outstanding + 1e-6) {
                        return 'Cannot exceed outstanding balance (${advance.outstanding.toStringAsFixed(2)})';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 12.h),
                  Container(
                    decoration: BoxDecoration(
                      color: FinDT.bgPage,
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: FinDT.border),
                    ),
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 10.w),
                      title: Text(
                        'Return cash to source fund account',
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: FinDT.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Deposits amount back to ${advance.fundAccountName ?? advance.fundAccountId}',
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          color: FinDT.textSecondary,
                        ),
                      ),
                      activeColor: FinDT.brand,
                      value: returnToFund,
                      onChanged: (v) =>
                          setLocal(() => returnToFund = v ?? true),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            finDialogCancelButton(ctx),
            finDialogActionButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                finSafePop(ctx, true);
              },
              label: 'Confirm Settlement',
              backgroundColor: FinDT.brand,
            ),
          ],
        ),
      ),
    );

    if (ok != true || !context.mounted) return;

    final amount = double.tryParse(ctrl.text) ?? 0;
    final user = context.read<AuthProvider>().user;
    final advProv = context.read<CashAdvanceProvider>();
    final fundProv = context.read<FundAccountProvider>();

    try {
      await advProv.settle(
        advanceId: advance.id,
        amount: amount,
        actorName: user?.actorLabel ?? 'Admin',
        actorUserId: user?.id ?? '',
        returnToFund: returnToFund,
      );
      await fundProv.fetchAllAccounts();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully settled ${amount.toStringAsFixed(2)} ${advance.currency} for ${advance.employeeName}',
            ),
            backgroundColor: FinDT.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to settle advance: $e'),
            backgroundColor: FinDT.danger,
          ),
        );
      }
    }
  }
}
