import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:xloop_invoice/features/finance/domain/entities/expense_category_entity.dart';
import 'package:xloop_invoice/features/finance/presentation/providers/finance_provider.dart';

/// Settings page for configuring top-level expense categories
/// and sub-types (e.g., fuel, car wash, salary, etc.).
class ExpenseCategoriesPage extends StatefulWidget {
  const ExpenseCategoriesPage({super.key});

  @override
  State<ExpenseCategoriesPage> createState() => _ExpenseCategoriesPageState();
}

class _ExpenseCategoriesPageState extends State<ExpenseCategoriesPage> {
  String? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceProvider>(
      builder: (context, fp, _) {
        final categories = fp.categories;
        final selectedCategory = _selectedCategoryId != null
            ? categories.firstWhere((c) => c.id == _selectedCategoryId, orElse: () => ExpenseCategoryEntity.empty())
            : categories.isNotEmpty
                ? categories.first
                : null;

        if (_selectedCategoryId == null && selectedCategory != null) {
          _selectedCategoryId = selectedCategory.id;
        }

        return Row(
          children: [
            // Left Panel — List of Categories
            Expanded(
              flex: 2,
              child: Container(
                color: const Color(0xFFF9FAFB),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(20.w),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Categories',
                            style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w700, color: const Color(0xFF111827)),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _showAddCategoryDialog(context, fp),
                            icon: const Icon(Icons.add, size: 16),
                            label: Text('Add', style: GoogleFonts.inter(fontSize: 12.sp)),
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
                      child: fp.isCategoriesLoading
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
                          : ListView.builder(
                              padding: EdgeInsets.symmetric(horizontal: 20.w),
                              itemCount: categories.length,
                              itemBuilder: (ctx, index) {
                                final category = categories[index];
                                final isSelected = category.id == _selectedCategoryId;
                                return Card(
                                  margin: EdgeInsets.only(bottom: 12.h),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.r),
                                    side: BorderSide(
                                      color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE5E7EB),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: ListTile(
                                    title: Text(
                                      category.name,
                                      style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text(
                                      '${category.expenseTypes.length} Types',
                                      style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF6B7280)),
                                    ),
                                    trailing: isSelected
                                        ? const Icon(Icons.chevron_right, color: Color(0xFF10B981))
                                        : null,
                                    onTap: () {
                                      setState(() {
                                        _selectedCategoryId = category.id;
                                      });
                                    },
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
            // Right Panel — Sub-types & Details
            Expanded(
              flex: 3,
              child: Container(
                color: Colors.white,
                child: selectedCategory == null || selectedCategory.id.isEmpty
                    ? Center(
                        child: Text(
                          'Select or create category to configure',
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
                                Text(
                                  '${selectedCategory.name} Types',
                                  style: GoogleFonts.inter(fontSize: 18.sp, fontWeight: FontWeight.w700),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _showAddTypeDialog(context, fp, selectedCategory),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Add Type'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 24.h),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: selectedCategory.expenseTypes.length,
                              separatorBuilder: (_, __) => const Divider(color: Color(0xFFE5E7EB)),
                              itemBuilder: (ctx, index) {
                                final t = selectedCategory.expenseTypes[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Row(
                                    children: [
                                      Text(
                                        t.name,
                                        style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w600),
                                      ),
                                      SizedBox(width: 8.w),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEEF2F6),
                                          borderRadius: BorderRadius.circular(4.r),
                                        ),
                                        child: Text(
                                          t.priority,
                                          style: GoogleFonts.inter(fontSize: 9.sp, fontWeight: FontWeight.w700, color: const Color(0xFF4F46E5)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    'Recurrence: ${t.defaultDuration} • Submitter: ${t.submittedByRole}\nDefault Amount: ${t.defaultAmount != null ? '${t.defaultAmount} SAR' : 'Variable'}',
                                    style: GoogleFonts.inter(fontSize: 12.sp, color: const Color(0xFF6B7280)),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () {
                                      // Remove this type and update category
                                      final updatedTypes = List<ExpenseTypeEntity>.from(selectedCategory.expenseTypes)
                                        ..removeAt(index);
                                      fp.updateCategory(selectedCategory.copyWith(expenseTypes: updatedTypes));
                                    },
                                  ),
                                );
                              },
                            ),
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

  void _showAddCategoryDialog(BuildContext context, FinanceProvider fp) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
        title: Text('Create Category', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Category Name (e.g., VEHICLES, EMPLOYEES)',
              style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: const Color(0xFF374151)),
            ),
            SizedBox(height: 6.h),
            TextField(
              controller: nameController,
              style: GoogleFonts.inter(fontSize: 13.sp),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              final newCat = ExpenseCategoryEntity(
                id: const Uuid().v4(),
                name: nameController.text.trim().toUpperCase(),
                createdAt: DateTime.now(),
              );
              fp.insertCategory(newCat);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            child: Text('Create', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showAddTypeDialog(BuildContext context, FinanceProvider fp, ExpenseCategoryEntity category) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    String recurrence = 'MONTHLY';
    String priority = 'MANDATORY';
    String submittedByRole = 'ADMIN';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
        title: Text('Add Expense Type', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogTextField(nameController, 'Type Name', validator: (v) => v!.isEmpty ? 'Enter name' : null),
                SizedBox(height: 12.h),
                _buildDropdownField<String>(
                  label: 'Default Recurrence',
                  value: recurrence,
                  items: const [
                    DropdownMenuItem(value: 'DAILY', child: Text('Daily')),
                    DropdownMenuItem(value: 'WEEKLY', child: Text('Weekly')),
                    DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')),
                    DropdownMenuItem(value: 'YEARLY', child: Text('Yearly')),
                    DropdownMenuItem(value: 'ONE_TIME', child: Text('One Time')),
                  ],
                  onChanged: (v) {
                    if (v != null) recurrence = v;
                  },
                ),
                SizedBox(height: 12.h),
                _buildDropdownField<String>(
                  label: 'Priority',
                  value: priority,
                  items: const [
                    DropdownMenuItem(value: 'MANDATORY', child: Text('Mandatory')),
                    DropdownMenuItem(value: 'IF_REQUIRED', child: Text('If Required')),
                  ],
                  onChanged: (v) {
                    if (v != null) priority = v;
                  },
                ),
                SizedBox(height: 12.h),
                _buildDropdownField<String>(
                  label: 'Who Submits It?',
                  value: submittedByRole,
                  items: const [
                    DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                    DropdownMenuItem(value: 'COORDINATOR', child: Text('Coordinator')),
                    DropdownMenuItem(value: 'DRIVER', child: Text('Driver')),
                  ],
                  onChanged: (v) {
                    if (v != null) submittedByRole = v;
                  },
                ),
                SizedBox(height: 12.h),
                _buildDialogTextField(
                  amountController,
                  'Default Expected Amount (Optional)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
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
              final double? amount = double.tryParse(amountController.text);
              final newType = ExpenseTypeEntity(
                id: const Uuid().v4(),
                name: nameController.text.trim(),
                defaultDuration: recurrence,
                priority: priority,
                submittedByRole: submittedByRole,
                defaultAmount: amount,
              );
              final updatedTypes = List<ExpenseTypeEntity>.from(category.expenseTypes)..add(newType);
              fp.updateCategory(category.copyWith(expenseTypes: updatedTypes));
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            child: Text('Add Type', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogTextField(
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
