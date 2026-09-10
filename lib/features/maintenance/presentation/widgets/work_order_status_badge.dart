import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/entities/work_order_status.dart';

/// Pill-shaped status badge, matching `ExpenseStatusBadge` so a work order
/// and the expense it becomes read as the same family of object.
class WorkOrderStatusBadge extends StatelessWidget {
  final WorkOrderStatus status;
  final double? fontSize;
  final bool compact;

  const WorkOrderStatusBadge({
    super.key,
    required this.status,
    this.fontSize,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = configFor(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8.w : 10.w,
        vertical: 4.h,
      ),
      decoration: BoxDecoration(
        color: config.bg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: config.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.w,
            height: 6.w,
            decoration: BoxDecoration(color: config.dot, shape: BoxShape.circle),
          ),
          SizedBox(width: 6.w),
          Text(
            compact ? status.shortLabel : status.displayName,
            style: GoogleFonts.inter(
              fontSize: fontSize ?? 11.sp,
              fontWeight: FontWeight.w600,
              color: config.text,
            ),
          ),
        ],
      ),
    );
  }

  static WorkOrderStatusColors configFor(WorkOrderStatus status) {
    switch (status) {
      case WorkOrderStatus.reported:
        return const WorkOrderStatusColors(
          bg: Color(0xFFF8FAFC),
          border: Color(0xFFE2E8F0),
          dot: Color(0xFF64748B),
          text: Color(0xFF334155),
        );
      case WorkOrderStatus.pendingApproval:
        return const WorkOrderStatusColors(
          bg: Color(0xFFFFFBEB),
          border: Color(0xFFFDE68A),
          dot: Color(0xFFD97706),
          text: Color(0xFF92400E),
        );
      case WorkOrderStatus.approved:
        return const WorkOrderStatusColors(
          bg: Color(0xFFECFDF5),
          border: Color(0xFFA7F3D0),
          dot: Color(0xFF059669),
          text: Color(0xFF065F46),
        );
      case WorkOrderStatus.inProgress:
        return const WorkOrderStatusColors(
          bg: Color(0xFFEFF6FF),
          border: Color(0xFFBFDBFE),
          dot: Color(0xFF2563EB),
          text: Color(0xFF1E40AF),
        );
      case WorkOrderStatus.onHold:
        return const WorkOrderStatusColors(
          bg: Color(0xFFFFF7ED),
          border: Color(0xFFFED7AA),
          dot: Color(0xFFEA580C),
          text: Color(0xFF9A3412),
        );
      case WorkOrderStatus.completed:
        return const WorkOrderStatusColors(
          bg: Color(0xFFF0F9FF),
          border: Color(0xFFBAE6FD),
          dot: Color(0xFF0284C7),
          text: Color(0xFF075985),
        );
      case WorkOrderStatus.closed:
        return const WorkOrderStatusColors(
          bg: Color(0xFFF0FDF4),
          border: Color(0xFFBBF7D0),
          dot: Color(0xFF16A34A),
          text: Color(0xFF166534),
        );
      case WorkOrderStatus.rejected:
        return const WorkOrderStatusColors(
          bg: Color(0xFFFFF1F2),
          border: Color(0xFFFFCDD2),
          dot: Color(0xFFDC2626),
          text: Color(0xFF991B1B),
        );
      case WorkOrderStatus.cancelled:
        return const WorkOrderStatusColors(
          bg: Color(0xFFF3F4F6),
          border: Color(0xFFE5E7EB),
          dot: Color(0xFF6B7280),
          text: Color(0xFF374151),
        );
    }
  }
}

class WorkOrderStatusColors {
  final Color bg;
  final Color border;
  final Color dot;
  final Color text;

  const WorkOrderStatusColors({
    required this.bg,
    required this.border,
    required this.dot,
    required this.text,
  });
}

/// Small flag shown only for urgent work — deliberately quiet for normal and
/// low priority so it keeps meaning when it does appear.
class WorkOrderPriorityFlag extends StatelessWidget {
  final WorkOrderPriority priority;

  const WorkOrderPriorityFlag({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    if (!priority.isUrgent) return const SizedBox.shrink();
    final isDown = priority == WorkOrderPriority.vehicleDown;
    final color = isDown ? const Color(0xFFDC2626) : const Color(0xFFEA580C);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDown ? Icons.car_crash_outlined : Icons.priority_high_rounded,
            size: 12.sp,
            color: color,
          ),
          SizedBox(width: 3.w),
          Text(
            priority.displayName,
            style: GoogleFonts.inter(
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// The "In Maintenance" tag shown against a vehicle anywhere in the fleet UI.
///
/// This is the vehicle-side half of the work order flow: while a job is in
/// progress the vehicle carries [VehicleStatus.inShop] and every list that
/// shows vehicles surfaces this chip.
class InMaintenanceChip extends StatelessWidget {
  /// Work order number to name, when known.
  final String? workOrderNumber;
  final bool compact;

  const InMaintenanceChip({
    super.key,
    this.workOrderNumber,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF2563EB);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6.w : 9.w,
        vertical: 3.h,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.build_circle_outlined, size: 12.sp, color: color),
          SizedBox(width: 4.w),
          Text(
            compact
                ? 'In Shop'
                : (workOrderNumber != null
                    ? 'In Maintenance · $workOrderNumber'
                    : 'In Maintenance'),
            style: GoogleFonts.inter(
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E40AF),
            ),
          ),
        ],
      ),
    );
  }
}
