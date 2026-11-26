import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// The tabs of the finance module, in display order.
enum FinanceTab {
  overview(Icons.dashboard_outlined, 'Overview'),
  expenses(Icons.receipt_long_outlined, 'Expenses'),
  accounts(Icons.account_balance_wallet_outlined, 'Accounts'),
  pettyCash(Icons.book_outlined, 'Petty Cash'),
  advances(Icons.payments_outlined, 'Advances'),
  salaries(Icons.badge_outlined, 'Salaries'),
  reports(Icons.assessment_outlined, 'Reports', adminOnly: true),
  masterData(Icons.dns_outlined, 'Master Data', adminOnly: true);

  const FinanceTab(this.icon, this.label, {this.adminOnly = false});

  final IconData icon;
  final String label;

  /// Shown to Admin / Super Admin only.
  final bool adminOnly;

  /// The tabs a user sees: all of them for admins, the rest otherwise.
  static List<FinanceTab> visibleTo({required bool isAdmin}) =>
      values.where((t) => isAdmin || !t.adminOnly).toList();
}

/// Clean inline navigation tabs for the finance module.
class FinanceNavTabs extends StatelessWidget {
  /// The tabs to show, in order.
  final List<FinanceTab> tabs;
  final FinanceTab selected;
  final ValueChanged<FinanceTab> onChanged;

  const FinanceNavTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
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
            children: tabs.map((tab) {
              final isSelected = selected == tab;
              return InkWell(
                onTap: () => onChanged(tab),
                borderRadius: BorderRadius.circular(8.r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  margin: EdgeInsets.symmetric(horizontal: 2.w),
                  padding: EdgeInsets.symmetric(
                    vertical: 8.h,
                    horizontal: 16.w,
                  ),
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
                        tab.icon,
                        size: 16.sp,
                        color: isSelected
                            ? const Color(0xFF4F46E5)
                            : const Color(0xFF6B7280),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        tab.label,
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
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
            }).toList(),
          ),
        ),
      ),
    );
  }
}

