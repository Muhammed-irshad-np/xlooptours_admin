import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Asks the user to confirm before leaving a form whose fields were edited.
///
/// [fields] lists every value the user can edit. [TextEditingController]s and
/// [ValueListenable]s are read for their current value; lists are compared
/// element by element; anything else is compared with `==`. The values at the
/// first build are the baseline, so a form that fills itself asynchronously
/// (e.g. after fetching master data) calls [UnsavedChangesGuardState.markClean]
/// once it has finished loading.
///
/// Only back navigation (app bar back button, system back, `maybePop`) is
/// intercepted. `Navigator.pop` after a successful save leaves without asking.
class UnsavedChangesGuard extends StatefulWidget {
  const UnsavedChangesGuard({
    super.key,
    required this.fields,
    required this.child,
    this.enabled = true,
  });

  final List<Object?> Function() fields;
  final Widget child;

  /// When false the page pops freely, e.g. when its data is kept as a draft.
  final bool enabled;

  @override
  State<UnsavedChangesGuard> createState() => UnsavedChangesGuardState();
}

class UnsavedChangesGuardState extends State<UnsavedChangesGuard> {
  late List<Object?> _baseline;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _baseline = _snapshot();
  }

  /// Treats the current field values as saved.
  void markClean() => _baseline = _snapshot();

  bool get isDirty => !_equals(_baseline, _snapshot());

  List<Object?> _snapshot() => _read(widget.fields()) as List<Object?>;

  static Object? _read(Object? value) {
    if (value is TextEditingController) return value.text;
    if (value is ValueListenable) return _read(value.value);
    if (value is Iterable) return value.map(_read).toList();
    return value;
  }

  static bool _equals(Object? a, Object? b) {
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_equals(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }

  Future<void> _onPopInvoked(bool didPop, Object? result) async {
    if (didPop || _confirming) return;
    if (isDirty) {
      _confirming = true;
      final discard = await showDiscardChangesDialog(context);
      _confirming = false;
      if (discard != true) return;
    }
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !widget.enabled,
      onPopInvokedWithResult: _onPopInvoked,
      child: widget.child,
    );
  }
}

/// Returns true when the user chooses to leave and lose their edits.
Future<bool?> showDiscardChangesDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final colorScheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 24.sp,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                'Discard unsaved changes?',
                style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'You have unsaved changes on this page. If you go back now, '
          'they will be lost.',
          style: TextStyle(fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Keep Editing',
              style: TextStyle(fontSize: 14.sp),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            child: Text('Discard', style: TextStyle(fontSize: 14.sp)),
          ),
        ],
      );
    },
  );
}
