import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:xloop_invoice/core/widgets/modern_app_bar.dart';
import 'package:xloop_invoice/features/auth/presentation/providers/auth_provider.dart';
import 'package:xloop_invoice/features/finance/presentation/providers/finance_provider.dart';
import 'package:xloop_invoice/features/vehicle/presentation/providers/vehicle_provider.dart';
import 'package:xloop_invoice/widgets/responsive_layout.dart';

import '../../domain/entities/work_order_entity.dart';
import '../../domain/entities/work_order_status.dart';
import '../../domain/services/work_order_transition_service.dart';
import '../providers/work_order_provider.dart';
import '../widgets/work_order_card.dart';
import 'work_order_detail_page.dart';
import 'work_order_form_page.dart';

/// The one screen for maintenance work.
///
/// Three lanes — *Needs your action*, *In progress*, *Done* — where the first
/// is computed per user from [WorkOrderTransitionService]. A coordinator sees
/// reports to cost and completed jobs to close; a manager sees approvals.
/// Nobody has to learn the state machine: whatever is in the first lane is
/// theirs to deal with.
class WorkOrderBoardPage extends StatefulWidget {
  const WorkOrderBoardPage({super.key});

  @override
  State<WorkOrderBoardPage> createState() => _WorkOrderBoardPageState();
}

