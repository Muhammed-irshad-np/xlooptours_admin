import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/work_order_entity.dart';
import '../../domain/entities/work_order_status.dart';
import 'work_order_status_badge.dart';

/// One work order in the board list.
///
/// Shows the four things you decide on at a glance: which vehicle, what
/// work, how much, and how long it has been sitting there.
class WorkOrderCard extends StatelessWidget {
  final WorkOrderEntity workOrder;
  final VoidCallback onTap;

  /// Highlights the card when it is waiting on the current user.
  final bool needsAction;

  const WorkOrderCard({
    super.key,
    required this.workOrder,
    required this.onTap,
    this.needsAction = false,
  });

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(
      symbol: '',
      decimalDigits: 2,
    );
    final isActual = workOrder.status == WorkOrderStatus.completed ||
        workOrder.status == WorkOrderStatus.closed;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: needsAction
                ? const Color(0xFFBFDBFE)
                : const Color(0xFFE5E7EB),
            width: needsAction ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    workOrder.vehiclePlate,
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                WorkOrderStatusBadge(status: workOrder.status, compact: true),
              ],
            ),
            SizedBox(height: 2.h),
            Text(
              workOrder.workOrderNumber,
              style: GoogleFonts.robotoMono(
                fontSize: 10.sp,
                color: const Color(0xFF9CA3AF),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              workOrder.lineSummary,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (workOrder.complaint.isNotEmpty) ...[
              SizedBox(height: 3.h),
              Text(
                workOrder.complaint,
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  color: const Color(0xFF6B7280),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            SizedBox(height: 10.h),
            Row(
              children: [
                Text(
                  '${isActual ? '' : '~'}${money.format(workOrder.displayTotal)} '
                  '${workOrder.currency}',
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: workOrder.hasOverrun
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF111827),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.schedule_rounded,
                  size: 12.sp,
                  color: const Color(0xFF9CA3AF),
                ),
                SizedBox(width: 3.w),
                Text(
                  _age(workOrder.ageInDays),
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
            if (workOrder.priority.isUrgent ||
                (workOrder.shopName?.isNotEmpty ?? false)) ...[
              SizedBox(height: 8.h),
              Wrap(
                spacing: 6.w,
                runSpacing: 4.h,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  WorkOrderPriorityFlag(priority: workOrder.priority),
                  if (workOrder.shopName?.isNotEmpty ?? false)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.storefront_outlined,
                          size: 11.sp,
                          color: const Color(0xFF9CA3AF),
                        ),
                        SizedBox(width: 3.w),
                        Text(
                          workOrder.shopName!,
                          style: GoogleFonts.inter(
                            fontSize: 10.sp,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _age(int days) {
    if (days <= 0) return 'Today';
    if (days == 1) return '1 day';
    return '$days days';
  }
}
