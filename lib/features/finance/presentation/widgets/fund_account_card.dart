import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/fund_account_entity.dart';

/// A modern, executive card displaying a fund account's balance and metadata.
class FundAccountCard extends StatelessWidget {
  final FundAccountEntity account;
  final bool isSelected;
  final VoidCallback? onTap;

  const FundAccountCard({
    super.key,
    required this.account,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _accountColors(account);
    final formatter = NumberFormat('#,##0.00', 'en_US');

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: isSelected ? colors.primary : const Color(0xFFE5E7EB),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? colors.primary.withValues(alpha: 0.18)
                    : const Color(0x08000000),
                blurRadius: isSelected ? 18 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header with accent gradient
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.primary.withValues(alpha: isSelected ? 0.12 : 0.07),
                        colors.primary.withValues(alpha: 0.02),
                      ],
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: colors.primary.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(7.w),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(9.r),
                        ),
                        child: Icon(
                          colors.icon,
                          color: colors.primary,
                          size: 16.sp,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              account.name,
                              style: GoogleFonts.inter(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF111827),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 1.h),
                            Text(
                              account.code,
                              style: GoogleFonts.inter(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Container(
                          padding: EdgeInsets.all(4.w),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 10.sp,
                          ),
                        )
                      else if (!account.isActive)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            'Inactive',
                            style: GoogleFonts.inter(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.09),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Text(
                            account.typeDisplayName,
                            style: GoogleFonts.inter(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w600,
                              color: colors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Balance & breakdown body
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CURRENT BALANCE',
                              style: GoogleFonts.inter(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                                color: const Color(0xFF9CA3AF),
                              ),
                            ),
                            SizedBox(height: 3.h),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  formatter.format(account.currentBalance),
                                  style: GoogleFonts.inter(
                                    fontSize: 17.sp,
                                    fontWeight: FontWeight.w800,
                                    color: account.currentBalance >= 0
                                        ? const Color(0xFF111827)
                                        : const Color(0xFFDC2626),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  account.currency,
                                  style: GoogleFonts.inter(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // If Petty Cash, show dual split breakdown
                        if (account.isPettyCash)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(color: const Color(0xFFF3F4F6)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(Icons.payments_outlined, size: 12.sp, color: const Color(0xFF16A34A)),
                                      SizedBox(width: 3.w),
                                      Flexible(
                                        child: Text(
                                          '${formatter.format(account.cashBalance)} SAR',
                                          style: GoogleFonts.inter(
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF1F2937),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(height: 12.h, width: 1, color: const Color(0xFFE5E7EB)),
                                SizedBox(width: 6.w),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(Icons.phone_android_outlined, size: 12.sp, color: const Color(0xFF7C3AED)),
                                      SizedBox(width: 3.w),
                                      Flexible(
                                        child: Text(
                                          '${formatter.format(account.stcPayBalance)} SAR',
                                          style: GoogleFonts.inter(
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF1F2937),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Card Footer: Coordinator Assigned Info
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFAFAFA),
                    border: Border(
                      top: BorderSide(color: Color(0xFFF3F4F6)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        size: 13.sp,
                        color: const Color(0xFF9CA3AF),
                      ),
                      SizedBox(width: 5.w),
                      Expanded(
                        child: Text(
                          (account.assignedTo != null && account.assignedTo!.isNotEmpty)
                              ? account.assignedTo!
                              : 'Unassigned',
                          style: GoogleFonts.inter(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w500,
                            color: (account.assignedTo != null && account.assignedTo!.isNotEmpty)
                                ? const Color(0xFF4B5563)
                                : const Color(0xFF9CA3AF),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 14.sp,
                        color: isSelected ? colors.primary : const Color(0xFFD1D5DB),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _AccountColors _accountColors(FundAccountEntity account) {
    if (account.isPettyCash) {
      return _AccountColors(
        primary: const Color(0xFF16A34A),
        icon: Icons.account_balance_wallet_outlined,
      );
    }
    if (account.isBank) {
      return _AccountColors(
        primary: const Color(0xFF0F766E),
        icon: Icons.account_balance_outlined,
      );
    }
    if (account.isStcPay) {
      return _AccountColors(
        primary: const Color(0xFF6D28D9),
        icon: Icons.phone_android_outlined,
      );
    }

    final lowerName = (account.accountTypeName ?? account.type.name).toLowerCase();
    if (lowerName.contains('driver')) {
      return _AccountColors(
        primary: const Color(0xFF2563EB),
        icon: Icons.drive_eta_outlined,
      );
    }
    if (lowerName.contains('tamkeen')) {
      return _AccountColors(
        primary: const Color(0xFF7C3AED),
        icon: Icons.business_center_outlined,
      );
    }
    if (lowerName.contains('fuel')) {
      return _AccountColors(
        primary: const Color(0xFFEA580C),
        icon: Icons.local_gas_station_outlined,
      );
    }
    if (lowerName.contains('admin')) {
      return _AccountColors(
        primary: const Color(0xFF0891B2),
        icon: Icons.admin_panel_settings_outlined,
      );
    }

    switch (account.type) {
      case FundAccountType.pettyCash:
        return _AccountColors(
          primary: const Color(0xFF16A34A),
          icon: Icons.account_balance_wallet_outlined,
        );
      case FundAccountType.driverAccount:
        return _AccountColors(
          primary: const Color(0xFF2563EB),
          icon: Icons.drive_eta_outlined,
        );
      case FundAccountType.tamkeen:
        return _AccountColors(
          primary: const Color(0xFF7C3AED),
          icon: Icons.business_center_outlined,
        );
      case FundAccountType.admin:
        return _AccountColors(
          primary: const Color(0xFF0891B2),
          icon: Icons.admin_panel_settings_outlined,
        );
      case FundAccountType.fuelCard:
        return _AccountColors(
          primary: const Color(0xFFEA580C),
          icon: Icons.local_gas_station_outlined,
        );
      case FundAccountType.stcPay:
        return _AccountColors(
          primary: const Color(0xFF6D28D9),
          icon: Icons.phone_android_outlined,
        );
      case FundAccountType.bank:
        return _AccountColors(
          primary: const Color(0xFF0F766E),
          icon: Icons.account_balance_outlined,
        );
      case FundAccountType.other:
        return _AccountColors(
          primary: const Color(0xFF4F46E5),
          icon: Icons.account_balance_wallet_outlined,
        );
    }
  }
}

class _AccountColors {
  final Color primary;
  final IconData icon;

  const _AccountColors({required this.primary, required this.icon});
}
