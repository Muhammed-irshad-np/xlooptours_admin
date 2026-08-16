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

/// Issue and settle staff cash advances / floats.
class CashAdvancesPage extends StatefulWidget {
  const CashAdvancesPage({super.key});

  @override
  State<CashAdvancesPage> createState() => _CashAdvancesPageState();
}

class _CashAdvancesPageState extends State<CashAdvancesPage> {
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
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    return Consumer<CashAdvanceProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Cash advances / floats',
                    style: GoogleFonts.inter(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: FinDT.textPrimary,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final list = provider.advances;
                    if (list.isEmpty) return;
                    final name =
                        'advances_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
                    await FinanceExportService.shareCsv(
                      fileName: name,
                      csvContent: FinanceExportService.advancesToCsv(list),
                    );
                  },
                  icon: Icon(Icons.download_rounded, size: 16.sp),
                  label: Text(
                    'Export CSV',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FinDT.brand,
                    side: BorderSide(color: FinDT.brand.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                  ),
                ),
                SizedBox(width: 8.w),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 11.h),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              'Money leaves the fund when issued. Settlement can return cash to the fund.',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: FinDT.textSecondary,
              ),
            ),
            SizedBox(height: 16.h),
            if (provider.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (provider.advances.isEmpty)
              Padding(
                padding: EdgeInsets.all(32.w),
                child: Center(
                  child: Text(
                    'No advances yet',
                    style: GoogleFonts.inter(color: FinDT.textSecondary),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: provider.advances.length,
                  separatorBuilder: (_, __) => SizedBox(height: 8.h),
                  itemBuilder: (context, i) {
                    final a = provider.advances[i];
                    return Container(
                      padding: EdgeInsets.all(14.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
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
                                  a.employeeName,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.sp,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  a.purpose,
                                  style: GoogleFonts.inter(
                                    fontSize: 12.sp,
                                    color: FinDT.textSecondary,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  '${a.fundAccountName ?? a.fundAccountId} · '
                                  '${DateFormat.yMMMd().format(a.issuedAt)} · '
                                  '${a.status.displayName}',
                                  style: GoogleFonts.inter(fontSize: 11.sp),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${fmt.format(a.amount)} ${a.currency}',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Out: ${fmt.format(a.outstanding)}',
                                style: GoogleFonts.inter(
                                  fontSize: 11.sp,
                                  color: a.outstanding > 0
                                      ? FinDT.warning
                                      : FinDT.success,
                                ),
                              ),
                              if (a.isOpen) ...[
                                SizedBox(height: 6.h),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    OutlinedButton(
                                      onPressed: () =>
                                          _showSettleDialog(context, a),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: FinDT.brand,
                                        side: const BorderSide(color: FinDT.brand),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8.r),
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12.w,
                                          vertical: 6.h,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        'Settle',
                                        style: GoogleFonts.inter(
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 6.w),
                                    OutlinedButton(
                                      onPressed: () =>
                                          _showWriteOffDialog(context, a),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: FinDT.danger,
                                        side: BorderSide(
                                          color: FinDT.danger.withValues(alpha: 0.5),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8.r),
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 10.w,
                                          vertical: 6.h,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
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
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showIssueDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final amountCtrl = TextEditingController();
    final purposeCtrl = TextEditingController();
    String? accountId;
    EmployeeEntity? employee;
    final accounts = context.read<FundAccountProvider>().activeAccounts;
    final employees = context.read<EmployeeProvider>().employees;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: finDialogShape,
          title: finDialogTitle('Issue Cash Advance', icon: Icons.payments_outlined),
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
                        label: 'Fund Account *',
                        hint: 'Select fund source',
                        prefixIcon: Icons.account_balance_wallet_outlined,
                      ),
                      style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
                      items: accounts
                          .map(
                            (a) => DropdownMenuItem(
                              value: a.id,
                              child: Text('${a.name} (${a.currentBalance.toStringAsFixed(0)} ${a.currency})'),
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
                        label: 'Employee *',
                        hint: 'Select employee recipient',
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
                      onChanged: (v) => setLocal(() => employee = v),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    SizedBox(height: 14.h),
                    TextFormField(
                      controller: amountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                      decoration: finDialogInputDecoration(
                        label: 'Advance Amount *',
                        hint: '0.00',
                        prefixIcon: Icons.attach_money_rounded,
                        suffixText: 'SAR',
                      ),
                      style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        if (n == null || n <= 0) return 'Enter a valid positive amount';
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
                      style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Purpose required' : null,
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
                  issuedBy: user?.actorLabel ?? 'Unknown',
                  issuedByUserId: user?.id,
                  issuedAt: DateTime.now(),
                  createdAt: DateTime.now(),
                );
                final advProv = context.read<CashAdvanceProvider>();
                final fundProv = context.read<FundAccountProvider>();
                Navigator.pop(ctx);
                try {
                  await advProv.issue(advance);
                  await fundProv.fetchAllAccounts();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$e'),
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
        ),
      ),
    );
  }

  Future<void> _showWriteOffDialog(
    BuildContext context,
    CashAdvanceEntity advance,
  ) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: finDialogShape,
        title: finDialogTitle('Write Off Advance?', icon: Icons.warning_amber_rounded, iconColor: FinDT.danger),
        content: SizedBox(
          width: 420.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: FinDT.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: FinDT.danger.withValues(alpha: 0.25)),
                ),
                child: Text(
                  'Mark remaining ${advance.outstanding.toStringAsFixed(2)} '
                  '${advance.currency} for ${advance.employeeName} as a loss.\n\n'
                  'Cash does NOT return to the fund. This only closes the open advance.',
                  style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.danger, height: 1.4),
                ),
              ),
              SizedBox(height: 14.h),
              TextField(
                controller: reasonCtrl,
                maxLines: 2,
                decoration: finDialogInputDecoration(
                  label: 'Reason *',
                  hint: 'e.g. Employee left, unrecoverable',
                  prefixIcon: Icons.edit_note_rounded,
                ),
                style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
              ),
            ],
          ),
        ),
        actions: [
          finDialogCancelButton(ctx),
          finDialogActionButton(
            onPressed: () => Navigator.pop(ctx, true),
            label: 'Write Off',
            backgroundColor: FinDT.danger,
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    if (reasonCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reason is required')),
      );
      return;
    }
    final user = context.read<AuthProvider>().user;
    try {
      await context.read<CashAdvanceProvider>().writeOff(
            advanceId: advance.id,
            reason: reasonCtrl.text.trim(),
            actorName: user?.actorLabel ?? 'Unknown',
            actorUserId: user?.id ?? '',
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Advance written off'),
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
          title: finDialogTitle('Settle Advance', icon: Icons.receipt_long_rounded),
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
                              'Recipient:',
                              style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textSecondary),
                            ),
                            Text(
                              advance.employeeName,
                              style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: FinDT.textPrimary),
                            ),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Outstanding Amount:',
                              style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textSecondary),
                            ),
                            Text(
                              '${advance.outstanding.toStringAsFixed(2)} ${advance.currency}',
                              style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: FinDT.warning),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 14.h),
                  TextFormField(
                    controller: ctrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: finDialogInputDecoration(
                      label: 'Settle Amount *',
                      prefixIcon: Icons.payments_outlined,
                      suffixText: advance.currency,
                    ),
                    style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
                    validator: (v) {
                      final val = double.tryParse(v ?? '');
                      if (val == null || val <= 0) return 'Enter a valid positive amount';
                      if (val > advance.outstanding) return 'Cannot exceed outstanding balance';
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
                        'Return cash to fund account',
                        style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w500, color: FinDT.textPrimary),
                      ),
                      activeColor: FinDT.brand,
                      value: returnToFund,
                      onChanged: (v) => setLocal(() => returnToFund = v ?? true),
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
                Navigator.pop(ctx, true);
              },
              label: 'Settle Advance',
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
        actorName: user?.actorLabel ?? 'Unknown',
        actorUserId: user?.id ?? '',
        returnToFund: returnToFund,
      );
      await fundProv.fetchAllAccounts();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: FinDT.danger),
        );
      }
    }
  }
}
