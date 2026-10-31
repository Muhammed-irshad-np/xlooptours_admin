import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/finance_policy_entity.dart';
import '../../domain/entities/fund_account_entity.dart';
import '../../domain/services/finance_permission_service.dart';
import '../pages/finance_dashboard_page.dart';
import '../providers/finance_provider.dart';
import '../providers/fund_account_provider.dart';

/// Master data view choosing which fund accounts the Salaries page may pay
/// from: one list for staff salaries, one for external drivers' trip payments.
/// A list left empty allows every active account.
class PayrollAccountsView extends StatefulWidget {
  const PayrollAccountsView({super.key});

  @override
  State<PayrollAccountsView> createState() => _PayrollAccountsViewState();
}

class _PayrollAccountsViewState extends State<PayrollAccountsView> {
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final accProv = context.read<FundAccountProvider>();
      if (accProv.accounts.isEmpty) accProv.fetchAllAccounts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final finProv = context.watch<FinanceProvider>();
    final accounts = context.watch<FundAccountProvider>().activeAccounts;
    final policy = finProv.policy;

    return Column(
      key: const ValueKey('payroll_accounts_view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: FinDT.bgPage,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: FinDT.border),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18.sp, color: FinDT.brand),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  'Only the accounts ticked here are offered when paying from the Salaries page. Leave a list empty to allow every active account.',
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    color: FinDT.textSecondary,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        LayoutBuilder(
          builder: (context, constraints) {
            final salaryCard = _buildAccountList(
              title: 'Salary Accounts',
              subtitle: 'Used to pay staff salaries',
              icon: Icons.groups_outlined,
              accounts: accounts,
              selected: policy.salaryAccountIds,
              onChanged: (ids) => _save(
                finProv,
                policy.copyWith(salaryAccountIds: ids),
                'Salary accounts updated',
              ),
            );
            final tripCard = _buildAccountList(
              title: 'External Trip Payment Accounts',
              subtitle: 'Used to pay external drivers for their trips',
              icon: Icons.local_shipping_outlined,
              accounts: accounts,
              selected: policy.tripPaymentAccountIds,
              onChanged: (ids) => _save(
                finProv,
                policy.copyWith(tripPaymentAccountIds: ids),
                'Trip payment accounts updated',
              ),
            );
            if (constraints.maxWidth < 800) {
              return Column(
                children: [salaryCard, SizedBox(height: 14.h), tripCard],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: salaryCard),
                SizedBox(width: 14.w),
                Expanded(child: tripCard),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildAccountList({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<FundAccountEntity> accounts,
    required List<String> selected,
    required ValueChanged<List<String>> onChanged,
  }) {
    // Ignore ids of accounts that were since deleted or deactivated.
    final activeSelected =
        selected.where((id) => accounts.any((a) => a.id == id)).toList();

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: FinDT.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20.sp, color: FinDT.brand),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: FinDT.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        color: FinDT.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: FinDT.brand.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  activeSelected.isEmpty
                      ? 'All accounts'
                      : '${activeSelected.length} selected',
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: FinDT.brand,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          const Divider(height: 1, color: FinDT.border),
          if (accounts.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Text(
                'No active fund accounts yet.',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  color: FinDT.textMuted,
                ),
              ),
            )
          else
            ...accounts.map(
              (a) => CheckboxListTile(
                value: activeSelected.contains(a.id),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: FinDT.brand,
                onChanged: _isSaving
                    ? null
                    : (checked) => onChanged(
                          checked == true
                              ? [...activeSelected, a.id]
                              : activeSelected.where((id) => id != a.id).toList(),
                        ),
                title: Text(
                  a.name,
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: FinDT.textPrimary,
                  ),
                ),
                subtitle: Text(
                  '${a.code} · ${a.typeDisplayName} · ${a.currency}',
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    color: FinDT.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _save(
    FinanceProvider finProv,
    FinancePolicyEntity updated,
    String successMessage,
  ) async {
    final user = context.read<AuthProvider>().user;
    if (!FinancePermissionService.canManageMasterData(
      user: user,
      policy: finProv.policy,
    )) {
      _snack('Your role is not allowed to change master data.', FinDT.danger);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await finProv.saveFinancePolicy(updated);
      if (mounted) _snack(successMessage, FinDT.success);
    } catch (e) {
      if (mounted) _snack('Failed to save: $e', FinDT.danger);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }
}
