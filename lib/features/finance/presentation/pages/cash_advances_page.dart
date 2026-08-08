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
                  label: const Text('Export CSV'),
                ),
                SizedBox(width: 8.w),
                FilledButton.icon(
                  onPressed: () => _showIssueDialog(context),
                  icon: Icon(Icons.add, size: 16.sp),
                  label: const Text('Issue advance'),
                  style: FilledButton.styleFrom(backgroundColor: FinDT.brand),
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
                                TextButton(
                                  onPressed: () =>
                                      _showSettleDialog(context, a),
                                  child: const Text('Settle'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      _showWriteOffDialog(context, a),
                                  style: TextButton.styleFrom(
                                    foregroundColor: FinDT.danger,
                                  ),
                                  child: const Text('Write off'),
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
          title: const Text('Issue cash advance'),
          content: SizedBox(
            width: 420.w,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: accountId,
                    decoration: const InputDecoration(labelText: 'Fund account'),
                    items: accounts
                        .map(
                          (a) => DropdownMenuItem(
                            value: a.id,
                            child: Text('${a.name} (${a.currentBalance.toStringAsFixed(0)})'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setLocal(() => accountId = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  SizedBox(height: 12.h),
                  DropdownButtonFormField<EmployeeEntity>(
                    value: employee,
                    decoration: const InputDecoration(labelText: 'Employee'),
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
                  SizedBox(height: 12.h),
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: const InputDecoration(labelText: 'Amount'),
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'Invalid';
                      return null;
                    },
                  ),
                  SizedBox(height: 12.h),
                  TextFormField(
                    controller: purposeCtrl,
                    decoration: const InputDecoration(labelText: 'Purpose'),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
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
                Navigator.pop(ctx);
                try {
                  await context.read<CashAdvanceProvider>().issue(advance);
                  await context.read<FundAccountProvider>().fetchAllAccounts();
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
              child: const Text('Issue (deduct from fund)'),
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
        title: const Text('Write off advance?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mark remaining ${advance.outstanding.toStringAsFixed(2)} '
              '${advance.currency} for ${advance.employeeName} as a loss.\n\n'
              'Cash does NOT return to the fund (it already left when issued). '
              'This only closes the open advance.',
              style: GoogleFonts.inter(fontSize: 13.sp, height: 1.4),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason *',
                hintText: 'e.g. Employee left, unrecoverable',
                border: OutlineInputBorder(),
              ),
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
            child: const Text('Write off'),
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
    final ctrl = TextEditingController(
      text: advance.outstanding.toStringAsFixed(2),
    );
    var returnToFund = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Settle ${advance.employeeName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Outstanding: ${advance.outstanding.toStringAsFixed(2)}'),
              SizedBox(height: 12.h),
              TextField(
                controller: ctrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Settle amount'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Return cash to fund account'),
                value: returnToFund,
                onChanged: (v) => setLocal(() => returnToFund = v ?? true),
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
              child: const Text('Settle'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final amount = double.tryParse(ctrl.text) ?? 0;
    final user = context.read<AuthProvider>().user;
    try {
      await context.read<CashAdvanceProvider>().settle(
            advanceId: advance.id,
            amount: amount,
            actorName: user?.actorLabel ?? 'Unknown',
            actorUserId: user?.id ?? '',
            returnToFund: returnToFund,
          );
      await context.read<FundAccountProvider>().fetchAllAccounts();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: FinDT.danger),
        );
      }
    }
  }
}
