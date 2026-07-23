import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/expense_entity.dart';

/// A modern, pill-shaped status badge for expense status.
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
        color: config.bg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: config.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.w,
            height: 6.w,
            decoration: BoxDecoration(
              color: config.dot,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 6.w),
          Text(
            status.displayName,
            style: GoogleFonts.inter(
              fontSize: fontSize ?? 11.sp,
              fontWeight: FontWeight.w600,
              color: config.text,
            ),
          ),
        ],
      ),
    );
  }

  _StatusConfig _statusConfig(ExpenseStatus status) {
    switch (status) {
      case ExpenseStatus.draft:
        return _StatusConfig(
          bg: const Color(0xFFF8FAFC),
          border: const Color(0xFFE2E8F0),
          dot: const Color(0xFF94A3B8),
          text: const Color(0xFF475569),
        );
      case ExpenseStatus.pending:
        return _StatusConfig(
          bg: const Color(0xFFFFFBEB),
          border: const Color(0xFFFDE68A),
          dot: const Color(0xFFD97706),
          text: const Color(0xFF92400E),
        );
      case ExpenseStatus.approved:
        return _StatusConfig(
          bg: const Color(0xFFECFDF5),
          border: const Color(0xFFA7F3D0),
          dot: const Color(0xFF059669),
          text: const Color(0xFF065F46),
        );
      case ExpenseStatus.paid:
        return _StatusConfig(
          bg: const Color(0xFFF0FDF4),
          border: const Color(0xFFBBF7D0),
          dot: const Color(0xFF16A34A),
          text: const Color(0xFF166534),
        );
      case ExpenseStatus.rejected:
        return _StatusConfig(
          bg: const Color(0xFFFFF1F2),
          border: const Color(0xFFFFCDD2),
          dot: const Color(0xFFDC2626),
          text: const Color(0xFF991B1B),
        );
      case ExpenseStatus.voided:
        return _StatusConfig(
          bg: const Color(0xFFF5F3FF),
          border: const Color(0xFFDDD6FE),
          dot: const Color(0xFF7C3AED),
          text: const Color(0xFF5B21B6),
        );
      case ExpenseStatus.closed:
        return _StatusConfig(
          bg: const Color(0xFFF3F4F6),
          border: const Color(0xFFE5E7EB),
          dot: const Color(0xFF6B7280),
          text: const Color(0xFF374151),
        );
    }
  }
}

class _StatusConfig {
  final Color bg;
  final Color border;
  final Color dot;
  final Color text;

  const _StatusConfig({
    required this.bg,
    required this.border,
    required this.dot,
    required this.text,
  });
}