class _WorkOrderBoardPageState extends State<WorkOrderBoardPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    if (!mounted) return;
    final vehicleProvider = context.read<VehicleProvider>();
    final financeProvider = context.read<FinanceProvider>();
    await Future.wait<dynamic>([
      context.read<WorkOrderProvider>().fetchWorkOrders(force: force),
      if (vehicleProvider.vehicles.isEmpty) vehicleProvider.fetchAllVehicles(),
      if (vehicleProvider.maintenanceTypes.isEmpty)
        vehicleProvider.fetchAllMaintenanceTypes(),
      if (vehicleProvider.shops.isEmpty) vehicleProvider.fetchAllShops(),
      financeProvider.fetchFinancePolicy(),
      if (financeProvider.categories.isEmpty)
        financeProvider.fetchCategories(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkOrderProvider>();
    final user = context.watch<AuthProvider>().user;
    final policy = context.watch<FinanceProvider>().policy;
    final lanes = provider.lanesFor(user: user, policy: policy);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: ModernAppBar(
        title: 'Work Orders',
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: Colors.black54),
            onPressed: () => _load(force: true),
          ),
          SizedBox(width: 8.w),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewWorkOrder,
        backgroundColor: const Color(0xFF2563EB),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'New Work Order',
          style: GoogleFonts.inter(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(force: true),
        child: Column(
          children: [
            _buildToolbar(provider),
            if (provider.isLoading && provider.workOrders.isEmpty)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: ResponsiveLayout(
                  mobile: _buildStackedLanes(lanes),
                  desktop: _buildColumnLanes(lanes),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Toolbar ─────────────────────────────────────────────────

  Widget _buildToolbar(WorkOrderProvider provider) {
    final vehicles = context.watch<VehicleProvider>().vehicles;
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40.h,
                  child: TextField(
                    controller: _searchController,
                    onChanged: provider.setSearchQuery,
                    style: GoogleFonts.inter(fontSize: 13.sp),
                    decoration: InputDecoration(
                      hintText: 'Search plate, WO number, complaint…',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 13.sp,
                        color: const Color(0xFF9CA3AF),
                      ),
                      prefixIcon: Icon(Icons.search, size: 18.sp),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12.w),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              _FilterChipToggle(
                label: 'Mine only',
                selected: provider.mineOnly,
                onChanged: provider.setMineOnly,
              ),
              SizedBox(width: 8.w),
              _FilterChipToggle(
                label: 'Show closed',
                selected: provider.showClosed,
                onChanged: provider.setShowClosed,
              ),
            ],
          ),
          SizedBox(height: 10.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StatusFilterChip(
                  label: 'All statuses',
                  selected: provider.statusFilter == null,
                  onTap: () => provider.setStatusFilter(null),
                ),
                for (final status in WorkOrderStatus.values)
                  Padding(
                    padding: EdgeInsets.only(left: 6.w),
                    child: _StatusFilterChip(
                      label: status.displayName,
                      selected: provider.statusFilter == status,
                      onTap: () => provider.setStatusFilter(
                        provider.statusFilter == status ? null : status,
                      ),
                    ),
                  ),
                SizedBox(width: 12.w),
                if (vehicles.isNotEmpty)
                  SizedBox(
                    width: 190.w,
                    height: 34.h,
                    child: DropdownButtonFormField<String?>(
                      initialValue: provider.vehicleFilter,
                      isExpanded: true,
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: Colors.black87,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 8.h,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      hint: Text(
                        'All vehicles',
                        style: GoogleFonts.inter(fontSize: 12.sp),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            'All vehicles',
                            style: GoogleFonts.inter(fontSize: 12.sp),
                          ),
                        ),
                        ...vehicles.map(
                          (v) => DropdownMenuItem<String?>(
                            value: v.id,
                            child: Text(
                              v.plateNumber,
                              style: GoogleFonts.inter(fontSize: 12.sp),
                            ),
                          ),
                        ),
                      ],
                      onChanged: provider.setVehicleFilter,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Lanes ───────────────────────────────────────────────────

  Widget _buildColumnLanes(Map<WorkOrderLane, List<WorkOrderEntity>> lanes) {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final lane in WorkOrderLane.values) ...[
            Expanded(child: _buildLaneColumn(lane, lanes[lane] ?? const [])),
            if (lane != WorkOrderLane.done) SizedBox(width: 14.w),
          ],
        ],
      ),
    );
  }

  Widget _buildLaneColumn(WorkOrderLane lane, List<WorkOrderEntity> items) {
    return Container(
      decoration: BoxDecoration(
        color: lane == WorkOrderLane.needsAction
            ? const Color(0xFFF0F6FF)
            : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: lane == WorkOrderLane.needsAction
              ? const Color(0xFFDBEAFE)
              : const Color(0xFFE5E7EB),
        ),
      ),
      padding: EdgeInsets.all(10.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _laneHeader(lane, items.length),
          SizedBox(height: 10.h),
          Expanded(
            child: items.isEmpty
                ? _emptyLane(lane)
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => SizedBox(height: 10.h),
                    itemBuilder: (context, i) => WorkOrderCard(
                      workOrder: items[i],
                      needsAction: lane == WorkOrderLane.needsAction,
                      onTap: () => _openDetail(items[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStackedLanes(Map<WorkOrderLane, List<WorkOrderEntity>> lanes) {
    final sections = <Widget>[];
    for (final lane in WorkOrderLane.values) {
      final items = lanes[lane] ?? const [];
      if (items.isEmpty && lane == WorkOrderLane.done) continue;
      sections.add(
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
          child: _laneHeader(lane, items.length),
        ),
      );
      if (items.isEmpty) {
        sections.add(
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: _emptyLane(lane),
          ),
        );
      } else {
        sections.addAll(
          items.map(
            (wo) => Padding(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 10.h),
              child: WorkOrderCard(
                workOrder: wo,
                needsAction: lane == WorkOrderLane.needsAction,
                onTap: () => _openDetail(wo),
              ),
            ),
          ),
        );
      }
    }
    return ListView(
      padding: EdgeInsets.only(bottom: 90.h),
      children: sections,
    );
  }

  Widget _laneHeader(WorkOrderLane lane, int count) {
    return Row(
      children: [
        Text(
          lane.title,
          style: GoogleFonts.inter(
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF374151),
          ),
        ),
        SizedBox(width: 6.w),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: lane == WorkOrderLane.needsAction
                ? const Color(0xFF2563EB)
                : const Color(0xFF9CA3AF),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.inter(
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyLane(WorkOrderLane lane) {
    final message = switch (lane) {
      WorkOrderLane.needsAction => 'Nothing waiting on you.',
      WorkOrderLane.inProgress => 'No jobs running.',
      WorkOrderLane.done => 'Nothing closed yet.',
    };
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 24.h),
      child: Center(
        child: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 12.sp,
            color: const Color(0xFF9CA3AF),
          ),
        ),
      ),
    );
  }

  // ─── Navigation ──────────────────────────────────────────────

  Future<void> _openDetail(WorkOrderEntity workOrder) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkOrderDetailPage(workOrderId: workOrder.id),
      ),
    );
  }

  Future<void> _openNewWorkOrder() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const WorkOrderFormPage()),
    );
    if (created == true && mounted) {
      await _load(force: true);
    }
  }
}

class _FilterChipToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;

  const _FilterChipToggle({
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: selected ? const Color(0xFF1E40AF) : const Color(0xFF6B7280),
        ),
      ),
      selected: selected,
      onSelected: onChanged,
      showCheckmark: false,
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFFEFF6FF),
      side: BorderSide(
        color: selected ? const Color(0xFFBFDBFE) : const Color(0xFFE5E7EB),
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StatusFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: selected ? const Color(0xFF111827) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}
