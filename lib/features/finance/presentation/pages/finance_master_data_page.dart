import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/finance_provider.dart';
import '../providers/fund_account_provider.dart';
import '../../domain/entities/expense_category_entity.dart';
import '../../domain/entities/fund_account_type_entity.dart';
import '../widgets/finance_dialog_helpers.dart';
import '../widgets/finance_workflow_policy_view.dart';
import 'finance_dashboard_page.dart';

/// Master Data Hub for the Finance module.
///
/// Houses central feeded configurations:
/// 1. Expense Categories & Types
/// 2. Virtual Account Types
/// 3. Finance Approval Policies & Thresholds
class FinanceMasterDataPage extends StatefulWidget {
  final int initialSubTab;

  const FinanceMasterDataPage({
    super.key,
    this.initialSubTab = 0,
  });

  @override
  State<FinanceMasterDataPage> createState() => _FinanceMasterDataPageState();
}

class _FinanceMasterDataPageState extends State<FinanceMasterDataPage> {
  late int _currentSubTab;

  @override
  void initState() {
    super.initState();
    _currentSubTab = widget.initialSubTab;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final finProv = context.read<FinanceProvider>();
      final accProv = context.read<FundAccountProvider>();
      if (finProv.categories.isEmpty) finProv.fetchCategories();
      finProv.fetchFinancePolicy();
      if (accProv.accountTypes.isEmpty) accProv.fetchAccountTypes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final finProv = context.watch<FinanceProvider>();
    final accProv = context.watch<FundAccountProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Top Header ──────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Finance Master Data',
                  style: GoogleFonts.inter(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w800,
                    color: FinDT.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  'Central master records, expense classifications, virtual account types, and approval policies',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: FinDT.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 18.h),

        // ── Sub-Navigation Tabs ─────────────────────────────────
        _buildSubNavPills(finProv, accProv),
        SizedBox(height: 20.h),

        // ── Active Master View ──────────────────────────────────
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _buildSubTabContent(finProv, accProv),
        ),
      ],
    );
  }

  Widget _buildSubNavPills(FinanceProvider finProv, FundAccountProvider accProv) {
    final tabs = [
      _MasterSubTabInfo(
        title: 'Expense Categories',
        icon: Icons.category_outlined,
        badge: '${finProv.categories.length}',
      ),
      _MasterSubTabInfo(
        title: 'Account Types',
        icon: Icons.account_balance_wallet_outlined,
        badge: '${accProv.accountTypes.length}',
      ),
      _MasterSubTabInfo(
        title: 'Workflow & Policies',
        icon: Icons.shield_outlined,
        badge: 'Governance',
      ),
    ];

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(tabs.length, (index) {
            final isSelected = _currentSubTab == index;
            final item = tabs[index];
            return InkWell(
              onTap: () => setState(() => _currentSubTab = index),
              borderRadius: BorderRadius.circular(8.r),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                margin: EdgeInsets.symmetric(horizontal: 2.w),
                padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 16.w),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8.r),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      size: 16.sp,
                      color: isSelected ? FinDT.brand : FinDT.textSecondary,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      item.title,
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? FinDT.textPrimary : FinDT.textSecondary,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? FinDT.brand.withValues(alpha: 0.12)
                            : const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Text(
                        item.badge,
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? FinDT.brand : FinDT.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildSubTabContent(FinanceProvider finProv, FundAccountProvider accProv) {
    switch (_currentSubTab) {
      case 0:
        return _buildCategoriesMasterView(finProv);
      case 1:
        return _buildAccountTypesMasterView(accProv);
      case 2:
        return const FinanceWorkflowPolicyView();
      default:
        return const SizedBox.shrink();
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // 1. EXPENSE CATEGORIES MASTER VIEW
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildCategoriesMasterView(FinanceProvider provider) {
    if (provider.isCategoriesLoading && provider.categories.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 40.h),
        child: const Center(child: CircularProgressIndicator(color: FinDT.brand)),
      );
    }

    return Column(
      key: const ValueKey('categories_master_view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Action bar
        Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: FinDT.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.category_outlined, size: 20.sp, color: FinDT.brand),
                  SizedBox(width: 8.w),
                  Text(
                    'Corporate Expense Classifications',
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: FinDT.textPrimary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _preseedDefaultCategories(context, provider),
                    icon: Icon(Icons.download_rounded, size: 15.sp),
                    label: Text(
                      'Preseed Standard Categories',
                      style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FinDT.brand,
                      side: BorderSide(color: FinDT.brand.withValues(alpha: 0.4)),
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  ElevatedButton.icon(
                    onPressed: () => _showAddCategoryDialog(context, provider),
                    icon: Icon(Icons.add_rounded, size: 16.sp),
                    label: Text(
                      'Add Category',
                      style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: FinDT.brand,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
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

        if (provider.categories.isEmpty)
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
                Icon(Icons.category_outlined, size: 40.sp, color: FinDT.textMuted),
                SizedBox(height: 14.h),
                Text(
                  'No expense categories found',
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: FinDT.textPrimary,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'Click "Preseed Standard Categories" to load default corporate classifications.',
                  style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textSecondary),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: provider.categories.length,
            separatorBuilder: (_, __) => SizedBox(height: 14.h),
            itemBuilder: (context, index) {
              final category = provider.categories[index];
              return _CategoryExpansionCard(category: category, provider: provider);
            },
          ),
      ],
    );
  }

  Future<void> _preseedDefaultCategories(
    BuildContext context,
    FinanceProvider provider,
  ) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final defaults = [
      ExpenseCategoryEntity(
        id: const Uuid().v4(),
        name: 'COMPANY',
        createdAt: DateTime.now(),
        expenseTypes: const [
          ExpenseTypeEntity(
            id: 'rent',
            name: 'Office Rent',
            defaultDuration: 'YEARLY',
            submittedByRole: 'ADMIN',
          ),
          ExpenseTypeEntity(
            id: 'electricity',
            name: 'Electricity Bill',
            defaultDuration: 'MONTHLY',
            submittedByRole: 'ADMIN',
          ),
          ExpenseTypeEntity(
            id: 'tax',
            name: 'Corporate Tax',
            defaultDuration: 'QUARTERLY',
            submittedByRole: 'ADMIN',
          ),
          ExpenseTypeEntity(
            id: 'wifi',
            name: 'Office Wi-Fi',
            defaultDuration: 'MONTHLY',
            submittedByRole: 'ADMIN',
          ),
        ],
      ),
      ExpenseCategoryEntity(
        id: const Uuid().v4(),
        name: 'VEHICLES',
        createdAt: DateTime.now(),
        expenseTypes: const [
          ExpenseTypeEntity(
            id: 'fuel',
            name: 'Fuel',
            defaultDuration: 'DAILY',
            submittedByRole: 'DRIVER',
          ),
          ExpenseTypeEntity(
            id: 'car_wash',
            name: 'Car Wash',
            defaultDuration: 'DAILY',
            submittedByRole: 'DRIVER',
          ),
          ExpenseTypeEntity(
            id: 'maintenance',
            name: 'Maintenance & Repairs',
            defaultDuration: 'MONTHLY',
            submittedByRole: 'COORDINATOR',
          ),
          ExpenseTypeEntity(
            id: 'insurance',
            name: 'Vehicle Insurance',
            defaultDuration: 'YEARLY',
            submittedByRole: 'ADMIN',
          ),
        ],
      ),
      ExpenseCategoryEntity(
        id: const Uuid().v4(),
        name: 'EMPLOYEES',
        createdAt: DateTime.now(),
        expenseTypes: const [
          ExpenseTypeEntity(
            id: 'salary',
            name: 'Basic Salary',
            defaultDuration: 'MONTHLY',
            submittedByRole: 'ADMIN',
          ),
          ExpenseTypeEntity(
            id: 'allowance',
            name: 'Housing & Transport Allowance',
            defaultDuration: 'MONTHLY',
            submittedByRole: 'ADMIN',
          ),
          ExpenseTypeEntity(
            id: 'bonus',
            name: 'Performance Bonus',
            defaultDuration: 'MONTHLY',
            submittedByRole: 'ADMIN',
          ),
        ],
      ),
    ];

    int addedCount = 0;
    for (final cat in defaults) {
      if (!provider.categories.any((c) => c.name.toUpperCase() == cat.name)) {
        await provider.insertCategory(cat);
        addedCount++;
      }
    }

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(
          addedCount > 0
              ? 'Successfully pre-seeded $addedCount standard categories'
              : 'All default categories already exist',
          style: GoogleFonts.inter(color: Colors.white),
        ),
        backgroundColor: FinDT.success,
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, FinanceProvider provider) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    bool isCreating = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: finDialogShape,
          title: finDialogTitle('New Expense Category', icon: Icons.category_outlined),
          content: SizedBox(
            width: 380.w,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 8.h),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: finDialogInputDecoration(
                      label: 'Category Name *',
                      hint: 'e.g. MARKETING, IT INFRASTRUCTURE',
                      prefixIcon: Icons.edit_outlined,
                    ),
                    style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (provider.categories.any(
                          (c) => c.name.toUpperCase() == v.trim().toUpperCase())) {
                        return 'Category already exists';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            finDialogCancelButton(
              ctx,
              onPressed: isCreating ? () {} : null,
            ),
            finDialogActionButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final cat = ExpenseCategoryEntity(
                  id: const Uuid().v4(),
                  name: nameCtrl.text.trim().toUpperCase(),
                  createdAt: DateTime.now(),
                );

                setDialogState(() => isCreating = true);
                try {
                  await provider.insertCategory(cat);
                  if (ctx.mounted) finSafePop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    setDialogState(() => isCreating = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$e'), backgroundColor: FinDT.danger),
                    );
                  }
                }
              },
              label: 'Create Category',
              backgroundColor: FinDT.brand,
              isLoading: isCreating,
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // 2. VIRTUAL ACCOUNT TYPES MASTER VIEW
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildAccountTypesMasterView(FundAccountProvider provider) {
    final types = provider.accountTypes;

    return Column(
      key: const ValueKey('account_types_master_view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Action Bar
        Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: FinDT.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 20.sp, color: FinDT.brand),
                  SizedBox(width: 8.w),
                  Text(
                    'Virtual Account Types & Ledgers',
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: FinDT.textPrimary,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAccountTypeEditDialog(context, provider),
                icon: Icon(Icons.add_rounded, size: 16.sp),
                label: Text(
                  'New Account Type',
                  style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: FinDT.brand,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),

        // Explanatory note
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
                  'Default types (Bank, Petty Cash, STC Pay) are permanent system anchors. Custom types (e.g. Driver Accounts, Fuel Cards, Tamkeen) define dynamic ledger prefix codes for auto-generation.',
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

        // Account Types Grid
        GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : 2,
            crossAxisSpacing: 14.w,
            mainAxisSpacing: 14.h,
            childAspectRatio: 1.8,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: types.length,
          itemBuilder: (context, index) {
            final type = types[index];
            final linkedAccounts = provider.accounts
                .where((a) =>
                    a.accountTypeId == type.id ||
                    a.typeDisplayName.toLowerCase() == type.name.toLowerCase())
                .length;

            return Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: FinDT.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
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
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: FinDT.brand.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          type.codePrefix,
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w800,
                            color: FinDT.brand,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      if (type.isSystemDefault)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            'System Default',
                            style: GoogleFonts.inter(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF4338CA),
                            ),
                          ),
                        )
                      else
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit_outlined, size: 15.sp, color: FinDT.textSecondary),
                              tooltip: 'Edit Type',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _showAccountTypeEditDialog(
                                context,
                                provider,
                                typeToEdit: type,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded, size: 15.sp, color: FinDT.danger),
                              tooltip: 'Delete Type',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _confirmDeleteAccountType(context, provider, type, linkedAccounts),
                            ),
                          ],
                        ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.name,
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: FinDT.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        type.description ?? 'Standard system ledger type',
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          color: FinDT.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$linkedAccounts active account(s)',
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: linkedAccounts > 0 ? FinDT.brand : FinDT.textMuted,
                        ),
                      ),
                      Icon(
                        Icons.circle,
                        size: 8.sp,
                        color: type.isActive ? FinDT.success : FinDT.danger,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _confirmDeleteAccountType(
    BuildContext context,
    FundAccountProvider provider,
    FundAccountTypeEntity type,
    int linkedAccountsCount,
  ) async {
    if (linkedAccountsCount > 0) {
      showFinConfirmationDialog(
        context: context,
        title: 'Cannot Delete Account Type',
        icon: Icons.lock_outline_rounded,
        iconColor: FinDT.danger,
        confirmColor: FinDT.brand,
        confirmLabel: 'Understood',
        message:
            'Cannot delete "${type.name}". There are currently $linkedAccountsCount active account(s) assigned to this virtual account type.',
        highlightNote:
            'Reassign or close all linked accounts before deleting this account type.',
      );
      return;
    }

    final confirm = await showFinConfirmationDialog(
      context: context,
      title: 'Delete Account Type?',
      message:
          'Are you sure you want to delete "${type.name}" (${type.codePrefix}) from system master records?',
      highlightNote:
          'This action is irreversible. The code prefix will no longer be available for auto-generating new ledgers.',
      confirmLabel: 'Delete Account Type',
      confirmColor: FinDT.danger,
      icon: Icons.delete_outline_rounded,
      iconColor: FinDT.danger,
    );

    if (confirm == true) {
      await provider.deleteAccountType(type.id);
    }
  }

  Future<FundAccountTypeEntity?> _showAccountTypeEditDialog(
    BuildContext context,
    FundAccountProvider provider, {
    FundAccountTypeEntity? typeToEdit,
  }) async {
    final formKey = GlobalKey<FormState>();
    final isEditing = typeToEdit != null;
    final nameCtrl = TextEditingController(text: typeToEdit?.name);
    final prefixCtrl = TextEditingController(text: typeToEdit?.codePrefix);
    final descCtrl = TextEditingController(text: typeToEdit?.description);
    bool isSaving = false;

    return showDialog<FundAccountTypeEntity?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: finDialogShape,
          title: finDialogTitle(
            isEditing ? 'Edit Account Type' : 'New Account Type',
            icon: Icons.category_outlined,
          ),
          content: SizedBox(
            width: 380.w,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 8.h),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: finDialogInputDecoration(
                        label: 'Account Type Name *',
                        hint: 'e.g. Driver Account, Fuel Card',
                        prefixIcon: Icons.edit_outlined,
                      ),
                      style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
                      onChanged: (val) {
                        if (!isEditing && prefixCtrl.text.trim().isEmpty && val.trim().isNotEmpty) {
                          final words = val.trim().split(RegExp(r'\s+'));
                          String autoPrefix = '';
                          if (words.length == 1) {
                            autoPrefix = val.trim().substring(0, val.trim().length.clamp(0, 3)).toUpperCase();
                          } else {
                            autoPrefix = words.take(3).map((w) => w[0]).join().toUpperCase();
                          }
                          prefixCtrl.text = autoPrefix;
                        }
                      },
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Name required';
                        final exists = provider.accountTypes.any((t) =>
                            t.name.toLowerCase() == v.trim().toLowerCase() &&
                            t.id != typeToEdit?.id);
                        if (exists) return 'An account type with this name already exists';
                        return null;
                      },
                    ),
                    SizedBox(height: 14.h),
                    TextFormField(
                      controller: prefixCtrl,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: finDialogInputDecoration(
                        label: 'Code Prefix * (e.g. DRV, PC, BNK)',
                        hint: 'e.g. DRV',
                        prefixIcon: Icons.qr_code_rounded,
                      ),
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: FinDT.textPrimary,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Code prefix required';
                        if (v.trim().length < 2) return 'At least 2 characters';
                        return null;
                      },
                    ),
                    SizedBox(height: 14.h),
                    TextFormField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: finDialogInputDecoration(
                        label: 'Description (Optional)',
                        hint: 'e.g. Float allocated to active operational drivers',
                        prefixIcon: Icons.description_outlined,
                      ),
                      style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            finDialogCancelButton(
              ctx,
              onPressed: isSaving ? () {} : null,
            ),
            finDialogActionButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final newType = FundAccountTypeEntity(
                  id: isEditing ? typeToEdit.id : const Uuid().v4(),
                  name: nameCtrl.text.trim(),
                  codePrefix: prefixCtrl.text.trim().toUpperCase(),
                  description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                  isSystemDefault: typeToEdit?.isSystemDefault ?? false,
                  isActive: true,
                  createdAt: typeToEdit?.createdAt ?? DateTime.now(),
                );

                setDialogState(() => isSaving = true);
                try {
                  if (isEditing) {
                    await provider.updateAccountType(newType);
                  } else {
                    await provider.insertAccountType(newType);
                  }
                  if (ctx.mounted) finSafePop(ctx, newType);
                } catch (e) {
                  if (ctx.mounted) {
                    setDialogState(() => isSaving = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error saving account type: $e'),
                        backgroundColor: FinDT.danger,
                      ),
                    );
                  }
                }
              },
              label: isEditing ? 'Save Changes' : 'Create Type',
              backgroundColor: FinDT.brand,
              isLoading: isSaving,
            ),
          ],
        ),
      ),
    );
  }
}

