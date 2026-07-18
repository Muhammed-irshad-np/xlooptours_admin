import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:xloop_invoice/features/finance/domain/entities/fund_transaction_entity.dart';
import '../providers/fund_account_provider.dart';
import '../widgets/fund_account_card.dart';
import '../widgets/currency_display.dart';
import '../../domain/entities/fund_account_entity.dart';
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

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Accounts List
            Expanded(flex: 4, child: _buildAccountsColumn(context, provider)),
            SizedBox(width: 24.w),

            // Right Column: Details & Transaction Log
            Expanded(flex: 5, child: _buildDetailsColumn(context, provider)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Virtual Accounts',
              style: GoogleFonts.inter(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: FinDT.textPrimary,
              ),
            ),
            _buildCreateAccountButton(context, provider),
          ],
        ),
        SizedBox(height: 16.h),
        if (active.isEmpty)
          _buildEmptyAccounts()
        else
          GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16.w,
              mainAxisSpacing: 16.h,
              childAspectRatio: 1.35,
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
          ),
      ],
    );
  }

  Widget _buildEmptyAccounts() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(40.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: FinDT.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 40.sp,
            color: FinDT.textMuted,
          ),
          SizedBox(height: 16.h),
          Text(
            'No accounts created yet',
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: FinDT.textPrimary,
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
    return ElevatedButton.icon(
      onPressed: () => _showAccountFormDialog(context, provider),
      icon: Icon(Icons.add, size: 16.sp),
      label: Text(
        'Add Account',
        style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: FinDT.brand,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
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
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: FinDT.border),
        ),
        child: Center(
          child: Text(
            'Select an account to view details & transactions',
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              color: FinDT.textSecondary,
            ),
          ),
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

          // Deposit / Withdrawal buttons
          Padding(
            padding: EdgeInsets.all(20.w),
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
                final isDeposit = tx.type == FundTransactionType.deposit;
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
                          color: isDeposit
                              ? FinDT.success.withValues(alpha: 0.08)
                              : FinDT.danger.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isDeposit
                              ? Icons.add_circle_outline
                              : Icons.remove_circle_outline,
                          color: isDeposit ? FinDT.success : FinDT.danger,
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
                            color: isDeposit ? FinDT.success : FinDT.danger,
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

  void _showAccountFormDialog(
    BuildContext context,
    FundAccountProvider provider, {
    FundAccountEntity? account,
  }) {
    final isEditing = account != null;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: account?.name);
    final codeCtrl = TextEditingController(text: account?.code);
    final assignedCtrl = TextEditingController(text: account?.assignedTo);
    FundAccountType selectedType = account?.type ?? FundAccountType.pettyCash;
    String currency = account?.currency ?? 'SAR';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? 'Edit Account' : 'New Fund Account'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Account Name *'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              SizedBox(height: 12.h),
              TextFormField(
                controller: codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Account Code *',
                  hintText: 'e.g., PETTY ACC#001',
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              SizedBox(height: 12.h),
              DropdownButtonFormField<FundAccountType>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'Account Type'),
                items: FundAccountType.values
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (v) => selectedType = v ?? FundAccountType.pettyCash,
              ),
              SizedBox(height: 12.h),
              DropdownButtonFormField<String>(
                value: currency,
                decoration: const InputDecoration(labelText: 'Currency'),
                items: ['SAR', 'BHD', 'AED', 'USD']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => currency = v ?? 'SAR',
              ),
              SizedBox(height: 12.h),
              TextFormField(
                controller: assignedCtrl,
                decoration: const InputDecoration(
                  labelText: 'Assigned Coordinator',
                  hintText: 'Employee name (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final acc = FundAccountEntity(
                id: isEditing ? account.id : const Uuid().v4(),
                name: nameCtrl.text,
                code: codeCtrl.text,
                type: selectedType,
                currency: currency,
                assignedTo: assignedCtrl.text.isEmpty
                    ? null
                    : assignedCtrl.text,
                currentBalance: isEditing ? account.currentBalance : 0.0,
                createdAt: isEditing ? account.createdAt : DateTime.now(),
              );

              if (isEditing) {
                provider.updateAccount(acc);
              } else {
                provider.insertAccount(acc);
              }
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: FinDT.brand),
            child: Text(isEditing ? 'Save' : 'Create'),
          ),
        ],
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
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isDeposit ? 'Deposit Cash' : 'Withdraw Cash'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Account: ${account.name} (${account.code})',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  color: FinDT.textSecondary,
                ),
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Amount *',
                  suffixText: 'SAR',
                ),
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
              SizedBox(height: 12.h),
              TextFormField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description / Purpose *',
                  hintText: 'e.g., Seed petty cash fund, bank withdrawal',
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final amount = double.parse(amountCtrl.text);
              final balanceBefore = account.currentBalance;
              final balanceAfter = isDeposit
                  ? balanceBefore + amount
                  : balanceBefore - amount;

              final tx = FundTransactionEntity(
                id: const Uuid().v4(),
                fundAccountId: account.id,
                type: isDeposit
                    ? FundTransactionType.deposit
                    : FundTransactionType.withdrawal,
                amount: amount,
                currency: account.currency,
                description: descCtrl.text,
                performedBy: 'Admin',
                date: DateTime.now(),
                createdAt: DateTime.now(),
                balanceBefore: balanceBefore,
                balanceAfter: balanceAfter,
              );

              provider.recordTransaction(tx);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
              backgroundColor: isDeposit ? FinDT.success : FinDT.danger,
            ),
            child: Text(isDeposit ? 'Deposit' : 'Withdraw'),
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
