import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../features/employee/domain/entities/document_renewal_entity.dart';
import '../features/employee/domain/entities/employee_entity.dart';
import '../features/employee/presentation/providers/employee_provider.dart';
import '../screens/document_renewal_history_screen.dart';
import 'document_renewal_card.dart';

/// Renewal summary on the employee details screen: one row per document
/// with its renewal count. Tapping a row, or "View All Renewals", opens
/// [DocumentRenewalHistoryScreen] with filters.
class DocumentRenewalHistorySection extends StatefulWidget {
  final EmployeeEntity employee;

  const DocumentRenewalHistorySection({super.key, required this.employee});

  @override
  State<DocumentRenewalHistorySection> createState() =>
      _DocumentRenewalHistorySectionState();
}

class _DocumentRenewalHistorySectionState
    extends State<DocumentRenewalHistorySection> {
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      await context.read<EmployeeProvider>().fetchDocumentRenewals(
        widget.employee.id,
      );
      if (mounted && _failed) setState(() => _failed = false);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final renewals = context.watch<EmployeeProvider>().renewalsFor(
      widget.employee.id,
    );

    final Widget body;
    if (_failed) {
      body = _message(
        'Could not load renewal history.',
        action: TextButton(onPressed: _load, child: const Text('Retry')),
      );
    } else if (renewals == null) {
      body = Padding(
        padding: EdgeInsets.all(20.w),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 3)),
      );
    } else if (renewals.isEmpty) {
      body = _message(
        'No renewals recorded yet. Renewing an Iqama, visa or any other '
        'document will be listed here.',
      );
    } else {
      // One row per document, newest renewal first; each opens the full
      // renewals screen already filtered to that document.
      final byType = <String, List<DocumentRenewalEntity>>{};
      for (final r in renewals) {
        byType.putIfAbsent(r.documentType, () => []).add(r);
      }
      final groups = byType.entries.toList()
        ..sort(
          (a, b) => b.value.first.renewedAt.compareTo(a.value.first.renewedAt),
        );

      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 2,
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              children: [
                for (var i = 0; i < groups.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: Colors.grey[200]),
                  _summaryTile(groups[i].key, groups[i].value),
                ],
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: 12.h),
            child: TextButton.icon(
              onPressed: () => _openScreen(null),
              icon: const Icon(Icons.filter_list),
              label: Text('View All Renewals (${renewals.length})'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.teal[700],
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  side: BorderSide(color: Colors.teal.withValues(alpha: 0.2)),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 24.h),
        Padding(
          padding: EdgeInsets.only(bottom: 12.h, left: 4.w),
          child: Row(
            children: [
              Icon(Icons.history, color: Colors.teal[700], size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                'Document Renewal History',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
            ],
          ),
        ),
        body,
      ],
    );
  }

  void _openScreen(String? documentType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentRenewalHistoryScreen(
          employee: widget.employee,
          initialDocumentType: documentType,
        ),
      ),
    );
  }

  /// [renewals] is newest first, so the first one is the latest renewal.
  Widget _summaryTile(String type, List<DocumentRenewalEntity> renewals) {
    final (icon, color) = documentRenewalStyle(type);
    final latest = renewals.first;
    final count = renewals.length;
    return ListTile(
      onTap: () => _openScreen(type),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      leading: Container(
        padding: EdgeInsets.all(8.w),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Icon(icon, color: color, size: 22.sp),
      ),
      title: Text(
        type,
        style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        'Last renewed ${_date(latest.renewedAt)} · '
        'expiry now ${_date(latest.newExpiryDate)}',
        style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Text(
              '$count renewal${count == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey[500]),
        ],
      ),
    );
  }

  String _date(DateTime d) => DateFormat('MMM dd, yyyy').format(d);

  Widget _message(String text, {Widget? action}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
            ),
            if (action != null) action,
          ],
        ),
      ),
    );
  }
}