class _MasterSubTabInfo {
  final String title;
  final IconData icon;
  final String badge;

  const _MasterSubTabInfo({
    required this.title,
    required this.icon,
    required this.badge,
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// CATEGORY EXPANSION CARD HELPER
// ═════════════════════════════════════════════════════════════════════════════

class _CategoryExpansionCard extends StatefulWidget {
  final ExpenseCategoryEntity category;
  final FinanceProvider provider;

  const _CategoryExpansionCard({
    required this.category,
    required this.provider,
  });

  @override
  State<_CategoryExpansionCard> createState() => _CategoryExpansionCardState();
}

class _CategoryExpansionCardState extends State<_CategoryExpansionCard> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;
    final types = cat.expenseTypes;

    return Container(
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
        children: [
          // Header Row
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(14.r),
              bottom: Radius.circular(_isExpanded ? 0 : 14.r),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: FinDT.brand.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(Icons.folder_outlined, size: 18.sp, color: FinDT.brand),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cat.name,
                          style: GoogleFonts.inter(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: FinDT.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          '${types.length} subcategory types configured',
                          style: GoogleFonts.inter(fontSize: 11.sp, color: FinDT.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add_circle_outline_rounded, size: 18.sp, color: FinDT.brand),
                    tooltip: 'Add Subcategory Type',
                    onPressed: () => _showAddTypeDialog(context),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, size: 18.sp, color: FinDT.danger),
                    tooltip: 'Delete Category',
                    onPressed: () => _confirmDeleteCategory(context),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 20.sp,
                    color: FinDT.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          // Types Content
          if (_isExpanded) ...[
            Divider(height: 1, color: FinDT.borderLight),
            Padding(
              padding: EdgeInsets.all(16.w),
              child: types.isEmpty
                  ? Center(
                      child: Text(
                        'No subcategory types added yet. Click + to add.',
                        style: GoogleFonts.inter(fontSize: 11.sp, color: FinDT.textMuted),
                      ),
                    )
                  : Wrap(
                      spacing: 10.w,
                      runSpacing: 10.h,
                      children: types.map((t) => _buildTypeChip(t)).toList(),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeChip(ExpenseTypeEntity type) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: FinDT.bgPage,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: FinDT.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            type.name,
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: FinDT.textPrimary,
            ),
          ),
          SizedBox(width: 8.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
            decoration: BoxDecoration(
              color: FinDT.brand.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4.r),
            ),
            child: Text(
              type.defaultDuration,
              style: GoogleFonts.inter(
                fontSize: 9.sp,
                fontWeight: FontWeight.w700,
                color: FinDT.brand,
              ),
            ),
          ),
          SizedBox(width: 6.w),
          InkWell(
            onTap: () => _confirmDeleteType(context, type),
            child: Icon(Icons.close, size: 14.sp, color: FinDT.textSecondary),
          ),
        ],
      ),
    );
  }

