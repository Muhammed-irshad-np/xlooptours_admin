import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Modern currency display with flag emoji and formatted amount.
class CurrencyDisplay extends StatelessWidget {
  final double amount;
  final String currency;
  final double? fontSize;
  final FontWeight? fontWeight;
  final Color? color;
  final bool showFlag;
  final bool compact;

  const CurrencyDisplay({
    super.key,
    required this.amount,
    this.currency = 'SAR',
    this.fontSize,
    this.fontWeight,
    this.color,
    this.showFlag = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = compact
        ? NumberFormat.compact(locale: 'en_US')
        : NumberFormat('#,##0.00', 'en_US');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showFlag) ...[
          Text(
            _flagEmoji(currency),
            style: TextStyle(fontSize: (fontSize ?? 14.sp) - 2),
          ),
          SizedBox(width: 4.w),
        ],
        Text(
          '${formatter.format(amount)} $currency',
          style: GoogleFonts.inter(
            fontSize: fontSize ?? 14.sp,
            fontWeight: fontWeight ?? FontWeight.w600,
            color: color ?? const Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  String _flagEmoji(String currency) {
    switch (currency.toUpperCase()) {
      case 'SAR':
        return '🇸🇦';
      case 'BHD':
        return '🇧🇭';
      case 'AED':
        return '🇦🇪';
      case 'QAR':
        return '🇶🇦';
      case 'USD':
        return '🇺🇸';
      default:
        return '💰';
    }
  }
}
