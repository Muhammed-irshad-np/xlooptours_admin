import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/fund_account_entity.dart';

/// A modern card displaying a fund account's balance and metadata.
///
/// Features a subtle gradient header, balance display, and account info.
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
    final colors = _accountColors(account.type);
    final formatter = NumberFormat('#,##0.00', 'en_US');

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
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
                  ? colors.primary.withValues(alpha: 0.15)
                  : const Color(0x0A000000),
              blurRadius: isSelected ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with gradient
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.primary.withValues(alpha: 0.08),
                    colors.primary.withValues(alpha: 0.03),
                  ],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(15.r),
                  topRight: Radius.circular(15.r),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(
                      colors.icon,
                      color: colors.primary,
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.name,
                          style: GoogleFonts.inter(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF111827),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          account.code,
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!account.isActive)
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        'Inactive',
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Balance section
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Balance',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${formatter.format(account.currentBalance)} ${account.currency}',
                    style: GoogleFonts.inter(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                      color: account.currentBalance >= 0
                          ? const Color(0xFF111827)
                          : const Color(0xFFDC2626),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (account.assignedTo != null) ...[
                    SizedBox(height: 10.h),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 14.sp,
                          color: const Color(0xFF9CA3AF),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          account.assignedTo!,
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _AccountColors _accountColors(FundAccountType type) {
    switch (type) {
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
          primary: const Color(0xFF6B7280),
          icon: Icons.folder_outlined,
        );
    }
  }
}

class _AccountColors {
  final Color primary;
  final IconData icon;

  const _AccountColors({required this.primary, required this.icon});
}
