import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:xloop_invoice/features/finance/domain/entities/fund_transaction_entity.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/fund_account_provider.dart';
import '../widgets/fund_account_card.dart';
import '../widgets/currency_display.dart';
import '../../domain/entities/fund_account_entity.dart';
import '../../domain/entities/fund_account_type_entity.dart';
import '../../domain/services/finance_permission_service.dart';
import '../../../../features/employee/presentation/providers/employee_provider.dart';
import '../../../../features/employee/domain/entities/employee_entity.dart';
import '../widgets/finance_dialog_helpers.dart';
import 'finance_dashboard_page.dart';

/// Screen for managing virtual fund accounts and viewing transaction history.
class FundAccountsPage extends StatefulWidget {
  const FundAccountsPage({super.key});

  @override
  State<FundAccountsPage> createState() => _FundAccountsPageState();
}

class _FundAccountsPageState extends State<FundAccountsPage> {
  String _accountFilter = 'ALL';
  String _txFilter = 'ALL';
  final _txSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Fetch accounts and select the first one by default if not already selected
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<FundAccountProvider>();
      provider.fetchAllAccounts().then((_) {
        if (provider.activeAccounts.isNotEmpty &&
            provider.selectedAccountId == null) {
          provider.selectAccount(provider.activeAccounts.first.id);
        }
      });
    });
  }

  @override
  void dispose() {
    _txSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FundAccountProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.accounts.isEmpty) {
          return _buildLoading();
        }

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
                      'Virtual Accounts & Treasury',
                      style: GoogleFonts.inter(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: FinDT.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Manage bank accounts, petty cash drawers, and live payment ledgers',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: FinDT.textSecondary,
                      ),
                    ),
                  ],
                ),
                _buildCreateAccountButton(context, provider),
              ],
            ),
            SizedBox(height: 16.h),

            // Top Treasury Pulse Summary Bar
            _buildTreasurySummaryBanner(provider),
            SizedBox(height: 20.h),

            // 2-Column Content Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Accounts List & Filters
                Expanded(flex: 4, child: _buildAccountsColumn(context, provider)),
                SizedBox(width: 20.w),

                // Right Column: Details & Transaction Log
                Expanded(flex: 5, child: _buildDetailsColumn(context, provider)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoading() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 40.h),
      child: const Center(child: CircularProgressIndicator(color: FinDT.brand)),
    );
  }

  Widget _buildTreasurySummaryBanner(FundAccountProvider provider) {
    final active = provider.activeAccounts;
    final formatter = NumberFormat('#,##0.00', 'en_US');

    double totalBalance = 0;
    double totalCash = 0;
    double totalStc = 0;
    int pettyCount = 0;
    int bankCount = 0;
    int driverCount = 0;

    for (final acc in active) {
      totalBalance += acc.currentBalance;
      if (acc.isPettyCash) {
        totalCash += acc.cashBalance;
        totalStc += acc.stcPayBalance;
        pettyCount++;
      } else if (acc.isBank || acc.isStcPay) {
        totalStc += acc.currentBalance;
        bankCount++;
      } else {
        driverCount++;
      }
    }

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
          // Total Liquidity
          Expanded(
            child: _buildSummaryMetric(
              title: 'TOTAL TREASURY LIQUIDITY',
              value: '${formatter.format(totalBalance)} SAR',
              icon: Icons.account_balance_wallet_rounded,
              iconColor: FinDT.brand,
              badgeText: '${active.length} Active Accounts',
              badgeColor: FinDT.brand,
            ),
          ),
          Container(height: 48.h, width: 1, color: FinDT.borderLight),

          // Physical Cash in Hand
          Expanded(
            child: _buildSummaryMetric(
              title: 'PHYSICAL CASH IN HAND',
              value: '${formatter.format(totalCash)} SAR',
              icon: Icons.payments_outlined,
              iconColor: const Color(0xFF16A34A),
              badgeText: '$pettyCount Petty Drawers',
              badgeColor: const Color(0xFF16A34A),
            ),
          ),
          Container(height: 48.h, width: 1, color: FinDT.borderLight),

          // Digital & Bank Float
          Expanded(
            child: _buildSummaryMetric(
              title: 'DIGITAL & BANK FLOAT',
              value: '${formatter.format(totalStc)} SAR',
              icon: Icons.phone_android_outlined,
              iconColor: const Color(0xFF7C3AED),
              badgeText: '$bankCount Bank / STC Wallets',
              badgeColor: const Color(0xFF7C3AED),
            ),
          ),
          Container(height: 48.h, width: 1, color: FinDT.borderLight),

          // Custom / Driver & Operations
          Expanded(
            child: _buildSummaryMetric(
              title: 'OPERATIONS & OTHER',
              value: '$driverCount Accounts',
              icon: Icons.category_outlined,
              iconColor: const Color(0xFF2563EB),
              badgeText: 'Custom & Ops',
              badgeColor: const Color(0xFF2563EB),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required String badgeText,
    required Color badgeColor,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, color: iconColor, size: 20.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: FinDT.textSecondary,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: FinDT.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                Text(
                  badgeText,
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w500,
                    color: badgeColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsColumn(
    BuildContext context,
    FundAccountProvider provider,
  ) {
    final active = provider.activeAccounts;
    if (active.isEmpty) {
      return _buildEmptyAccounts(context, provider);
    }

    final filtered = active.where((a) {
      if (_accountFilter == 'ALL') return true;
      if (_accountFilter == 'PETTY_CASH') return a.isPettyCash;
      if (_accountFilter == 'BANK') return a.isBank;
      if (_accountFilter == 'STC_PAY') return a.isStcPay;
      return a.accountTypeId == _accountFilter ||
          a.typeDisplayName.toUpperCase() == _accountFilter.toUpperCase();
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildAccountFilterChip('ALL', 'All (${active.length})'),
              SizedBox(width: 8.w),
              _buildAccountFilterChip(
                'PETTY_CASH',
                'Petty Cash (${active.where((a) => a.isPettyCash).length})',
              ),
              SizedBox(width: 8.w),
              _buildAccountFilterChip(
                'BANK',
                'Bank (${active.where((a) => a.isBank).length})',
              ),
              SizedBox(width: 8.w),
              _buildAccountFilterChip(
                'STC_PAY',
                'STC Pay (${active.where((a) => a.isStcPay).length})',
              ),
              // Dynamic custom types filter chips
              ...provider.accountTypes
                  .where((t) => !t.isSystemDefault)
                  .map((customType) {
                final count = active.where((a) =>
                    a.accountTypeId == customType.id ||
                    a.typeDisplayName.toLowerCase() ==
                        customType.name.toLowerCase()).length;
                return Padding(
                  padding: EdgeInsets.only(left: 8.w),
                  child: _buildAccountFilterChip(
                    customType.id,
                    '${customType.name} ($count)',
                  ),
                );
              }),
            ],
          ),
        ),
        SizedBox(height: 14.h),

        if (filtered.isEmpty)
          Container(
            padding: EdgeInsets.all(32.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: FinDT.border),
            ),
            child: Center(
              child: Text(
                'No accounts matching this category',
                style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textSecondary),
              ),
            ),
          )
        else
          GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14.w,
              mainAxisSpacing: 14.h,
              childAspectRatio: 1.25,
            ),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final account = filtered[index];
              final isSelected = provider.selectedAccountId == account.id;
              return FundAccountCard(
                account: account,
                isSelected: isSelected,
                onTap: () => provider.selectAccount(account.id),
              );
            },
          ),
      ],
    );
  }

  Widget _buildAccountFilterChip(String filterKey, String label) {
    final isSelected = _accountFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _accountFilter = filterKey),
      labelStyle: GoogleFonts.inter(
        fontSize: 11.sp,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : FinDT.textSecondary,
      ),
      selectedColor: FinDT.brand,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? FinDT.brand : FinDT.border,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.r),
      ),
      showCheckmark: false,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
    );
  }

  Widget _buildEmptyAccounts(BuildContext context, FundAccountProvider provider) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 40.h),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: FinDT.brand.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 32.sp,
              color: FinDT.brand,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'No Accounts Created Yet',
            style: GoogleFonts.inter(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: FinDT.textPrimary,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Create your first virtual account (e.g. Bank Account or Petty Cash Drawer) to manage balances.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              color: FinDT.textSecondary,
              height: 1.4,
            ),
          ),
          SizedBox(height: 20.h),
          ElevatedButton.icon(
            onPressed: () => _showAccountFormDialog(context, provider),
            icon: Icon(Icons.add_rounded, size: 16.sp),
            label: Text(
              'Add First Account',
              style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: FinDT.brand,
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
    );
  }

  Widget _buildCreateAccountButton(
    BuildContext context,
    FundAccountProvider provider,
  ) {
    final user = context.read<AuthProvider>().user;
    final policy = context.read<FinanceProvider>().policy;
    final canTransfer = FinancePermissionService.canTransferFunds(user: user, policy: policy);
    final canManageAccounts = FinancePermissionService.canManageAccounts(user: user, policy: policy);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canTransfer)
          OutlinedButton.icon(
            onPressed: () => _showTransferDialog(context, provider),
            icon: Icon(Icons.swap_horiz_rounded, size: 16.sp),
            label: Text(
              'Transfer',
              style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: FinDT.textPrimary,
              side: const BorderSide(color: FinDT.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
            ),
          ),
        if (canTransfer && canManageAccounts) SizedBox(width: 8.w),
        if (canManageAccounts)
          ElevatedButton.icon(
            onPressed: () => _showAccountFormDialog(context, provider),
            icon: Icon(Icons.add_rounded, size: 16.sp),
            label: Text(
              'Add Account',
              style:
                  GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600),
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
    );
  }

  void _showAdjustmentDialog(
    BuildContext context,
    FundAccountProvider provider,
    FundAccountEntity account,
  ) {
    final formKey = GlobalKey<FormState>();
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    var increase = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: finDialogShape,
          title: finDialogTitle('Balance Adjustment', icon: Icons.tune_rounded, iconColor: FinDT.warning),
          content: SizedBox(
            width: 420.w,
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
                        color: FinDT.bgPage,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(color: FinDT.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded, size: 18.sp, color: FinDT.warning),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Text(
                              'Use only when counted cash/bank does not match the app. Always explain why.\n'
                              'Current balance: ${account.currentBalance.toStringAsFixed(2)} ${account.currency}',
                              style: GoogleFonts.inter(
                                fontSize: 12.sp,
                                color: FinDT.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 14.h),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_upward_rounded, size: 14.sp, color: increase ? FinDT.success : FinDT.textSecondary),
                                SizedBox(width: 4.w),
                                Text('Increase (+)', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: increase ? FinDT.success : FinDT.textSecondary)),
                              ],
                            ),
                            selected: increase,
                            onSelected: (_) => setLocal(() => increase = true),
                            selectedColor: FinDT.success.withValues(alpha: 0.15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: ChoiceChip(
                            label: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_downward_rounded, size: 14.sp, color: !increase ? FinDT.danger : FinDT.textSecondary),
                                SizedBox(width: 4.w),
                                Text('Decrease (−)', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: !increase ? FinDT.danger : FinDT.textSecondary)),
                              ],
                            ),
                            selected: !increase,
                            onSelected: (_) => setLocal(() => increase = false),
                            selectedColor: FinDT.danger.withValues(alpha: 0.15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                          ),
                        ),
                      ],
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
                        label: 'Adjustment Amount *',
                        hint: '0.00',
                        prefixIcon: Icons.attach_money_rounded,
                        suffixText: account.currency,
                      ),
                      style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        if (n == null || n <= 0) return 'Enter a positive amount';
                        return null;
                      },
                    ),
                    SizedBox(height: 14.h),
                    TextFormField(
                      controller: reasonCtrl,
                      maxLines: 2,
                      decoration: finDialogInputDecoration(
                        label: 'Reason * (required)',
                        hint: 'e.g. Cash count shortfall after day close',
                        prefixIcon: Icons.edit_note_rounded,
                      ),
                      style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Reason required' : null,
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
                final amount = double.parse(amountCtrl.text);
                final reason = reasonCtrl.text.trim();
                final isIncrease = increase;
                Navigator.pop(ctx);
                try {
                  await provider.recordMovement(
                    fundAccountId: account.id,
                    type: FundTransactionType.adjustment,
                    amountMajor: amount,
                    currency: account.currency,
                    description:
                        'ADJUSTMENT (${isIncrease ? '+' : '−'}): $reason',
                    performedBy: user?.actorLabel ?? 'Unknown',
                    performedByUserId: user?.id ?? '',
                    bucket: FundBucket.total,
                    credit: isIncrease,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isIncrease
                              ? 'Balance increased by $amount'
                              : 'Balance decreased by $amount',
                        ),
                        backgroundColor: FinDT.success,
                      ),
                    );
                  }
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
              label: 'Post Adjustment',
              backgroundColor: FinDT.warning,
            ),
          ],
        ),
      ),
    );
  }

  void _showTransferDialog(
    BuildContext context,
    FundAccountProvider provider,
  ) {
    final formKey = GlobalKey<FormState>();
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? fromId = provider.selectedAccountId;
    String? toId;
    final accounts = provider.activeAccounts;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: finDialogShape,
          title: finDialogTitle('Transfer Between Accounts', icon: Icons.swap_horiz_rounded),
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
                      initialValue: fromId,
                      decoration: finDialogInputDecoration(
                        label: 'Source Account (From) *',
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
                      onChanged: (v) => setLocal(() => fromId = v),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    SizedBox(height: 14.h),
                    DropdownButtonFormField<String>(
                      initialValue: toId,
                      decoration: finDialogInputDecoration(
                        label: 'Destination Account (To) *',
                        prefixIcon: Icons.account_balance_outlined,
                      ),
                      style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
                      items: accounts
                          .where((a) => a.id != fromId)
                          .map(
                            (a) => DropdownMenuItem(
                              value: a.id,
                              child: Text('${a.name} (${a.currentBalance.toStringAsFixed(0)} ${a.currency})'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setLocal(() => toId = v),
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
                        label: 'Transfer Amount *',
                        hint: '0.00',
                        prefixIcon: Icons.attach_money_rounded,
                        suffixText: 'SAR',
                      ),
                      style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        if (n == null || n <= 0) return 'Invalid amount';
                        return null;
                      },
                    ),
                    SizedBox(height: 14.h),
                    TextFormField(
                      controller: descCtrl,
                      decoration: finDialogInputDecoration(
                        label: 'Purpose / Description *',
                        hint: 'e.g. Seed petty cash fund',
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
                final from = accounts.firstWhere((a) => a.id == fromId);
                final amount = double.parse(amountCtrl.text);
                Navigator.pop(ctx);
                try {
                  await provider.transfer(
                    fromAccountId: fromId!,
                    toAccountId: toId!,
                    amountMajor: amount,
                    currency: from.currency,
                    description: descCtrl.text.trim(),
                    performedBy: user?.actorLabel ?? 'Unknown',
                    performedByUserId: user?.id ?? '',
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Transfer completed (both sides posted)'),
                        backgroundColor: FinDT.success,
                      ),
                    );
                  }
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
              label: 'Transfer Funds',
              backgroundColor: FinDT.brand,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsColumn(
    BuildContext context,
    FundAccountProvider provider,
  ) {
    final selected = provider.selectedAccount;
    if (selected == null) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 48.h),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: FinDT.textSecondary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.space_dashboard_outlined,
                size: 32.sp,
                color: FinDT.textSecondary,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'No Account Selected',
              style: GoogleFonts.inter(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: FinDT.textPrimary,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'Select an account from the left to view live balances and transaction ledgers.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: FinDT.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    final formatter = NumberFormat('#,##0.00', 'en_US');

    // Filter transactions
    final query = _txSearchController.text.toLowerCase().trim();
    final filteredTxs = provider.transactions.where((tx) {
      final isIn = tx.balanceAfter >= tx.balanceBefore;
      final isAdjust = tx.type == FundTransactionType.adjustment;

      if (_txFilter == 'INFLOW' && !isIn) return false;
      if (_txFilter == 'OUTFLOW' && (isIn || isAdjust)) return false;
      if (_txFilter == 'ADJUST' && !isAdjust) return false;

      if (query.isNotEmpty) {
        return tx.description.toLowerCase().contains(query) ||
            tx.performedBy.toLowerCase().contains(query);
      }
      return true;
    }).toList();

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
          // ── Header Card ─────────────────────────────────────
          Padding(
            padding: EdgeInsets.all(18.w),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: FinDT.brand.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Icon(
                          Icons.account_balance_wallet_rounded,
                          color: FinDT.brand,
                          size: 20.sp,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    selected.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w700,
                                      color: FinDT.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                  decoration: BoxDecoration(
                                    color: FinDT.bgPage,
                                    borderRadius: BorderRadius.circular(6.r),
                                    border: Border.all(color: FinDT.border),
                                  ),
                                  child: Text(
                                    selected.code,
                                    style: GoogleFonts.inter(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w600,
                                      color: FinDT.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 3.h),
                            Row(
                              children: [
                                Text(
                                  selected.typeDisplayName,
                                  style: GoogleFonts.inter(
                                    fontSize: 11.sp,
                                    color: FinDT.brand,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (selected.assignedTo != null && selected.assignedTo!.isNotEmpty) ...[
                                  Text(
                                    ' • Assigned to ${selected.assignedTo}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.sp,
                                      color: FinDT.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildDetailsActions(context, provider, selected),
              ],
            ),
          ),
          Divider(height: 1, color: FinDT.borderLight),

          // ── Balance Hero Card ─────────────────────────────────
          Container(
            margin: EdgeInsets.all(18.w),
            padding: EdgeInsets.all(18.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  FinDT.brand.withValues(alpha: 0.08),
                  FinDT.brand.withValues(alpha: 0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: FinDT.brand.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CURRENT AVAILABLE BALANCE',
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: FinDT.brand,
                  ),
                ),
                SizedBox(height: 6.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      formatter.format(selected.currentBalance),
                      style: GoogleFonts.inter(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w900,
                        color: selected.currentBalance >= 0
                            ? FinDT.textPrimary
                            : FinDT.danger,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      selected.currency,
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: FinDT.textSecondary,
                      ),
                    ),
                  ],
                ),

                // If Petty Cash, show dual cash/stc sub-cards
                if (selected.isPettyCash) ...[
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(6.w),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Icon(Icons.payments_outlined, size: 16.sp, color: const Color(0xFF16A34A)),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Physical Cash', style: GoogleFonts.inter(fontSize: 10.sp, color: FinDT.textSecondary)),
                                    SizedBox(height: 1.h),
                                    Text(
                                      '${formatter.format(selected.cashBalance)} SAR',
                                      style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: FinDT.textPrimary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(6.w),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Icon(Icons.phone_android_outlined, size: 16.sp, color: const Color(0xFF7C3AED)),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('STC Pay Float', style: GoogleFonts.inter(fontSize: 10.sp, color: FinDT.textSecondary)),
                                    SizedBox(height: 1.h),
                                    Text(
                                      '${formatter.format(selected.stcPayBalance)} SAR',
                                      style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: FinDT.textPrimary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ── Quick Actions Bar ─────────────────────────────────
          Builder(builder: (context) {
            final user = context.read<AuthProvider>().user;
            final policy = context.read<FinanceProvider>().policy;
            final canMove = FinancePermissionService.canMoveFunds(
              user: user,
              account: selected,
              policy: policy,
            );
            if (!canMove) return const SizedBox.shrink();

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 18.w),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTransactionActionBtn(
                      context: context,
                      provider: provider,
                      account: selected,
                      isDeposit: true,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: _buildTransactionActionBtn(
                      context: context,
                      provider: provider,
                      account: selected,
                      isDeposit: false,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  OutlinedButton.icon(
                    onPressed: () => _showAdjustmentDialog(context, provider, selected),
                    icon: Icon(Icons.tune_rounded, size: 15.sp),
                    label: Text('Adjust', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FinDT.warning,
                      side: BorderSide(color: FinDT.warning.withValues(alpha: 0.5)),
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                    ),
                  ),
                ],
              ),
            );
          }),
          SizedBox(height: 16.h),
          Divider(height: 1, color: FinDT.borderLight),

          // ── Transaction Timeline Header & Filter Tabs ──────────
          Padding(
            padding: EdgeInsets.all(18.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Transaction History',
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: FinDT.textPrimary,
                      ),
                    ),
                    Text(
                      '${provider.transactions.length} total entries',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        color: FinDT.textSecondary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),

                // Search & Filter Row
                Row(
                  children: [
                    // Search box
                    Expanded(
                      flex: 4,
                      child: SizedBox(
                        height: 38.h,
                        child: TextField(
                          controller: _txSearchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Search transactions...',
                            hintStyle: GoogleFonts.inter(fontSize: 11.sp, color: FinDT.textMuted),
                            prefixIcon: Icon(Icons.search, size: 16.sp, color: FinDT.textSecondary),
                            filled: true,
                            fillColor: FinDT.bgPage,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.r),
                              borderSide: const BorderSide(color: FinDT.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.r),
                              borderSide: const BorderSide(color: FinDT.border),
                            ),
                          ),
                          style: GoogleFonts.inter(fontSize: 11.sp, color: FinDT.textPrimary),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),

                    // Filter tabs
                    _buildTxFilterTab('ALL', 'All'),
                    SizedBox(width: 4.w),
                    _buildTxFilterTab('INFLOW', 'Inflow (+)'),
                    SizedBox(width: 4.w),
                    _buildTxFilterTab('OUTFLOW', 'Outflow (-)'),
                    SizedBox(width: 4.w),
                    _buildTxFilterTab('ADJUST', 'Adjust'),
                  ],
                ),
              ],
            ),
          ),

          // ── Transaction Timeline List ──────────────────────────
          if (provider.isTransactionsLoading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 40.h),
              child: const Center(
                child: CircularProgressIndicator(color: FinDT.brand),
              ),
            )
          else if (filteredTxs.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 20.w),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 36.sp, color: FinDT.textMuted),
                    SizedBox(height: 8.h),
                    Text(
                      'No matching transactions found',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: FinDT.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredTxs.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: FinDT.borderLight),
              itemBuilder: (context, index) {
                final tx = filteredTxs[index];
                final isIn = tx.balanceAfter >= tx.balanceBefore;
                final isAdjust = tx.type == FundTransactionType.adjustment;
                final color = isAdjust
                    ? FinDT.warning
                    : (isIn ? const Color(0xFF16A34A) : const Color(0xFFDC2626));

                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Icon(
                          isAdjust
                              ? Icons.tune_rounded
                              : (isIn
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded),
                          color: color,
                          size: 16.sp,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tx.description,
                              style: GoogleFonts.inter(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: FinDT.textPrimary,
                              ),
                            ),
                            SizedBox(height: 3.h),
                            Row(
                              children: [
                                Text(
                                  DateFormat('dd MMM yyyy, hh:mm a').format(tx.date),
                                  style: GoogleFonts.inter(
                                    fontSize: 10.sp,
                                    color: FinDT.textSecondary,
                                  ),
                                ),
                                Text(
                                  ' • By ${tx.performedBy}',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.sp,
                                    color: FinDT.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          CurrencyDisplay(
                            amount: tx.amount,
                            currency: tx.currency,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            'Bal: ${formatter.format(tx.balanceAfter)} SAR',
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
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTxFilterTab(String key, String label) {
    final isSelected = _txFilter == key;
    return InkWell(
      onTap: () => setState(() => _txFilter = key),
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: isSelected ? FinDT.brand : FinDT.bgPage,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: isSelected ? FinDT.brand : FinDT.border),
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

  Widget _buildDetailsActions(
    BuildContext context,
    FundAccountProvider provider,
    FundAccountEntity selected,
  ) {
    final user = context.read<AuthProvider>().user;
    final policy = context.read<FinanceProvider>().policy;
    final canManageAccounts = FinancePermissionService.canManageAccounts(user: user, policy: policy);
    if (!canManageAccounts) return const SizedBox.shrink();

    return Row(
      children: [
        IconButton(
          onPressed: () =>
              _showAccountFormDialog(context, provider, account: selected),
          icon: Icon(
            Icons.edit_outlined,
            size: 18.sp,
            color: FinDT.textSecondary,
          ),
          tooltip: 'Edit Account',
        ),
        IconButton(
          onPressed: () => _confirmDeleteAccount(context, provider, selected),
          icon: Icon(
            selected.currentBalanceMinor > 0
                ? Icons.delete_outline
                : (provider.transactions.isNotEmpty
                    ? Icons.archive_outlined
                    : Icons.delete_outline),
            size: 18.sp,
            color: selected.currentBalanceMinor > 0
                ? FinDT.textMuted
                : FinDT.danger,
          ),
          tooltip: selected.currentBalanceMinor > 0
              ? 'Cannot close account with active balance'
              : (provider.transactions.isNotEmpty
                  ? 'Deactivate Account'
                  : 'Delete Account'),
        ),
      ],
    );
  }

  Widget _buildTransactionActionBtn({
    required BuildContext context,
    required FundAccountProvider provider,
    required FundAccountEntity account,
    required bool isDeposit,
  }) {
    final color = isDeposit ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    return OutlinedButton.icon(
      onPressed: () =>
          _showTransactionDialog(context, provider, account, isDeposit),
      icon: Icon(
        isDeposit ? Icons.add_rounded : Icons.remove_rounded,
        size: 15.sp,
      ),
      label: Text(isDeposit ? 'Deposit Cash' : 'Withdraw Cash'),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
        padding: EdgeInsets.symmetric(vertical: 12.h),
        textStyle: GoogleFonts.inter(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ─── Dialogs & Actions ──────────────────────────────────────

  InputDecoration _dialogInputDecoration({
    required String label,
    String? hint,
    IconData? prefixIcon,
    String? suffixText,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textSecondary),
      hintText: hint,
      hintStyle: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textMuted),
      suffixText: suffixText,
      suffixStyle: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: FinDT.textPrimary),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 18.sp, color: FinDT.brand)
          : null,
      filled: true,
      fillColor: FinDT.bgPage,
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
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
        borderSide: const BorderSide(color: FinDT.brand, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: const BorderSide(color: FinDT.danger),
      ),
    );
  }

  void _showEmployeeSearchDialog(
    BuildContext context,
    EmployeeProvider empProv,
    ValueChanged<EmployeeEntity> onSelect,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            final filtered = empProv.employees.where((e) {
              final q = searchQuery.toLowerCase();
              return e.fullName.toLowerCase().contains(q) ||
                  e.position.toLowerCase().contains(q);
            }).toList();

            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: finDialogShape,
              title: finDialogTitle('Select Coordinator', icon: Icons.person_search_outlined),
              content: SizedBox(
                width: 400.w,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      onChanged: (v) => setStateDialog(() => searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Search employee name or position...',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 12.sp,
                          color: FinDT.textSecondary,
                        ),
                        prefixIcon: Icon(Icons.search, size: 18.sp, color: FinDT.brand),
                        filled: true,
                        fillColor: FinDT.bgPage,
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
                          borderSide: const BorderSide(color: FinDT.brand),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: 300.h),
                      child: filtered.isEmpty
                          ? Padding(
                              padding: EdgeInsets.all(24.w),
                              child: Text(
                                'No employees found',
                                style: GoogleFonts.inter(
                                  fontSize: 12.sp,
                                  color: FinDT.textSecondary,
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(
                                height: 1,
                                color: FinDT.borderLight,
                              ),
                              itemBuilder: (context, index) {
                                final emp = filtered[index];
                                return ListTile(
                                  onTap: () {
                                    onSelect(emp);
                                    Navigator.pop(ctx);
                                  },
                                  leading: CircleAvatar(
                                    backgroundColor: FinDT.brand.withValues(alpha: 0.1),
                                    child: Text(
                                      emp.fullName.isNotEmpty
                                          ? emp.fullName[0].toUpperCase()
                                          : 'E',
                                      style: GoogleFonts.inter(
                                        color: FinDT.brand,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12.sp,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    emp.fullName,
                                    style: GoogleFonts.inter(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w600,
                                      color: FinDT.textPrimary,
                                    ),
                                  ),
                                  subtitle: Text(
                                    emp.position.isNotEmpty ? emp.position : 'Employee',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.sp,
                                      color: FinDT.textSecondary,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(color: FinDT.textSecondary),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  FundAccountType _mapTypeToEnum(FundAccountTypeEntity entity) {
    switch (entity.id) {
      case 'pettyCash':
      case 'petty_cash':
        return FundAccountType.pettyCash;
      case 'bank':
        return FundAccountType.bank;
      case 'stcPay':
      case 'stc_pay':
        return FundAccountType.stcPay;
      default:
        return FundAccountType.other;
    }
  }

  void _showAccountFormDialog(
    BuildContext context,
    FundAccountProvider provider, {
    FundAccountEntity? account,
  }) {
    final empProv = context.read<EmployeeProvider>();
    final isEditing = account != null;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: account?.name);

    final availableTypes = provider.accountTypes;
    FundAccountTypeEntity selectedType = availableTypes.firstWhere(
      (t) =>
          (account?.accountTypeId != null && t.id == account!.accountTypeId) ||
          t.name.toLowerCase() == account?.typeDisplayName.toLowerCase(),
      orElse: () => availableTypes.firstWhere(
        (t) => t.id == 'pettyCash',
        orElse: () => availableTypes.isNotEmpty
            ? availableTypes.first
            : FundAccountTypeEntity.defaultTypes[1],
      ),
    );

    final initialCode = isEditing
        ? (account.code.isNotEmpty ? account.code : provider.generateUniqueCode(selectedType))
        : provider.generateUniqueCode(selectedType);
    final codeCtrl = TextEditingController(text: initialCode);
    String? assignedName = account?.assignedTo;
    String currency = account?.currency ?? 'SAR';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: finDialogShape,
          title: finDialogTitle(
            isEditing ? 'Edit Fund Account' : 'New Fund Account',
            icon: Icons.account_balance_wallet_outlined,
          ),
          content: SizedBox(
            width: 440.w,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 8.h),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: _dialogInputDecoration(
                        label: 'Account Name *',
                        hint: 'e.g. Main Cash Drawer',
                        prefixIcon: Icons.account_balance_wallet_outlined,
                      ),
                      style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    SizedBox(height: 14.h),

                    // Account Type Dropdown
                    DropdownButtonFormField<String>(
                      key: ValueKey(selectedType.id),
                      initialValue: provider.accountTypes.any((t) => t.id == selectedType.id)
                          ? selectedType.id
                          : (provider.accountTypes.isNotEmpty ? provider.accountTypes.first.id : null),
                      decoration: _dialogInputDecoration(
                        label: 'Account Type *',
                        prefixIcon: Icons.category_outlined,
                      ),
                      style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
                      items: provider.accountTypes
                          .map(
                            (t) => DropdownMenuItem(
                              value: t.id,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(t.name),
                                  SizedBox(width: 6.w),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                                    decoration: BoxDecoration(
                                      color: FinDT.brand.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(4.r),
                                    ),
                                    child: Text(
                                      t.codePrefix,
                                      style: GoogleFonts.inter(
                                        fontSize: 9.sp,
                                        fontWeight: FontWeight.w700,
                                        color: FinDT.brand,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        final found = provider.accountTypes.firstWhere(
                          (t) => t.id == val,
                          orElse: () => selectedType,
                        );
                        setStateDialog(() {
                          selectedType = found;
                          if (!isEditing) {
                            codeCtrl.text = provider.generateUniqueCode(found);
                          }
                        });
                      },
                    ),
                    SizedBox(height: 14.h),
                    TextFormField(
                      controller: codeCtrl,
                      readOnly: true,
                      decoration: _dialogInputDecoration(
                        label: 'Account Code',
                        hint: 'Auto-generated',
                        prefixIcon: Icons.qr_code_rounded,
                      ).copyWith(
                        fillColor: FinDT.bgPage,
                        suffixIcon: Container(
                          margin: EdgeInsets.only(right: 8.w),
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: FinDT.brand.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome_rounded, size: 12.sp, color: FinDT.brand),
                              SizedBox(width: 4.w),
                              Text(
                                'Auto',
                                style: GoogleFonts.inter(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w600,
                                  color: FinDT.brand,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: FinDT.textPrimary,
                        letterSpacing: 0.5,
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    SizedBox(height: 14.h),
                    DropdownButtonFormField<String>(
                      initialValue: currency,
                      decoration: _dialogInputDecoration(
                        label: 'Currency',
                        prefixIcon: Icons.payments_outlined,
                      ),
                      style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
                      items: ['SAR', 'BHD', 'AED', 'USD']
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setStateDialog(() => currency = v ?? 'SAR'),
                    ),
                    SizedBox(height: 14.h),
                    // Searchable Assigned Coordinator Field
                    InkWell(
                      onTap: () => _showEmployeeSearchDialog(context, empProv, (selected) {
                        setStateDialog(() {
                          assignedName = selected.fullName;
                        });
                      }),
                      borderRadius: BorderRadius.circular(10.r),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                        decoration: BoxDecoration(
                          color: FinDT.bgPage,
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(color: FinDT.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_search_outlined,
                              size: 18.sp,
                              color: FinDT.brand,
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Text(
                                (assignedName != null && assignedName!.isNotEmpty)
                                    ? assignedName!
                                    : 'Search & Select Coordinator...',
                                style: GoogleFonts.inter(
                                  fontSize: 12.sp,
                                  color: (assignedName != null && assignedName!.isNotEmpty)
                                      ? FinDT.textPrimary
                                      : FinDT.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (assignedName != null && assignedName!.isNotEmpty)
                              InkWell(
                                onTap: () => setStateDialog(() => assignedName = null),
                                child: Icon(Icons.close, size: 16.sp, color: FinDT.textSecondary),
                              )
                            else
                              Icon(
                                Icons.arrow_drop_down_rounded,
                                size: 20.sp,
                                color: FinDT.textSecondary,
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Account creation guard notice
                    Builder(
                      builder: (_) {
                        bool hasConflict = false;
                        if (assignedName != null && assignedName!.isNotEmpty) {
                          if (selectedType.id == 'stcPay') {
                            hasConflict = provider.accounts.any((a) =>
                                a.assignedTo == assignedName &&
                                a.isPettyCash &&
                                a.id != account?.id);
                          } else if (selectedType.id == 'pettyCash') {
                            hasConflict = provider.accounts.any((a) =>
                                a.assignedTo == assignedName &&
                                a.isStcPay &&
                                a.id != account?.id);
                          }
                        }

                        if (!hasConflict) return const SizedBox.shrink();

                        return Padding(
                          padding: EdgeInsets.only(top: 14.h),
                          child: Container(
                            padding: EdgeInsets.all(12.w),
                            decoration: BoxDecoration(
                              color: FinDT.danger.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(color: FinDT.danger.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline_rounded, size: 18.sp, color: FinDT.danger),
                                SizedBox(width: 10.w),
                                Expanded(
                                  child: Text(
                                    selectedType.id == 'stcPay'
                                        ? '$assignedName already has a Petty Cash account. STC Pay balances for coordinators should be managed directly inside Petty Cash.'
                                        : '$assignedName already has a standalone STC Pay account.',
                                    style: GoogleFonts.inter(fontSize: 11.sp, color: FinDT.danger, height: 1.3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: FinDT.textSecondary),
              ),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;

                // Check conflict guard
                bool hasConflict = false;
                if (assignedName != null && assignedName!.isNotEmpty) {
                  if (selectedType.id == 'stcPay') {
                    hasConflict = provider.accounts.any((a) =>
                        a.assignedTo == assignedName &&
                        a.isPettyCash &&
                        a.id != account?.id);
                  }
                }
                if (hasConflict) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Cannot create standalone STC Pay account for a coordinator who already has Petty Cash.',
                        style: GoogleFonts.inter(color: Colors.white),
                      ),
                      backgroundColor: FinDT.danger,
                    ),
                  );
                  return;
                }

                final entityType = _mapTypeToEnum(selectedType);
                final acc = FundAccountEntity(
                  id: isEditing ? account.id : const Uuid().v4(),
                  name: nameCtrl.text.trim(),
                  code: codeCtrl.text.trim(),
                  type: entityType,
                  accountTypeId: selectedType.id,
                  accountTypeName: selectedType.name,
                  currency: currency,
                  assignedTo: assignedName,
                  currentBalanceMinor: isEditing ? account.currentBalanceMinor : 0,
                  cashBalanceMinor: isEditing ? account.cashBalanceMinor : 0,
                  stcPayBalanceMinor: isEditing ? account.stcPayBalanceMinor : 0,
                  createdAt: isEditing ? account.createdAt : DateTime.now(),
                );

                if (isEditing) {
                  provider.updateAccount(acc);
                } else {
                  provider.insertAccount(acc);
                }
                Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(
                backgroundColor: FinDT.brand,
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              child: Text(
                isEditing ? 'Save Account' : 'Create Account',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }



  void _showTransactionDialog(
    BuildContext context,
    FundAccountProvider provider,
    FundAccountEntity account,
    bool isDeposit,
  ) {
    final formKey = GlobalKey<FormState>();
    final isPettyCash = account.isPettyCash;

    final amountCtrl = TextEditingController();
    final cashAmountCtrl = TextEditingController();
    final stcAmountCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: finDialogShape,
        title: finDialogTitle(
          isDeposit ? 'Deposit Funds' : 'Withdraw Funds',
          icon: isDeposit ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
          iconColor: isDeposit ? FinDT.success : FinDT.danger,
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
                  width: double.infinity,
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: FinDT.bgPage,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: FinDT.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_wallet_outlined, size: 16.sp, color: FinDT.brand),
                      SizedBox(width: 8.w),
                      Text(
                        'Account: ',
                        style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textSecondary),
                      ),
                      Text(
                        '${account.name} (${account.code})',
                        style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: FinDT.textPrimary),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                if (isPettyCash) ...[
                  // Dual Bucket deposit/withdrawal for Petty Cash
                  Text(
                    'Specify breakdown for ${isDeposit ? "deposit" : "withdrawal"}:',
                    style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: FinDT.textPrimary),
                  ),
                  SizedBox(height: 10.h),
                  TextFormField(
                    controller: cashAmountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    decoration: _dialogInputDecoration(
                      label: 'Physical Cash Amount',
                      hint: '0.00',
                      prefixIcon: Icons.payments_outlined,
                      suffixText: 'SAR',
                    ),
                    style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
                    validator: (v) {
                      final cash = double.tryParse(v ?? '') ?? 0.0;
                      final stc = double.tryParse(stcAmountCtrl.text) ?? 0.0;
                      if (cash == 0 && stc == 0) return 'Enter cash or STC Pay amount';
                      if (!isDeposit && cash > account.cashBalance) {
                        return 'Exceeds physical cash balance (${account.cashBalance.toStringAsFixed(2)})';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 12.h),
                  TextFormField(
                    controller: stcAmountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    decoration: _dialogInputDecoration(
                      label: 'STC Pay Transfer Amount',
                      hint: '0.00',
                      prefixIcon: Icons.phone_android_outlined,
                      suffixText: 'SAR',
                    ),
                    style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
                    validator: (v) {
                      final cash = double.tryParse(cashAmountCtrl.text) ?? 0.0;
                      final stc = double.tryParse(v ?? '') ?? 0.0;
                      if (cash == 0 && stc == 0) return 'Enter cash or STC Pay amount';
                      if (!isDeposit && stc > account.stcPayBalance) {
                        return 'Exceeds STC Pay balance (${account.stcPayBalance.toStringAsFixed(2)})';
                      }
                      return null;
                    },
                  ),
                ] else ...[
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    decoration: _dialogInputDecoration(
                      label: 'Amount *',
                      hint: '0.00',
                      prefixIcon: Icons.payments_outlined,
                      suffixText: 'SAR',
                    ),
                    style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      final val = double.tryParse(v);
                      if (val == null || val <= 0) return 'Invalid amount';
                      if (!isDeposit && val > account.currentBalance) {
                        return 'Insufficient balance';
                      }
                      return null;
                    },
                  ),
                ],
                SizedBox(height: 14.h),
                TextFormField(
                  controller: descCtrl,
                  decoration: _dialogInputDecoration(
                    label: 'Description / Purpose *',
                    hint: 'e.g., Seed petty cash fund',
                    prefixIcon: Icons.description_outlined,
                  ),
                  style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: FinDT.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final cashAmt = double.tryParse(cashAmountCtrl.text) ?? 0.0;
              final stcAmt = double.tryParse(stcAmountCtrl.text) ?? 0.0;
              final totalAmt = isPettyCash ? (cashAmt + stcAmt) : double.parse(amountCtrl.text);

              final auth = context.read<AuthProvider>().user;
              final actorName = auth?.actorLabel ?? 'Unknown';
              final actorId = auth?.id ?? '';

              Navigator.pop(ctx);
              provider.recordMovement(
                fundAccountId: account.id,
                type: isDeposit
                    ? FundTransactionType.deposit
                    : FundTransactionType.withdrawal,
                amountMajor: totalAmt,
                currency: account.currency,
                description: isPettyCash
                    ? '${descCtrl.text} [Cash: $cashAmt, STC: $stcAmt]'
                    : descCtrl.text,
                performedBy: actorName,
                performedByUserId: actorId,
                bucket: isPettyCash ? FundBucket.total : FundBucket.total,
                cashDelta:
                    isPettyCash ? (isDeposit ? cashAmt : -cashAmt) : null,
                stcPayDelta:
                    isPettyCash ? (isDeposit ? stcAmt : -stcAmt) : null,
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: isDeposit ? FinDT.success : FinDT.danger,
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            child: Text(
              isDeposit ? 'Deposit Funds' : 'Withdraw Funds',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(
    BuildContext context,
    FundAccountProvider provider,
    FundAccountEntity account,
  ) {
    if (account.currentBalanceMinor > 0) {
      showFinConfirmationDialog(
        context: context,
        title: 'Cannot Close Active Account',
        icon: Icons.account_balance_wallet_outlined,
        confirmColor: FinDT.brand,
        message:
            'Account "${account.name}" holds an active balance of ${account.currentBalance.toStringAsFixed(2)} ${account.currency}.\n\n'
            'Financial Safety Rule: You cannot close or delete an account with active funds. Please transfer or withdraw all funds to reach 0.00 ${account.currency} first.',
        confirmLabel: 'Understood',
      );
      return;
    }

    final hasHistory = provider.transactions.isNotEmpty;
    showFinConfirmationDialog(
      context: context,
      title: hasHistory ? 'Deactivate Account?' : 'Delete Unused Account?',
      message: hasHistory
          ? 'This will deactivate "${account.name}".\n\nAll historical ledger entries, transaction receipts, and accounting audit logs are permanently locked and preserved. The account will simply be hidden from new transaction forms.'
          : 'This unused account has zero transactions and will be deleted.',
      confirmLabel: hasHistory ? 'Deactivate Account' : 'Delete Account',
      confirmColor: FinDT.danger,
      icon: hasHistory ? Icons.archive_outlined : Icons.delete_outline_rounded,
    ).then((ok) async {
      if (ok == true) {
        await provider.deleteAccount(account.id);
        if (context.mounted && provider.error == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                hasHistory
                    ? 'Account "${account.name}" deactivated. Historical ledger remains safe.'
                    : 'Account "${account.name}" deleted.',
              ),
              backgroundColor: FinDT.brand,
            ),
          );
        }
      }
    });
  }
}

