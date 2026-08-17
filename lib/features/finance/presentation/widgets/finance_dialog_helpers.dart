import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../pages/finance_dashboard_page.dart';

/// Modern decoration for all input and dropdown fields in Finance dialogs.
InputDecoration finDialogInputDecoration({
  required String label,
  String? hint,
  IconData? prefixIcon,
  String? suffixText,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: label,
    labelStyle: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textSecondary),
    hintText: hint,
    hintStyle: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textMuted),
    suffixText: suffixText,
    suffixStyle: GoogleFonts.inter(
      fontSize: 12.sp,
      fontWeight: FontWeight.w600,
      color: FinDT.textPrimary,
    ),
    suffixIcon: suffixIcon,
    prefixIcon: prefixIcon != null
        ? Icon(prefixIcon, size: 18.sp, color: FinDT.brand)
        : null,
    filled: true,
    fillColor: FinDT.bgPage,
    contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10.r),
      borderSide: const BorderSide(color: FinDT.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10.r),
      borderSide: const BorderSide(color: FinDT.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10.r),
      borderSide: const BorderSide(color: FinDT.brand, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10.r),
      borderSide: const BorderSide(color: FinDT.danger),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10.r),
      borderSide: const BorderSide(color: FinDT.danger, width: 1.5),
    ),
  );
}

/// Standard shape for all Finance dialogs.
RoundedRectangleBorder get finDialogShape => RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16.r),
    );

/// Standard dialog title widget.
Widget finDialogTitle(String title, {IconData? icon, Color? iconColor}) {
  if (icon == null) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 18.sp,
        fontWeight: FontWeight.w700,
        color: FinDT.textPrimary,
      ),
    );
  }

  final effectiveColor = iconColor ?? FinDT.brand;
  return Row(
    children: [
      Container(
        padding: EdgeInsets.all(8.w),
        decoration: BoxDecoration(
          color: effectiveColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Icon(icon, size: 20.sp, color: effectiveColor),
      ),
      SizedBox(width: 12.w),
      Expanded(
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
            color: FinDT.textPrimary,
          ),
        ),
      ),
    ],
  );
}

/// Safely dismisses a dialog or route without risk of concurrent pops or _debugLocked assertion errors.
void finSafePop(BuildContext context, [dynamic result]) {
  try {
    FocusManager.instance.primaryFocus?.unfocus();
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(result);
    }
  } catch (e) {
    debugPrint('finSafePop suppressed error: $e');
  }
}

/// Standard cancel button for dialogs with debouncing and safe pop guards.
Widget finDialogCancelButton(BuildContext context, {String label = 'Cancel', VoidCallback? onPressed}) {
  return _FinDialogCancelButton(
    label: label,
    onPressed: onPressed,
  );
}

class _FinDialogCancelButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;

  const _FinDialogCancelButton({
    required this.label,
    this.onPressed,
  });

  @override
  State<_FinDialogCancelButton> createState() => _FinDialogCancelButtonState();
}

class _FinDialogCancelButtonState extends State<_FinDialogCancelButton> {
  bool _isDismissed = false;

  void _handleCancel() {
    if (_isDismissed) return;
    _isDismissed = true;

    if (widget.onPressed != null) {
      widget.onPressed!();
      return;
    }

    finSafePop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: _isDismissed ? null : _handleCancel,
      child: Text(
        widget.label,
        style: GoogleFonts.inter(
          fontSize: 13.sp,
          fontWeight: FontWeight.w600,
          color: FinDT.textSecondary,
        ),
      ),
    );
  }
}

/// Standard action / confirm button for dialogs.
Widget finDialogActionButton({
  required VoidCallback? onPressed,
  required String label,
  Color backgroundColor = FinDT.brand,
  Color foregroundColor = Colors.white,
  bool isLoading = false,
  IconData? icon,
}) {
  return FilledButton(
    onPressed: isLoading ? null : onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.r),
      ),
      elevation: 0,
    ),
    child: isLoading
        ? SizedBox(
            width: 16.w,
            height: 16.h,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16.sp, color: foregroundColor),
                SizedBox(width: 6.w),
              ],
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
  );
}

/// Shows a modern, beautifully styled confirmation dialog.
Future<bool?> showFinConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? highlightNote,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  Color confirmColor = FinDT.brand,
  IconData icon = Icons.help_outline_rounded,
  Color? iconColor,
  Widget? customContent,
}) {
  final effectiveIconColor = iconColor ?? confirmColor;

  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: finDialogShape,
      title: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: effectiveIconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, size: 20.sp, color: effectiveIconColor),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: FinDT.textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                color: FinDT.textSecondary,
                height: 1.5,
              ),
            ),
            if (highlightNote != null) ...[
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: effectiveIconColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: effectiveIconColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18.sp,
                      color: effectiveIconColor,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        highlightNote,
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          color: effectiveIconColor,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (customContent != null) ...[
              SizedBox(height: 12.h),
              customContent,
            ],
          ],
        ),
      ),
      actions: [
        finDialogCancelButton(ctx, label: cancelLabel),
        finDialogActionButton(
          onPressed: () => Navigator.pop(ctx, true),
          label: confirmLabel,
          backgroundColor: confirmColor,
        ),
      ],
    ),
  );
}
