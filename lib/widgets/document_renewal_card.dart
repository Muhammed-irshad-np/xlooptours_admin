import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../features/employee/domain/entities/document_renewal_entity.dart';
import '../screens/document_viewer_screen.dart';

/// Icon and colour per document, matching the Documents & IDs cards.
(IconData, Color) documentRenewalStyle(String documentType) {
  switch (documentType) {
    case 'Iqama':
      return (Icons.badge, Colors.teal);
    case 'Bahrain Residence ID':
      return (Icons.badge, Colors.red);
    case 'Passport':
      return (Icons.book, Colors.indigo);
    case 'Driving License':
      return (Icons.drive_eta, Colors.blue);
    case 'Saudi Visa':
      return (Icons.airplane_ticket, Colors.green);
    case 'Bahrain Visa':
      return (Icons.airplane_ticket, Colors.redAccent);
    case 'Dubai Visa':
      return (Icons.airplane_ticket, Colors.amber.shade800);
    case 'Qatar Visa':
      return (Icons.airplane_ticket, Colors.purple);
    case 'Health Insurance':
      return (Icons.health_and_safety, Colors.pink);
    case 'Authorization':
      return (Icons.security, Colors.deepPurple);
    default:
      return (Icons.description, Colors.blueGrey);
  }
}

/// One renewal: the document, old → new expiry, and who renewed it when.
class DocumentRenewalCard extends StatelessWidget {
  final DocumentRenewalEntity renewal;

  const DocumentRenewalCard({super.key, required this.renewal});

  String _date(DateTime d) => DateFormat('MMM dd, yyyy').format(d);

  @override
  Widget build(BuildContext context) {
    final (icon, color) = documentRenewalStyle(renewal.documentType);
    final renewedOn = DateFormat('MMM dd, yyyy · hh:mm a')
        .format(renewal.renewedAt);
    final by = renewal.renewedBy?.trim();
    final oldScan = renewal.previousAttachmentUrl;
    final hasOldScan = oldScan != null &&
        oldScan.isNotEmpty &&
        oldScan != renewal.newAttachmentUrl;

    return Card(
      elevation: 1,
      margin: EdgeInsets.only(bottom: 10.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(icon, color: color, size: 22.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    renewal.documentType,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if ((renewal.newNumber ?? '').isNotEmpty) ...[
                    SizedBox(height: 2.h),
                    Text(
                      renewal.numberChanged
                          ? 'No: ${renewal.previousNumber} → ${renewal.newNumber}'
                          : 'No: ${renewal.newNumber}',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                  SizedBox(height: 8.h),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6.w,
                    runSpacing: 4.h,
                    children: [
                      Icon(
                        Icons.event_outlined,
                        size: 14.sp,
                        color: Colors.grey[500],
                      ),
                      Text(
                        _date(renewal.previousExpiryDate),
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Colors.grey[600],
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward,
                        size: 14.sp,
                        color: Colors.grey[500],
                      ),
                      Text(
                        _date(renewal.newExpiryDate),
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    by == null || by.isEmpty
                        ? 'Renewed $renewedOn'
                        : 'Renewed $renewedOn by $by',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                  ),
                  if (hasOldScan)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: Icon(Icons.history_edu, size: 16.sp),
                        label: const Text('View previous copy'),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DocumentViewerScreen(
                              attachmentUrl: oldScan,
                              title:
                                  '${renewal.documentType} (expired ${_date(renewal.previousExpiryDate)})',
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
