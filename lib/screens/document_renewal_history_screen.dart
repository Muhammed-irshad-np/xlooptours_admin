import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../core/widgets/modern_app_bar.dart';
import '../features/employee/domain/entities/employee_entity.dart';
import '../features/employee/presentation/providers/employee_provider.dart';
import '../widgets/document_renewal_card.dart';

/// Every recorded renewal for one employee, filterable by document.
class DocumentRenewalHistoryScreen extends StatefulWidget {
  final EmployeeEntity employee;

  const DocumentRenewalHistoryScreen({super.key, required this.employee});

  @override
  State<DocumentRenewalHistoryScreen> createState() =>
      _DocumentRenewalHistoryScreenState();
}

class _DocumentRenewalHistoryScreenState
    extends State<DocumentRenewalHistoryScreen> {
  /// Null shows every document.
  String? _documentType;

  @override
  Widget build(BuildContext context) {
    final renewals =
        context.watch<EmployeeProvider>().renewalsFor(widget.employee.id) ??
        const [];
    final types = renewals.map((r) => r.documentType).toSet().toList()
      ..sort();
    final shown = _documentType == null
        ? renewals
        : renewals.where((r) => r.documentType == _documentType).toList();

    return Scaffold(
      appBar: ModernAppBar(
        title: 'Renewal History: ${widget.employee.fullName}',
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: EdgeInsets.all(16.w),
            children: [
              if (types.length > 1)
                Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: [
                      ChoiceChip(
                        label: Text('All (${renewals.length})'),
                        selected: _documentType == null,
                        onSelected: (_) => setState(() => _documentType = null),
                      ),
                      ...types.map(
                        (t) => ChoiceChip(
                          label: Text(t),
                          selected: _documentType == t,
                          onSelected: (_) =>
                              setState(() => _documentType = t),
                        ),
                      ),
                    ],
                  ),
                ),
              if (shown.isEmpty)
                Padding(
                  padding: EdgeInsets.all(24.w),
                  child: Text(
                    'No renewals recorded yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
                  ),
                )
              else
                ...shown.map((r) => DocumentRenewalCard(renewal: r)),
            ],
          ),
        ),
      ),
    );
  }
}
