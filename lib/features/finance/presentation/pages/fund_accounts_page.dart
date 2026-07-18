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
    return ElevatedButton.icon(
      onPressed: () => _showAccountFormDialog(context, provider),
      icon: Icon(Icons.add_rounded, size: 16.sp),
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
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 11.h),
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
                final acc = FundAccountEntity(
                  id: isEditing ? account.id : const Uuid().v4(),
                  name: nameCtrl.text,
                  code: codeCtrl.text,
                  type: selectedType,
                  currency: currency,
                  assignedTo: assignedName,
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
    final amountCtrl = TextEditingController();
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
          isDeposit ? 'Deposit Cash' : 'Withdraw Cash',
          style: GoogleFonts.inter(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: FinDT.textPrimary,
          ),
        ),
        content: SizedBox(
          width: 400.w,
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
                TextFormField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
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
