import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../pages/finance_dashboard_page.dart';
import 'finance_dialog_helpers.dart';

/// One line of the summary shown before an expense is submitted.
class ExpenseConfirmRow {
  final String label;
  final String value;

  const ExpenseConfirmRow(this.label, this.value);
}

/// Shows what is about to be saved so the submitter can catch a wrong amount,
/// account or vehicle before it reaches the approval queue.
///
/// Rows with an empty value are skipped, so callers can pass optional fields
/// unconditionally. Resolves to true only when the user confirms.
Future<bool> showExpenseSubmitConfirmDialog({
  required BuildContext context,
  required double amount,
  required String currency,
  required List<ExpenseConfirmRow> rows,
  bool isEditing = false,
}) async {
  final visibleRows = rows.where((r) => r.value.trim().isNotEmpty).toList();
  final amountText = NumberFormat('#,##0.00', 'en_US').format(amount);

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: finDialogShape,
      title: finDialogTitle(
        isEditing ? 'Confirm Expense Update' : 'Confirm Expense',
        icon: Icons.fact_check_outlined,
        iconColor: FinDT.brand,
      ),
      content: SizedBox(
        width: 440.w,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please check the details below before submitting.',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  color: FinDT.textSecondary,
                ),
              ),
              SizedBox(height: 14.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
                decoration: BoxDecoration(
                  color: FinDT.brandLight,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Amount',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: FinDT.textSecondary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '$currency $amountText',
                      style: GoogleFonts.inter(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w800,
                        color: FinDT.brand,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: FinDT.border),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < visibleRows.length; i++)
                      _SummaryRow(
                        row: visibleRows[i],
                        showDivider: i < visibleRows.length - 1,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        finDialogCancelButton(ctx, label: 'Go Back & Edit'),
        finDialogActionButton(
          onPressed: () => finSafePop(ctx, true),
          label: isEditing ? 'Confirm & Update' : 'Confirm & Submit',
          icon: Icons.check_rounded,
        ),
      ],
    ),
  );
  return result == true;
}

class _SummaryRow extends StatelessWidget {
  final ExpenseConfirmRow row;
  final bool showDivider;

  const _SummaryRow({required this.row, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: FinDT.borderLight))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120.w,
            child: Text(
              row.label,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: FinDT.textSecondary,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              row.value,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: FinDT.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
