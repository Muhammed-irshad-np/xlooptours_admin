import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:xloop_invoice/features/finance/domain/entities/fund_account_entity.dart';

/// Card widget displaying a fund account with balance and type icon.
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
    final config = _typeConfig(account.type);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isSelected ? config.color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: isSelected ? config.color : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
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
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: config.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(config.icon, size: 20.sp, color: config.color),
                ),
                SizedBox(width: 10.w),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        account.code,
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!account.isActive)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Text(
                      'Inactive',
                      style: GoogleFonts.inter(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 14.h),
            Text(
              '${account.currentBalance.toStringAsFixed(2)} ${account.currency}',
              style: GoogleFonts.inter(
                fontSize: 22.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
            SizedBox(height: 4.h),
            if (account.assignedTo != null)
              Row(
                children: [
                  Icon(Icons.person_outline, size: 13.sp, color: const Color(0xFF9CA3AF)),
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
        ),
      ),
    );
  }

  _TypeConfig _typeConfig(FundAccountType type) {
    switch (type) {
      case FundAccountType.pettyCash:
        return _TypeConfig(icon: Icons.account_balance_wallet, color: const Color(0xFF10B981));
      case FundAccountType.driverAccount:
        return _TypeConfig(icon: Icons.local_taxi, color: const Color(0xFF3B82F6));
      case FundAccountType.tamkeen:
        return _TypeConfig(icon: Icons.business, color: const Color(0xFF8B5CF6));
      case FundAccountType.admin:
        return _TypeConfig(icon: Icons.admin_panel_settings, color: const Color(0xFFF59E0B));
      case FundAccountType.fuelCard:
        return _TypeConfig(icon: Icons.local_gas_station, color: const Color(0xFFEF4444));
      case FundAccountType.stcPay:
        return _TypeConfig(icon: Icons.phone_android, color: const Color(0xFF6366F1));
      case FundAccountType.bank:
        return _TypeConfig(icon: Icons.account_balance, color: const Color(0xFF0EA5E9));
      case FundAccountType.other:
        return _TypeConfig(icon: Icons.more_horiz, color: const Color(0xFF6B7280));
    }
  }
}

class _TypeConfig {
  final IconData icon;
  final Color color;
  _TypeConfig({required this.icon, required this.color});
}
