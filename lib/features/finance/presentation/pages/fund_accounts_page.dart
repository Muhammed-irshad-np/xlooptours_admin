import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:xloop_invoice/features/finance/domain/entities/fund_transaction_entity.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/fund_account_provider.dart';
import '../widgets/fund_account_card.dart';
import '../widgets/currency_display.dart';
import '../../domain/entities/fund_account_entity.dart';
import '../../../../features/employee/presentation/providers/employee_provider.dart';
import '../../../../features/employee/domain/entities/employee_entity.dart';
import 'finance_dashboard_page.dart';

/// Screen for managing virtual fund accounts and viewing transaction history.
class FundAccountsPage extends StatefulWidget {
  const FundAccountsPage({super.key});

  @override
  State<FundAccountsPage> createState() => _FundAccountsPageState();
}

class _FundAccountsPageState extends State<FundAccountsPage> {
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
                      'Virtual Accounts',
                      style: GoogleFonts.inter(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: FinDT.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Manage bank accounts, petty cash drawers, and payment ledgers',
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
            SizedBox(height: 20.h),

            // 2-Column Content Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Accounts List
                Expanded(flex: 4, child: _buildAccountsColumn(context, provider)),
                SizedBox(width: 24.w),

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

  Widget _buildAccountsColumn(
    BuildContext context,
    FundAccountProvider provider,
  ) {
    final active = provider.activeAccounts;
    if (active.isEmpty) {
      return _buildEmptyAccounts(context, provider);
    }

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16.w,
        mainAxisSpacing: 16.h,
        childAspectRatio: 1.15,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: active.length,
      itemBuilder: (context, index) {
        final account = active[index];
        final isSelected = provider.selectedAccountId == account.id;
        return FundAccountCard(
          account: account,
          isSelected: isSelected,
          onTap: () => provider.selectAccount(account.id),
        );
      },
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          onPressed: () => _showTransferDialog(context, provider),
          icon: Icon(Icons.swap_horiz_rounded, size: 16.sp),
          label: Text(
            'Transfer',
            style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600),
          ),
        ),
        SizedBox(width: 8.w),
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
          title: const Text('Balance adjustment'),
          content: SizedBox(
            width: 420.w,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Use only when counted cash/bank does not match the app. '
                    'Always explain why. Current balance: '
                    '${account.currentBalance.toStringAsFixed(2)} ${account.currency}',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: FinDT.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 14.h),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Increase (+)'),
                          selected: increase,
                          onSelected: (_) => setLocal(() => increase = true),
                          selectedColor: FinDT.success.withValues(alpha: 0.2),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Decrease (−)'),
                          selected: !increase,
                          onSelected: (_) => setLocal(() => increase = false),
                          selectedColor: FinDT.danger.withValues(alpha: 0.15),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'Enter a positive amount';
                      return null;
                    },
                  ),
                  SizedBox(height: 12.h),
                  TextFormField(
                    controller: reasonCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Reason * (required)',
                      hintText: 'e.g. Cash count shortfall after day close',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Reason required' : null,
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
              style: FilledButton.styleFrom(backgroundColor: FinDT.warning),
              child: const Text('Post adjustment'),
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
          title: const Text('Transfer between accounts'),
          content: SizedBox(
            width: 420.w,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: fromId,
                    decoration: const InputDecoration(labelText: 'From'),
                    items: accounts
                        .map(
                          (a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(a.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setLocal(() => fromId = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  SizedBox(height: 12.h),
                  DropdownButtonFormField<String>(
                    value: toId,
                    decoration: const InputDecoration(labelText: 'To'),
                    items: accounts
                        .where((a) => a.id != fromId)
                        .map(
                          (a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(a.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setLocal(() => toId = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  SizedBox(height: 12.h),
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount'),
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'Invalid amount';
                      return null;
                    },
                  ),
                  SizedBox(height: 12.h),
                  TextFormField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Purpose *'),
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
              child: const Text('Transfer'),
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
              'Select an account from the left to view transaction history and balances.',
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
          // Header of details card
          Padding(
            padding: EdgeInsets.all(20.w),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected.name,
                        style: GoogleFonts.inter(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: FinDT.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '${selected.code} • ${selected.type.displayName}',
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          color: FinDT.textSecondary,
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

          // Deposit / Withdrawal / Adjust
          Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildTransactionActionBtn(
                        context: context,
                        provider: provider,
                        account: selected,
                        isDeposit: true,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _buildTransactionActionBtn(
                        context: context,
                        provider: provider,
                        account: selected,
                        isDeposit: false,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showAdjustmentDialog(
                      context,
                      provider,
                      selected,
                    ),
                    icon: Icon(Icons.tune_rounded, size: 16.sp),
                    label: Text(
                      'Adjustment (fix balance with reason)',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FinDT.warning,
                      side: BorderSide(color: FinDT.warning.withValues(alpha: 0.5)),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: FinDT.borderLight),

          // Transaction Timeline List
          Padding(
            padding: EdgeInsets.all(20.w),
            child: Text(
              'Transaction History',
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: FinDT.textPrimary,
              ),
            ),
          ),
          if (provider.isTransactionsLoading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 40.h),
              child: const Center(
                child: CircularProgressIndicator(color: FinDT.brand),
              ),
            )
          else if (provider.transactions.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 40.h),
              child: Center(
                child: Text(
                  'No transactions recorded yet',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: FinDT.textSecondary,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: provider.transactions.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: FinDT.borderLight),
              itemBuilder: (context, index) {
                final tx = provider.transactions[index];
                final isIn = tx.balanceAfter >= tx.balanceBefore;
                final isAdjust =
                    tx.type == FundTransactionType.adjustment;
                final color = isAdjust
                    ? FinDT.warning
                    : (isIn ? FinDT.success : FinDT.danger);
                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 14.h,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isAdjust
                              ? Icons.tune_rounded
                              : (isIn
                                  ? Icons.add_circle_outline
                                  : Icons.remove_circle_outline),
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
                            SizedBox(height: 2.h),
                            Text(
                              '${DateFormat('dd MMM yy, hh:mm a').format(tx.date)} • By ${tx.performedBy}',
                              style: GoogleFonts.inter(
                                fontSize: 10.sp,
                                color: FinDT.textSecondary,
                              ),
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
                            'Bal: ${tx.balanceAfter.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                              fontSize: 9.sp,
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

  Widget _buildDetailsActions(
    BuildContext context,
    FundAccountProvider provider,
    FundAccountEntity selected,
  ) {
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
          icon: Icon(Icons.delete_outline, size: 18.sp, color: FinDT.danger),
          tooltip: 'Delete Account',
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
    final color = isDeposit ? FinDT.success : FinDT.danger;
    return OutlinedButton.icon(
      onPressed: () =>
          _showTransactionDialog(context, provider, account, isDeposit),
      icon: Icon(
        isDeposit ? Icons.add_rounded : Icons.remove_rounded,
        size: 14.sp,
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              title: Text(
                'Select Coordinator',
                style: GoogleFonts.inter(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: FinDT.textPrimary,
                ),
              ),
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

  void _showAccountFormDialog(
    BuildContext context,
    FundAccountProvider provider, {
    FundAccountEntity? account,
  }) {
    final empProv = context.read<EmployeeProvider>();
    final isEditing = account != null;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: account?.name);
    final codeCtrl = TextEditingController(text: account?.code);
    String? assignedName = account?.assignedTo;
    FundAccountType selectedType = account?.type ?? FundAccountType.pettyCash;
    String currency = account?.currency ?? 'SAR';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          title: Text(
            isEditing ? 'Edit Fund Account' : 'New Fund Account',
            style: GoogleFonts.inter(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: FinDT.textPrimary,
            ),
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
                    TextFormField(
                      controller: codeCtrl,
                      decoration: _dialogInputDecoration(
                        label: 'Account Code *',
                        hint: 'e.g. ACC-PETTY-01',
                        prefixIcon: Icons.qr_code_rounded,
                      ),
                      style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    SizedBox(height: 14.h),
                    DropdownButtonFormField<FundAccountType>(
                      initialValue: selectedType,
                      decoration: _dialogInputDecoration(
                        label: 'Account Type',
                        prefixIcon: Icons.category_outlined,
                      ),
                      style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
                      items: FundAccountType.values
                          .map(
                            (t) => DropdownMenuItem(
                              value: t,
                              child: Text(t.displayName),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setStateDialog(() => selectedType = v ?? FundAccountType.pettyCash),
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
                          if (selectedType == FundAccountType.stcPay) {
                            hasConflict = provider.accounts.any((a) =>
                                a.assignedTo == assignedName &&
                                a.type == FundAccountType.pettyCash &&
                                a.id != account?.id);
                          } else if (selectedType == FundAccountType.pettyCash) {
                            hasConflict = provider.accounts.any((a) =>
                                a.assignedTo == assignedName &&
                                a.type == FundAccountType.stcPay &&
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
                                    selectedType == FundAccountType.stcPay
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
                  if (selectedType == FundAccountType.stcPay) {
                    hasConflict = provider.accounts.any((a) =>
                        a.assignedTo == assignedName &&
                        a.type == FundAccountType.pettyCash &&
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

                final acc = FundAccountEntity(
                  id: isEditing ? account.id : const Uuid().v4(),
                  name: nameCtrl.text,
                  code: codeCtrl.text,
                  type: selectedType,
                  currency: currency,
                  assignedTo: assignedName,
                  currentBalance: isEditing ? account.currentBalance : 0.0,
                  cashBalance: isEditing ? account.cashBalance : 0.0,
                  stcPayBalance: isEditing ? account.stcPayBalance : 0.0,
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
    final isPettyCash = account.type == FundAccountType.pettyCash;

    final amountCtrl = TextEditingController();
    final cashAmountCtrl = TextEditingController();
    final stcAmountCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Text(
          isDeposit ? 'Deposit Funds' : 'Withdraw Funds',
          style: GoogleFonts.inter(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: FinDT.textPrimary,
          ),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: Text(
          'This will permanently delete ${account.name}. Historical transactions will be preserved in logs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              provider.deleteAccount(account.id);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: FinDT.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
