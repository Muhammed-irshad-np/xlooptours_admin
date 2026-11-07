import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../features/employee/domain/entities/employee_entity.dart';
import '../features/employee/presentation/providers/employee_provider.dart';
import '../screens/document_renewal_history_screen.dart';
import 'document_renewal_card.dart';

/// Latest document renewals on the employee details screen, in the same
/// style as the Tafweed history: five newest, then "View All History".
class DocumentRenewalHistorySection extends StatefulWidget {
  final EmployeeEntity employee;

  const DocumentRenewalHistorySection({super.key, required this.employee});

  @override
  State<DocumentRenewalHistorySection> createState() =>
      _DocumentRenewalHistorySectionState();
}

class _DocumentRenewalHistorySectionState
    extends State<DocumentRenewalHistorySection> {
  static const _previewCount = 5;
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
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...renewals
              .take(_previewCount)
              .map((r) => DocumentRenewalCard(renewal: r)),
          if (renewals.length > _previewCount)
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DocumentRenewalHistoryScreen(
                      employee: widget.employee,
                    ),
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.teal[700],
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    side: BorderSide(
                      color: Colors.teal.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: Text('View All History (${renewals.length})'),
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
