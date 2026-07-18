import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Navigation tabs for the finance module with animated underline.
///
/// Uses a scrollable tab bar to prevent RenderFlex overflow on narrow viewports.
class FinanceNavTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const FinanceNavTabs({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
  });

  static const _tabs = [
    _TabData(icon: Icons.dashboard_outlined, label: 'Overview'),
    _TabData(icon: Icons.receipt_long_outlined, label: 'Expenses'),
    _TabData(icon: Icons.account_balance_wallet_outlined, label: 'Accounts'),
    _TabData(icon: Icons.book_outlined, label: 'Petty Cash'),
    _TabData(icon: Icons.category_outlined, label: 'Categories'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_tabs.length, (index) {
            final isSelected = selectedIndex == index;
            final tab = _tabs[index];
            return GestureDetector(
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                margin: EdgeInsets.symmetric(horizontal: 2.w),
                padding: EdgeInsets.symmetric(
                  vertical: 10.h,
                  horizontal: 14.w,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10.r),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0x14000000),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tab.icon,
                      size: 15.sp,
                      color: isSelected
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFF9CA3AF),
                    ),
                    SizedBox(width: 5.w),
                    Text(
                      tab.label,
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? const Color(0xFF111827)
                            : const Color(0xFF6B7280),
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
}

class _TabData {
  final IconData icon;
  final String label;
  const _TabData({required this.icon, required this.label});
}
