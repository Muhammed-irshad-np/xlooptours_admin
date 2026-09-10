import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_entity.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_status.dart';

import '../../domain/entities/work_order_entity.dart';
import '../pages/work_order_detail_page.dart';
import '../pages/work_order_form_page.dart';
import '../providers/work_order_provider.dart';
import 'report_issue_dialog.dart';
import 'work_order_status_badge.dart';

/// Maintenance status and work order history for one vehicle.
///
/// Drop-in for the vehicle detail screen: it answers "is this car at the
/// workshop right now, and what has been done to it" without the reader
/// having to go to the work order board.
class VehicleWorkOrdersSection extends StatefulWidget {
  final VehicleEntity vehicle;

  const VehicleWorkOrdersSection({super.key, required this.vehicle});

  @override
  State<VehicleWorkOrdersSection> createState() =>
      _VehicleWorkOrdersSectionState();
}

class _VehicleWorkOrdersSectionState extends State<VehicleWorkOrdersSection> {
  List<WorkOrderEntity> _workOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final provider = context.read<WorkOrderProvider>();
    final items = await provider.fetchForVehicle(widget.vehicle.id);
    if (!mounted) return;
    setState(() {
      _workOrders = items;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final occupying =
        _workOrders.where((w) => w.occupiesVehicle).firstOrNull;
    final open = _workOrders.where((w) => w.isOpen).toList();
    final recent = _workOrders.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (occupying != null || VehicleStatus.isInShop(widget.vehicle.status))
          _buildInShopBanner(occupying),
        SizedBox(height: 12.h),
        Row(
          children: [
            Text(
              'Maintenance Work Orders',
              style: GoogleFonts.inter(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
            if (open.isNotEmpty) ...[
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  '${open.length} open',
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
            const Spacer(),
            TextButton.icon(
              onPressed: _reportProblem,
              icon: Icon(Icons.report_problem_outlined, size: 15.sp),
              label: Text(
                'Report problem',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _newWorkOrder,
              icon: Icon(Icons.add, size: 15.sp),
              label: Text(
                'New',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        if (_isLoading)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: const Center(child: CircularProgressIndicator()),
          )
        else if (recent.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Text(
              'No work orders for this vehicle yet.',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: const Color(0xFF9CA3AF),
              ),
            ),
          )
        else
          ...recent.map(_buildRow),
      ],
    );
  }

  Widget _buildInShopBanner(WorkOrderEntity? workOrder) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.build_circle_outlined,
            size: 22.sp,
            color: const Color(0xFF2563EB),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This vehicle is in maintenance',
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E40AF),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  workOrder != null
                      ? '${workOrder.workOrderNumber} · ${workOrder.lineSummary}'
                        '${workOrder.shopName != null ? ' at ${workOrder.shopName}' : ''}'
                      : 'Marked ${VehicleStatus.inShop} with no open work order.',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: const Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
          if (workOrder != null)
            TextButton(
              onPressed: () => _openDetail(workOrder),
              child: Text(
                'View',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRow(WorkOrderEntity workOrder) {
    return InkWell(
      onTap: () => _openDetail(workOrder),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        workOrder.workOrderNumber,
                        style: GoogleFonts.robotoMono(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      WorkOrderStatusBadge(
                        status: workOrder.status,
                        compact: true,
                      ),
                    ],
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    workOrder.lineSummary,
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  Text(
                    DateFormat('MMM dd, yyyy').format(workOrder.createdAt),
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${workOrder.displayTotal.toStringAsFixed(2)} '
              '${workOrder.currency}',
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18.sp,
              color: const Color(0xFFD1D5DB),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDetail(WorkOrderEntity workOrder) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkOrderDetailPage(workOrderId: workOrder.id),
      ),
    );
    await _load();
  }

  Future<void> _reportProblem() async {
    final created = await ReportIssueDialog.show(
      context,
      vehicle: widget.vehicle,
    );
    if (created != null) await _load();
  }

  Future<void> _newWorkOrder() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WorkOrderFormPage(initialVehicle: widget.vehicle),
      ),
    );
    if (created == true) await _load();
  }
}
