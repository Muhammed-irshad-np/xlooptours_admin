import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../core/widgets/modern_app_bar.dart';
import '../features/employee/domain/entities/document_renewal_entity.dart';
import '../features/employee/domain/entities/employee_entity.dart';
import '../features/employee/presentation/providers/employee_provider.dart';
import '../widgets/document_renewal_card.dart';

/// Every recorded renewal for one employee, filterable by document and year.
class DocumentRenewalHistoryScreen extends StatefulWidget {
  final EmployeeEntity employee;

  /// Document to filter on when the screen opens; null shows every document.
  final String? initialDocumentType;

  const DocumentRenewalHistoryScreen({
    super.key,
    required this.employee,
    this.initialDocumentType,
  });

  @override
  State<DocumentRenewalHistoryScreen> createState() =>
      _DocumentRenewalHistoryScreenState();
}

class _DocumentRenewalHistoryScreenState
    extends State<DocumentRenewalHistoryScreen> {
  /// Null shows every document / every year.
  String? _documentType;
  int? _year;
  bool _newestFirst = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _documentType = widget.initialDocumentType;
    final provider = context.read<EmployeeProvider>();
    if (provider.renewalsFor(widget.employee.id) == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
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
    final all = context.watch<EmployeeProvider>().renewalsFor(
      widget.employee.id,
    );

    return Scaffold(
      appBar: ModernAppBar(title: 'Renewals: ${widget.employee.fullName}'),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: _failed
              ? _centered(
                  'Could not load renewal history.',
                  action: TextButton(
                    onPressed: _load,
                    child: const Text('Retry'),
                  ),
                )
              : all == null
              ? const Center(child: CircularProgressIndicator(strokeWidth: 3))
              : RefreshIndicator(onRefresh: _load, child: _content(all)),
        ),
      ),
    );
  }

  Widget _content(List<DocumentRenewalEntity> all) {
    // Counts per document follow the year filter, and the year list follows
    // the document filter, so every chip tells you what tapping it will show.
    final inYear = _year == null
        ? all
        : all.where((r) => r.renewedAt.year == _year).toList();
    final ofType = _documentType == null
        ? all
        : all.where((r) => r.documentType == _documentType).toList();

    final typeCounts = <String, int>{};
    for (final r in inYear) {
      typeCounts[r.documentType] = (typeCounts[r.documentType] ?? 0) + 1;
    }
    final types = {...all.map((r) => r.documentType)}.toList()..sort();
    final years = {...ofType.map((r) => r.renewedAt.year)}.toList()
      ..sort((a, b) => b.compareTo(a));

    final shown = inYear
        .where((r) => _documentType == null || r.documentType == _documentType)
        .toList()
      ..sort(
        (a, b) => _newestFirst
            ? b.renewedAt.compareTo(a.renewedAt)
            : a.renewedAt.compareTo(b.renewedAt),
      );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(16.w),
      children: [
        Text(
          'Document',
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: [
            ChoiceChip(
              label: Text('All (${inYear.length})'),
              selected: _documentType == null,
              onSelected: (_) => setState(() => _documentType = null),
            ),
            ...types.map((t) {
              final (icon, color) = documentRenewalStyle(t);
              return ChoiceChip(
                avatar: Icon(icon, size: 16.sp, color: color),
                label: Text('$t (${typeCounts[t] ?? 0})'),
                selected: _documentType == t,
                onSelected: (_) => setState(() => _documentType = t),
              );
            }),
          ],
        ),
        SizedBox(height: 16.h),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int?>(
                // Rebuilt on change so "Clear filters" resets the field too.
                key: ValueKey(_year),
                initialValue: years.contains(_year) ? _year : null,
                decoration: const InputDecoration(
                  labelText: 'Renewed in',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('All years'),
                  ),
                  ...years.map(
                    (y) => DropdownMenuItem<int?>(value: y, child: Text('$y')),
                  ),
                ],
                onChanged: (y) => setState(() => _year = y),
              ),
            ),
            SizedBox(width: 12.w),
            OutlinedButton.icon(
              onPressed: () => setState(() => _newestFirst = !_newestFirst),
              icon: Icon(
                _newestFirst ? Icons.arrow_downward : Icons.arrow_upward,
                size: 18.sp,
              ),
              label: Text(_newestFirst ? 'Newest first' : 'Oldest first'),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        Row(
          children: [
            Expanded(
              child: Text(
                '${shown.length} renewal${shown.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[900],
                ),
              ),
            ),
            if (_documentType != null || _year != null)
              TextButton(
                onPressed: () => setState(() {
                  _documentType = null;
                  _year = null;
                }),
                child: const Text('Clear filters'),
              ),
          ],
        ),
        SizedBox(height: 8.h),
        if (shown.isEmpty)
          Padding(
            padding: EdgeInsets.all(24.w),
            child: Text(
              all.isEmpty
                  ? 'No renewals recorded yet.'
                  : 'No renewals match these filters.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
            ),
          )
        else
          ...shown.map((r) => DocumentRenewalCard(renewal: r)),
      ],
    );
  }

  Widget _centered(String text, {Widget? action}) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
