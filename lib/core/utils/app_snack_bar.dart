import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Centralized snackbar utility that displays standardized, top-positioned
/// floating toast notifications across the entire application.
///
/// Uses Flutter's [Overlay] API instead of [ScaffoldMessenger] so that
/// notifications always render **on top of** dialogs, bottom sheets,
/// and any other modal surfaces.
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

  /// Tracks the currently visible overlay entry so we can dismiss it
  /// before showing a new one (prevents stacking).
  static OverlayEntry? _currentEntry;

  /// Shows a success toast (green) with a check icon.
  static void showSuccess(BuildContext context, String message) {
    _show(
      context,
      message: message,
      backgroundColor: const Color(0xFF2E7D32),
      icon: Icons.check_circle_rounded,
    );
  }

  /// Shows an error toast (red) with an error icon.
  static void showError(BuildContext context, String message) {
    _show(
      context,
      message: message,
      backgroundColor: const Color(0xFFC62828),
      icon: Icons.error_rounded,
    );
  }

  /// Shows a warning toast (orange) with a warning icon.
  static void showWarning(BuildContext context, String message) {
    _show(
      context,
      message: message,
      backgroundColor: const Color(0xFFE65100),
      icon: Icons.warning_rounded,
    );
  }

  /// Shows an info toast (blue) with an info icon.
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
    // Remove any currently visible toast first
    _dismiss();

    final overlay = Overlay.of(context, rootOverlay: true);

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _AppSnackBarOverlay(
        message: message,
        backgroundColor: backgroundColor,
        icon: icon,
        duration: duration,
        onDismiss: () {
          if (_currentEntry == entry) {
            _dismiss();
          }
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }

  /// Programmatically dismiss the current toast.
  static void _dismiss() {
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

/// Internal animated overlay widget that handles the slide-in/out animation,
/// auto-dismiss timer, and manual close button.
class _AppSnackBarOverlay extends StatefulWidget {
  const _AppSnackBarOverlay({
    required this.message,
    required this.backgroundColor,
    required this.icon,
    required this.duration,
    required this.onDismiss,
  });

  final String message;
  final Color backgroundColor;
  final IconData icon;
  final Duration duration;
  final VoidCallback onDismiss;

  @override
  State<_AppSnackBarOverlay> createState() => _AppSnackBarOverlayState();
}

class _AppSnackBarOverlayState extends State<_AppSnackBarOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 200),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    // Auto-dismiss after duration
    Future.delayed(widget.duration, _animateOut);
  }

  Future<void> _animateOut() async {
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) {
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Positioned(
      top: mediaQuery.padding.top + 12.h,
      right: 16.w,
      // Constrain width: at most 45% of screen, at least 280
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: (mediaQuery.size.width * 0.45).clamp(280.0, 500.0),
        ),
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, color: Colors.white, size: 20.sp),
                    SizedBox(width: 10.w),
                    Flexible(
                      child: Text(
                        widget.message,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    GestureDetector(
                      onTap: _animateOut,
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                        size: 18.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
