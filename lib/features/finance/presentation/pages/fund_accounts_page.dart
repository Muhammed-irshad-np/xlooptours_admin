import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:xloop_invoice/features/finance/domain/entities/fund_account_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/fund_transaction_entity.dart';
import 'package:xloop_invoice/features/finance/presentation/providers/fund_account_provider.dart';
import 'package:xloop_invoice/features/finance/presentation/widgets/fund_account_card.dart';
import 'package:xloop_invoice/features/finance/presentation/widgets/transaction_timeline.dart';
import 'package:xloop_invoice/features/employee/presentation/providers/employee_provider.dart';

/// Page to manage virtual fund accounts (e.g. Petty Cash, Driver Accounts, STC Pay)
/// and their financial transaction history.
class FundAccountsPage extends StatefulWidget {
  const FundAccountsPage({super.key});

  @override
  State<FundAccountsPage> createState() => _FundAccountsPageState();
}

class _FundAccountsPageState extends State<FundAccountsPage> {
  @override
  void initState() {
    super.initState();
    // Load accounts initially
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final fap = context.read<FundAccountProvider>();
      fap.fetchAllAccounts().then((_) {
        if (fap.accounts.isNotEmpty && fap.selectedAccountId == null) {
          fap.selectAccount(fap.accounts.first.id);
        }
      });
    });
  }

  void _showAddAccountDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final balanceController = TextEditingController(text: '0.0');
    FundAccountType selectedType = FundAccountType.pettyCash;
    String selectedCurrency = 'SAR';
    String? selectedEmployeeId;
    String? selectedEmployeeName;

    showDialog(
      context: context,
      builder: (ctx) {
        final employeeProvider = ctx.watch<EmployeeProvider>();
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
          title: Text('Create Fund Account', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextField(nameController, 'Account Name', validator: (v) => v!.isEmpty ? 'Enter name' : null),
                  SizedBox(height: 12.h),
                  _buildTextField(codeController, 'Code (e.g., PETTY ACC#001)', validator: (v) => v!.isEmpty ? 'Enter code' : null),
                  SizedBox(height: 12.h),
                  _buildDropdownField<FundAccountType>(
                    label: 'Type',
                    value: selectedType,
                    items: FundAccountType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.displayName))).toList(),
                    onChanged: (v) {
                      if (v != null) selectedType = v;
                    },
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildTextField(
                          balanceController,
                          'Initial Balance',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        flex: 1,
                        child: _buildDropdownField<String>(
                          label: 'Currency',
                          value: selectedCurrency,
                          items: const [
                            DropdownMenuItem(value: 'SAR', child: Text('SAR')),
                            DropdownMenuItem(value: 'BHD', child: Text('BHD')),
                          ],
                          onChanged: (v) {
                            if (v != null) selectedCurrency = v;
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  _buildDropdownField<String>(
                    label: 'Assign To Employee (Optional)',
                    value: selectedEmployeeId,
                    items: employeeProvider.employees.map((e) => DropdownMenuItem(value: e.id, child: Text(e.fullName))).toList(),
                    onChanged: (v) {
                      selectedEmployeeId = v;
                      if (v != null) {
                        selectedEmployeeName = employeeProvider.employees.firstWhere((e) => e.id == v).fullName;
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF6B7280))),
            ),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final newAccount = FundAccountEntity(
                  id: const Uuid().v4(),
                  name: nameController.text.trim(),
                  code: codeController.text.trim(),
                  type: selectedType,
                  currentBalance: double.tryParse(balanceController.text) ?? 0.0,
                  currency: selectedCurrency,
                  assignedTo: selectedEmployeeName,
                  assignedToId: selectedEmployeeId,
                  createdAt: DateTime.now(),
                );
                context.read<FundAccountProvider>().insertAccount(newAccount);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
              child: Text('Create', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  void _showTransactionDialog(BuildContext context, FundTransactionType type) {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    String? selectedDestAccountId;

    final provider = context.read<FundAccountProvider>();
    final account = provider.selectedAccount;
    if (account == null) return;

    showDialog(
      context: context,
      builder: (ctx) {
        final fap = ctx.watch<FundAccountProvider>();
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
          title: Text(
            type == FundTransactionType.deposit
                ? 'Record Deposit'
                : type == FundTransactionType.withdrawal
                    ? 'Record Withdrawal'
                    : 'Record Transfer',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Source Account: ${account.name} (${account.currentBalance} ${account.currency})',
                    style: GoogleFonts.inter(fontSize: 12.sp, color: const Color(0xFF6B7280)),
                  ),
                  SizedBox(height: 16.h),
                  _buildTextField(
                    amountController,
                    'Amount',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    validator: (v) {
                      if (v!.isEmpty) return 'Enter amount';
                      final val = double.tryParse(v);
                      if (val == null || val <= 0) return 'Enter a positive amount';
                      if (type != FundTransactionType.deposit && val > account.currentBalance) {
                        return 'Insufficient balance';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 12.h),
                  if (type == FundTransactionType.transfer) ...[
                    _buildDropdownField<String>(
                      label: 'Destination Account',
                      value: selectedDestAccountId,
                      items: fap.activeAccounts
                          .where((a) => a.id != account.id)
                          .map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} (${a.currency})')))
                          .toList(),
                      onChanged: (v) {
                        selectedDestAccountId = v;
                      },
                      validator: (v) => v == null ? 'Select destination' : null,
                    ),
                    SizedBox(height: 12.h),
                  ],
                  _buildTextField(
                    descriptionController,
                    'Description / Ref ID',
                    validator: (v) => v!.isEmpty ? 'Enter description' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF6B7280))),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final double amount = double.parse(amountController.text);
                final desc = descriptionController.text.trim();
                final now = DateTime.now();

                if (type == FundTransactionType.transfer) {
                  final destAccount = provider.getAccountById(selectedDestAccountId!);
                  if (destAccount == null) return;

                  // Record Outflow from source
                  final txOut = FundTransactionEntity(
                    id: const Uuid().v4(),
                    fundAccountId: account.id,
                    type: FundTransactionType.transfer,
                    amount: amount,
                    currency: account.currency,
                    description: 'Transfer to ${destAccount.name}: $desc',
                    transferToAccountId: destAccount.id,
                    performedBy: 'ADMIN',
                    date: now,
                    createdAt: now,
                    balanceBefore: account.currentBalance,
                    balanceAfter: account.currentBalance - amount,
                  );

                  // Record Inflow to destination
                  final txIn = FundTransactionEntity(
                    id: const Uuid().v4(),
                    fundAccountId: destAccount.id,
                    type: FundTransactionType.transfer,
                    amount: amount,
                    currency: destAccount.currency,
                    description: 'Transfer from ${account.name}: $desc',
                    performedBy: 'ADMIN',
                    date: now,
                    createdAt: now,
                    balanceBefore: destAccount.currentBalance,
                    balanceAfter: destAccount.currentBalance + amount,
                  );

                  await provider.recordTransaction(txOut);
                  await provider.recordTransaction(txIn);
                } else {
                  final double balanceAfter = type == FundTransactionType.deposit
                      ? account.currentBalance + amount
                      : account.currentBalance - amount;

                  final tx = FundTransactionEntity(
                    id: const Uuid().v4(),
                    fundAccountId: account.id,
                    type: type,
                    amount: amount,
                    currency: account.currency,
                    description: desc,
                    performedBy: 'ADMIN',
                    date: now,
                    createdAt: now,
                    balanceBefore: account.currentBalance,
                    balanceAfter: balanceAfter,
                  );

                  await provider.recordTransaction(tx);
                }

                if (context.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
              child: Text('Record', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FundAccountProvider>(
      builder: (context, fap, _) {
        final selectedAccount = fap.selectedAccount;

        return Row(
          children: [
            // Left Panel (Accounts List)
            Expanded(
              flex: 2,
              child: Container(
                color: const Color(0xFFF9FAFB),
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(20.w),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Virtual Accounts',
                            style: GoogleFonts.inter(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _showAddAccountDialog(context),
                            icon: const Icon(Icons.add, size: 16),
                            label: Text('Create Account', style: GoogleFonts.inter(fontSize: 12.sp)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: fap.isLoading
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
                          : ListView.builder(
                              padding: EdgeInsets.symmetric(horizontal: 20.w),
                              itemCount: fap.accounts.length,
                              itemBuilder: (ctx, index) {
                                final account = fap.accounts[index];
                                return Padding(
                                  padding: EdgeInsets.only(bottom: 12.h),
                                  child: FundAccountCard(
                                    account: account,
                                    isSelected: account.id == fap.selectedAccountId,
                                    onTap: () => fap.selectAccount(account.id),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
            // Divider
            const VerticalDivider(width: 1, color: Color(0xFFE5E7EB)),
            // Right Panel (Transaction History & Actions)
            Expanded(
              flex: 3,
              child: Container(
                color: Colors.white,
                child: selectedAccount == null
                    ? Center(
                        child: Text(
                          'Select an account to view transactions',
                          style: GoogleFonts.inter(color: const Color(0xFF9CA3AF), fontSize: 13.sp),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: EdgeInsets.all(24.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      selectedAccount.name,
                                      style: GoogleFonts.inter(fontSize: 18.sp, fontWeight: FontWeight.w700),
                                    ),
                                    Text(
                                      'Code: ${selectedAccount.code}',
                                      style: GoogleFonts.inter(fontSize: 12.sp, color: const Color(0xFF9CA3AF)),
                                    ),
                                  ],
                                ),
                                // Edit/Archive Account Actions
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () {
                                        // Edit Account metadata if needed
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.archive_outlined),
                                      onPressed: () {
                                        fap.updateAccount(selectedAccount.copyWith(isActive: !selectedAccount.isActive));
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: 24.h),
                            // Quick Action Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: _ActionBtn(
                                    label: 'Deposit',
                                    icon: Icons.add_circle_outline,
                                    color: const Color(0xFF10B981),
                                    onTap: () => _showTransactionDialog(context, FundTransactionType.deposit),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: _ActionBtn(
                                    label: 'Withdraw',
                                    icon: Icons.remove_circle_outline,
                                    color: const Color(0xFFEF4444),
                                    onTap: () => _showTransactionDialog(context, FundTransactionType.withdrawal),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: _ActionBtn(
                                    label: 'Transfer',
                                    icon: Icons.swap_horiz,
                                    color: const Color(0xFF3B82F6),
                                    onTap: () => _showTransactionDialog(context, FundTransactionType.transfer),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 32.h),
                            Text(
                              'Transaction History',
                              style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w700),
                            ),
                            SizedBox(height: 16.h),
                            fap.isTransactionsLoading
                                ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
                                : TransactionTimeline(transactions: fap.transactions),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: const Color(0xFF374151)),
        ),
        SizedBox(height: 6.h),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          style: GoogleFonts.inter(fontSize: 13.sp),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    String? Function(T?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: const Color(0xFF374151)),
        ),
        SizedBox(height: 6.h),
        DropdownButtonFormField<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          validator: validator,
          style: GoogleFonts.inter(fontSize: 13.sp, color: Colors.black),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
          ),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16.sp),
      label: Text(label, style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: EdgeInsets.symmetric(vertical: 12.h),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      ),
    );
  }
}