  void _showAddTypeDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    String duration = 'MONTHLY';
    String role = 'ADMIN';
    bool isAdding = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: finDialogShape,
          title: finDialogTitle('New Expense Type', icon: Icons.playlist_add_rounded),
          content: SizedBox(
            width: 380.w,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 8.h),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: finDialogInputDecoration(
                      label: 'Type Name *',
                      hint: 'e.g. Office Stationery, Car Wash',
                      prefixIcon: Icons.edit_outlined,
                    ),
                    style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  SizedBox(height: 14.h),
                  DropdownButtonFormField<String>(
                    initialValue: duration,
                    decoration: finDialogInputDecoration(
                      label: 'Default Duration',
                      prefixIcon: Icons.schedule_rounded,
                    ),
                    style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
                    items: ['DAILY', 'WEEKLY', 'MONTHLY', 'QUARTERLY', 'YEARLY', 'ONE_TIME']
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => duration = v ?? 'MONTHLY'),
                  ),
                  SizedBox(height: 14.h),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: finDialogInputDecoration(
                      label: 'Allowed Role',
                      prefixIcon: Icons.person_outline_rounded,
                    ),
                    style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
                    items: ['ADMIN', 'COORDINATOR', 'DRIVER', 'ANY']
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => role = v ?? 'ADMIN'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            finDialogCancelButton(
              ctx,
              onPressed: isAdding ? () {} : null,
            ),
            finDialogActionButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final newType = ExpenseTypeEntity(
                  id: const Uuid().v4(),
                  name: nameCtrl.text.trim(),
                  defaultDuration: duration,
                  submittedByRole: role,
                );
                final updatedCat = widget.category.copyWith(
                  expenseTypes: [...widget.category.expenseTypes, newType],
                );
                setDialogState(() => isAdding = true);
                try {
                  await widget.provider.updateCategory(updatedCat);
                  if (ctx.mounted) finSafePop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    setDialogState(() => isAdding = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$e'), backgroundColor: FinDT.danger),
                    );
                  }
                }
              },
              label: 'Add Type',
              backgroundColor: FinDT.brand,
              isLoading: isAdding,
            ),
          ],
        ),
      ),
    );
  }

  void _removeType(String typeId) {
    final updatedTypes = widget.category.expenseTypes.where((t) => t.id != typeId).toList();
    final updatedCat = widget.category.copyWith(expenseTypes: updatedTypes);
    widget.provider.updateCategory(updatedCat);
  }

  void _confirmDeleteType(BuildContext context, ExpenseTypeEntity type) {
    showFinConfirmationDialog(
      context: context,
      title: 'Delete Expense Type?',
      message:
          'Are you sure you want to remove "${type.name}" from category "${widget.category.name}"?',
      highlightNote:
          'Existing expense vouchers tagged with this type will remain in the transaction history.',
      confirmLabel: 'Delete Type',
      confirmColor: FinDT.danger,
      icon: Icons.delete_outline_rounded,
      iconColor: FinDT.danger,
      onConfirm: () async {
        _removeType(type.id);
      },
    );
  }

  Future<void> _confirmDeleteCategory(BuildContext context) async {
    await showFinConfirmationDialog(
      context: context,
      title: 'Delete Category?',
      message:
          'Are you sure you want to delete the category "${widget.category.name}" and all its ${widget.category.expenseTypes.length} configured sub-types?',
      highlightNote:
          'Historical expenses already filed under this category will retain their ledger records and audit trail.',
      confirmLabel: 'Delete Category',
      confirmColor: FinDT.danger,
      icon: Icons.delete_outline_rounded,
      iconColor: FinDT.danger,
      onConfirm: () async {
        await widget.provider.deleteCategory(widget.category.id);
      },
    );
  }
}
