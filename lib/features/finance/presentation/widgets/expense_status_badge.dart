import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:xloop_invoice/features/finance/domain/entities/expense_entity.dart';

/// Color-coded status badge for expense approval status.
class ExpenseStatusBadge extends StatelessWidget {
  final ExpenseStatus status;
  final double? fontSize;

  const ExpenseStatusBadge({
    super.key,
    required this.status,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final config = _statusConfig(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: config.bgColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: config.borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.w,
            height: 6.w,
            decoration: BoxDecoration(
              color: config.dotColor,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 6.w),
          Text(
            status.displayName,
            style: GoogleFonts.inter(
              fontSize: fontSize ?? 11.sp,
              fontWeight: FontWeight.w600,
              color: config.textColor,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeConfig _statusConfig(ExpenseStatus status) {
    switch (status) {
      case ExpenseStatus.pending:
        return _BadgeConfig(
          bgColor: const Color(0xFFFFF7ED),
          borderColor: const Color(0xFFFED7AA),
          dotColor: const Color(0xFFF59E0B),
          textColor: const Color(0xFF92400E),
        );
      case ExpenseStatus.approved:
        return _BadgeConfig(
          bgColor: const Color(0xFFF0FDF4),
          borderColor: const Color(0xFFBBF7D0),
          dotColor: const Color(0xFF22C55E),
          textColor: const Color(0xFF166534),
        );
      case ExpenseStatus.rejected:
        return _BadgeConfig(
          bgColor: const Color(0xFFFFF1F2),
          borderColor: const Color(0xFFFFCDD2),
          dotColor: const Color(0xFFEF4444),
          textColor: const Color(0xFF991B1B),
        );
      case ExpenseStatus.closed:
        return _BadgeConfig(
          bgColor: const Color(0xFFF3F4F6),
          borderColor: const Color(0xFFD1D5DB),
          dotColor: const Color(0xFF6B7280),
          textColor: const Color(0xFF374151),
        );
    }
  }
}

class _BadgeConfig {
  final Color bgColor;
  final Color borderColor;
  final Color dotColor;
  final Color textColor;

  _BadgeConfig({
    required this.bgColor,
    required this.borderColor,
    required this.dotColor,
    required this.textColor,
  });
}
