import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

/// A detail row entry for the confirmation dialog.
///
/// Each entry represents a label-value pair that will be displayed
/// in the confirmation summary before saving.
class ConfirmDetailEntry {
  /// The label/title for this detail (e.g. "Name", "Phone", etc.)
  final String label;

  /// The value to display. Null or empty values are automatically skipped.
  final String? value;

  const ConfirmDetailEntry({required this.label, this.value});
}

/// A section header that groups related detail entries.
class ConfirmDetailSection {
  /// The section title (e.g. "Basic Info", "Documents", etc.)
  final String title;

  /// The icon to display next to the section title.
  final IconData icon;

  /// The detail entries in this section.
  final List<ConfirmDetailEntry> entries;

  const ConfirmDetailSection({
    required this.title,
    required this.icon,
    required this.entries,
  });
}

/// Shows a confirmation dialog before saving with a summary of entered details.
///
/// Returns `true` if the user confirms, `false` or `null` if cancelled.
///
/// [context] - The build context.
/// [title] - The dialog title (e.g. "Confirm Save Employee").
/// [sections] - Grouped detail sections to display in the summary.
/// [confirmButtonText] - Text for the confirm button (defaults to "Confirm & Save").
/// [entityName] - Optional entity name displayed at the top as a subtitle.
Future<bool?> showConfirmSaveDialog({
  required BuildContext context,
  required String title,
  required List<ConfirmDetailSection> sections,
  String confirmButtonText = 'Confirm & Save',
  String? entityName,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _ConfirmSaveDialog(
      title: title,
      sections: sections,
      confirmButtonText: confirmButtonText,
      entityName: entityName,
    ),
  );
}

class _ConfirmSaveDialog extends StatelessWidget {
  final String title;
  final List<ConfirmDetailSection> sections;
  final String confirmButtonText;
  final String? entityName;

  const _ConfirmSaveDialog({
    required this.title,
    required this.sections,
    required this.confirmButtonText,
    this.entityName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      titlePadding: EdgeInsets.zero,
      contentPadding: EdgeInsets.zero,
      actionsPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      title: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16.r),
            topRight: Radius.circular(16.r),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.checklist_rounded,
                  color: colorScheme.primary,
                  size: 24.sp,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 20.sp),
                  onPressed: () => Navigator.pop(context, false),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            if (entityName != null && entityName!.isNotEmpty) ...[
              SizedBox(height: 6.h),
              Text(
                entityName!,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ],
            SizedBox(height: 8.h),
            Text(
              'Please review the details below before saving.',
              style: TextStyle(
                fontSize: 12.sp,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520.w,
          maxHeight: MediaQuery.of(context).size.height * 0.55,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < sections.length; i++) ...[
                if (i > 0) SizedBox(height: 12.h),
                _buildSection(context, sections[i]),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: TextStyle(
              fontSize: 14.sp,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: Icon(Icons.check_circle_outline, size: 18.sp),
          label: Text(
            confirmButtonText,
            style: TextStyle(fontSize: 14.sp),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(BuildContext context, ConfirmDetailSection section) {
    // Filter out entries with null/empty values
    final validEntries = section.entries
        .where((e) => e.value != null && e.value!.trim().isNotEmpty)
        .toList();

    if (validEntries.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(section.icon, size: 16.sp, color: theme.colorScheme.primary),
            SizedBox(width: 6.w),
            Text(
              section.title,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              for (int i = 0; i < validEntries.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 12.h,
                    color: theme.dividerColor.withValues(alpha: 0.2),
                  ),
                _buildDetailRow(context, validEntries[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(BuildContext context, ConfirmDetailEntry entry) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120.w,
          child: Text(
            entry.label,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            entry.value ?? '',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

/// Helper to format a DateTime as a readable date string for the dialog.
String formatDateForConfirmation(DateTime? date) {
  if (date == null) return '';
  return DateFormat('dd MMM yyyy').format(date);
}
