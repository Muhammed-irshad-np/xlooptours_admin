import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Centralized snackbar utility that displays standardized, top-positioned
/// floating snackbars across the entire application.
///
/// Usage:
/// ```dart
/// AppSnackBar.showSuccess(context, 'Item saved successfully');
/// AppSnackBar.showError(context, 'Failed to save item');
/// AppSnackBar.showWarning(context, 'Only admins can perform this action');
/// AppSnackBar.showInfo(context, 'Processing your request...');
/// ```
class AppSnackBar {
  AppSnackBar._(); // Prevent instantiation

  /// Shows a success snackbar (green) with a check icon.
  static void showSuccess(BuildContext context, String message) {
    _show(
      context,
      message: message,
      backgroundColor: const Color(0xFF2E7D32),
      icon: Icons.check_circle_rounded,
    );
  }

  /// Shows an error snackbar (red) with an error icon.
  static void showError(BuildContext context, String message) {
    _show(
      context,
      message: message,
      backgroundColor: const Color(0xFFC62828),
      icon: Icons.error_rounded,
    );
  }

  /// Shows a warning snackbar (orange) with a warning icon.
  static void showWarning(BuildContext context, String message) {
    _show(
      context,
      message: message,
      backgroundColor: const Color(0xFFE65100),
      icon: Icons.warning_rounded,
    );
  }

  /// Shows an info snackbar (blue) with an info icon.
  static void showInfo(BuildContext context, String message) {
    _show(
      context,
      message: message,
      backgroundColor: const Color(0xFF1565C0),
      icon: Icons.info_rounded,
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required Color backgroundColor,
    required IconData icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    // Clear any existing snackbar before showing a new one
    messenger.hideCurrentSnackBar();

    final mediaQuery = MediaQuery.of(context);

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
        duration: duration,
        // Push the snackbar to the top of the screen by using a large
        // bottom margin. This is the standard Flutter approach since
        // SnackBar doesn't natively support top positioning.
        margin: EdgeInsets.only(
          bottom: mediaQuery.size.height - mediaQuery.padding.top - 120.h,
          left: mediaQuery.size.width * 0.55,
          right: 16.w,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        dismissDirection: DismissDirection.up,
        showCloseIcon: true,
        closeIconColor: Colors.white70,
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20.sp),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
