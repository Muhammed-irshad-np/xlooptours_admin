import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Summary metric card for the finance dashboard.
class ExpenseSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const ExpenseSummaryCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(18.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(icon, size: 20.sp, color: color),
                ),
                if (onTap != null)
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12.sp,
                    color: const Color(0xFF9CA3AF),
                  ),
              ],
            ),
            SizedBox(height: 14.h),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 24.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: const Color(0xFF6B7280),
              ),
            ),
            if (subtitle != null) ...[
              SizedBox(height: 2.h),
              Text(
                subtitle!,
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
