import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/finance_provider.dart';
import '../../domain/entities/expense_category_entity.dart';
import 'finance_dashboard_page.dart';

/// Screen for managing expense categories and types.
class ExpenseCategoriesPage extends StatelessWidget {
  const ExpenseCategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceProvider>(
      builder: (context, provider, _) {
        if (provider.isCategoriesLoading && provider.categories.isEmpty) {
          return _buildLoading();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Expense Categories & Types',
                  style: GoogleFonts.inter(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: FinDT.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    _buildPreseedButton(context, provider),
                    SizedBox(width: 12.w),
                    _buildAddCategoryButton(context, provider),
                  ],
                ),
              ],
            ),
            SizedBox(height: 16.h),

            if (provider.categories.isEmpty)
              _buildEmptyState()
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: provider.categories.length,
                separatorBuilder: (_, __) => SizedBox(height: 16.h),
                itemBuilder: (context, index) {
                  final category = provider.categories[index];
                  return _CategoryExpansionCard(
                    category: category,
                    provider: provider,
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildLoading() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 40.h),
      child: const Center(
        child: CircularProgressIndicator(color: FinDT.brand),
      ),
    );
  }

  Widget _buildEmptyState() {
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
          Icon(Icons.category_outlined, size: 40.sp, color: FinDT.textMuted),
          SizedBox(height: 16.h),
          Text(
            'No expense categories found',
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: FinDT.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Click Preseed to load default standard categories.',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              color: FinDT.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreseedButton(BuildContext context, FinanceProvider provider) {
    return OutlinedButton.icon(
      onPressed: () => _preseedDefaultCategories(context, provider),
      icon: Icon(Icons.download_rounded, size: 16.sp),
      label: Text(
        'Preseed Defaults',
        style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: FinDT.brand,
        side: BorderSide(color: FinDT.brand.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      ),
    );
  }

  Widget _buildAddCategoryButton(BuildContext context, FinanceProvider provider) {
    return ElevatedButton.icon(
      onPressed: () => _showAddCategoryDialog(context, provider),
      icon: Icon(Icons.add, size: 16.sp),
      label: Text(
        'Add Category',
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

  // ─── Pre-seed Data Trigger ──────────────────────────────────

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

    for (final cat in defaults) {
      if (!provider.categories.any((c) => c.name.toUpperCase() == cat.name)) {
        await provider.insertCategory(cat);
      }
    }

    await provider.fetchCategories();
    scaffoldMessenger.showSnackBar(
      const SnackBar(content: Text('Standard categories pre-seeded successfully!')),
    );
  }

  void _showAddCategoryDialog(BuildContext context, FinanceProvider provider) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Expense Category'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Category Name *',
              hintText: 'e.g., VEHICLES, MARKETING',
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final cat = ExpenseCategoryEntity(
                id: const Uuid().v4(),
                name: nameCtrl.text.toUpperCase().trim(),
                createdAt: DateTime.now(),
              );
              provider.insertCategory(cat);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: FinDT.brand),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CATEGORY CARD WITH EXPANDABLE TYPES
// ═══════════════════════════════════════════════════════════════════════════════

class _CategoryExpansionCard extends StatelessWidget {
  final ExpenseCategoryEntity category;
  final FinanceProvider provider;

  const _CategoryExpansionCard({
    required this.category,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: FinDT.border),
      ),
      child: ExpansionTile(
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: FinDT.brand.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(Icons.folder_outlined, color: FinDT.brand, size: 18.sp),
            ),
            SizedBox(width: 12.w),
            Text(
              category.name,
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: FinDT.textPrimary,
              ),
            ),
            SizedBox(width: 8.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: FinDT.borderLight,
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text(
                '${category.expenseTypes.length} Types',
                style: GoogleFonts.inter(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                  color: FinDT.textSecondary,
                ),
              ),
            ),
          ],
        ),
        tilePadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        trailing: _buildActions(context),
        children: [
          Divider(height: 1, color: FinDT.borderLight),
          if (category.expenseTypes.isEmpty)
            Padding(
              padding: EdgeInsets.all(24.w),
              child: Center(
                child: Text(
                  'No expense types added to this category yet.',
                  style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textSecondary),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: category.expenseTypes.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: FinDT.borderLight),
              itemBuilder: (context, index) {
                final type = category.expenseTypes[index];
                return ListTile(
                  title: Text(
                    type.name,
                    style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Frequency: ${type.defaultDuration} | Submitted by: ${type.submittedByRole}',
                    style: GoogleFonts.inter(fontSize: 11.sp, color: FinDT.textSecondary),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _showTypeFormDialog(context, type: type),
                        icon: Icon(Icons.edit_outlined, size: 16.sp, color: FinDT.textSecondary),
                      ),
                      IconButton(
                        onPressed: () => _deleteType(context, type.id),
                        icon: Icon(Icons.delete_outline, size: 16.sp, color: FinDT.danger),
                      ),
                    ],
                  ),
                );
              },
            ),
          Divider(height: 1, color: FinDT.borderLight),
          Padding(
            padding: EdgeInsets.all(12.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showTypeFormDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Expense Type'),
                  style: TextButton.styleFrom(foregroundColor: FinDT.brand),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => _confirmDeleteCategory(context),
          icon: Icon(Icons.delete_outline, size: 18.sp, color: FinDT.danger),
        ),
      ],
    );
  }

  // ─── Type Dialog ──────────────────────────────────────────

  void _showTypeFormDialog(BuildContext context, {ExpenseTypeEntity? type}) {
    final isEditing = type != null;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: type?.name);
    String duration = type?.defaultDuration ?? 'MONTHLY';
    String role = type?.submittedByRole ?? 'ADMIN';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? 'Edit Expense Type' : 'Add Expense Type'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Type Name *',
                  hintText: 'e.g., fuel, electricity',
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              SizedBox(height: 12.h),
              DropdownButtonFormField<String>(
                value: duration,
                decoration: const InputDecoration(labelText: 'Default Frequency'),
                items: ['DAILY', 'WEEKLY', 'MONTHLY', 'QUARTERLY', 'YEARLY', 'ONE_TIME']
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (v) => duration = v ?? 'MONTHLY',
              ),
              SizedBox(height: 12.h),
              DropdownButtonFormField<String>(
                value: role,
                decoration: const InputDecoration(labelText: 'Who Submits This?'),
                items: ['ADMIN', 'COORDINATOR', 'DRIVER']
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => role = v ?? 'ADMIN',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final newType = ExpenseTypeEntity(
                id: isEditing ? type.id : const Uuid().v4(),
                name: nameCtrl.text.trim(),
                defaultDuration: duration,
                submittedByRole: role,
              );

              final updatedTypes = List<ExpenseTypeEntity>.from(category.expenseTypes);
              if (isEditing) {
                final idx = updatedTypes.indexWhere((t) => t.id == type.id);
                if (idx != -1) updatedTypes[idx] = newType;
              } else {
                updatedTypes.add(newType);
              }

              provider.updateCategory(category.copyWith(expenseTypes: updatedTypes));
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: FinDT.brand),
            child: Text(isEditing ? 'Save' : 'Add'),
          ),
        ],
      ),
    );
  }

  void _deleteType(BuildContext context, String typeId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense Type?'),
        content: const Text('This will remove this sub-type from the category list.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final updatedTypes =
                  category.expenseTypes.where((t) => t.id != typeId).toList();
              provider.updateCategory(category.copyWith(expenseTypes: updatedTypes));
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: FinDT.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCategory(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text(
          'Are you sure you want to delete the category "${category.name}" and all its sub-types?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              provider.deleteCategory(category.id);
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
