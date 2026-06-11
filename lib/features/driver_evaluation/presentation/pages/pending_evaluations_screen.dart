import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:xloop_invoice/features/driver_evaluation/presentation/providers/admin_evaluation_provider.dart';
import 'package:xloop_invoice/features/driver_evaluation/presentation/pages/evaluation_detail_screen.dart';
import 'package:xloop_invoice/features/employee/presentation/providers/employee_provider.dart';
import 'package:xloop_invoice/features/vehicle/presentation/providers/vehicle_provider.dart';
import 'package:xloop_invoice/features/employee/domain/entities/employee_entity.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_entity.dart';
import 'package:xloop_invoice/core/utils/share_dialog.dart';
import 'package:xloop_invoice/features/driver_evaluation/domain/entities/evaluation_entity.dart';
import 'package:xloop_invoice/widgets/searchable_dropdown.dart';

class PendingEvaluationsScreen extends StatefulWidget {
  const PendingEvaluationsScreen({super.key});

  @override
  State<PendingEvaluationsScreen> createState() =>
      _PendingEvaluationsScreenState();
}

class _PendingEvaluationsScreenState extends State<PendingEvaluationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminEvaluationProvider>().loadPendingEvaluations();
      context.read<EmployeeProvider>().fetchAllEmployees();
      context.read<VehicleProvider>().fetchAllVehicles();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: AppBar(
        title: Text(
          'Driver Evaluations',
          style: TextStyle(
            fontSize: 22.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
            tooltip: 'Refresh evaluations',
            onPressed: () {
              context.read<AdminEvaluationProvider>().loadPendingEvaluations();
            },
          ),
          SizedBox(width: 16.w),
        ],
      ),
      body:
          Consumer3<AdminEvaluationProvider, EmployeeProvider, VehicleProvider>(
            builder:
                (
                  context,
                  adminProvider,
                  employeeProvider,
                  vehicleProvider,
                  child,
                ) {
                  if (adminProvider.isLoading &&
                      adminProvider.pendingEvaluations.isEmpty &&
                      adminProvider.evaluatedEvaluations.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (adminProvider.errorMessage != null &&
                      adminProvider.pendingEvaluations.isEmpty &&
                      adminProvider.evaluatedEvaluations.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48.r,
                            color: Colors.red,
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            'Error: ${adminProvider.errorMessage}',
                            style: TextStyle(
                              fontSize: 16.sp,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          SizedBox(height: 16.h),
                          ElevatedButton(
                            onPressed: () =>
                                adminProvider.loadPendingEvaluations(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: [
                      Container(
                        color: Colors.white,
                        child: TabBar(
                          controller: _tabController,
                          indicatorColor: const Color(0xFF13B1F2),
                          indicatorWeight: 3,
                          labelColor: const Color(0xFF13B1F2),
                          unselectedLabelColor: const Color(0xFF64748B),
                          labelStyle: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.sp,
                          ),
                          unselectedLabelStyle: GoogleFonts.inter(
                            fontWeight: FontWeight.w500,
                            fontSize: 14.sp,
                          ),
                          tabs: const [
                            Tab(text: 'Pending'),
                            Tab(text: 'Evaluated'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildEvaluationList(
                              adminProvider.pendingEvaluations,
                              employeeProvider.employees,
                              vehicleProvider.vehicles,
                              isPendingTab: true,
                            ),
                            _buildEvaluationList(
                              adminProvider.evaluatedEvaluations,
                              employeeProvider.employees,
                              vehicleProvider.vehicles,
                              isPendingTab: false,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showGenerateLinkDialog(context),
        backgroundColor: const Color(0xFF13B1F2),
        tooltip: 'Generate evaluation link',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEvaluationList(
    List<EvaluationEntity> evaluations,
    List<EmployeeEntity> employees,
    List<VehicleEntity> vehicles, {
    required bool isPendingTab,
  }) {
    if (evaluations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPendingTab
                  ? Icons.assignment_turned_in_outlined
                  : Icons.check_circle_outline,
              size: 64.r,
              color: const Color(0xFF94A3B8),
            ),
            SizedBox(height: 16.h),
            Text(
              isPendingTab
                  ? 'No pending evaluations found'
                  : 'No evaluated drivers found',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              isPendingTab
                  ? 'Generate a new link to send to a driver.'
                  : 'Completed evaluations will appear here.',
              style: TextStyle(fontSize: 14.sp, color: const Color(0xFF94A3B8)),
            ),
            if (isPendingTab) ...[
              SizedBox(height: 24.h),
              ElevatedButton.icon(
                onPressed: () => _showGenerateLinkDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Generate Evaluation Link'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.w,
                    vertical: 12.h,
                  ),
                  backgroundColor: const Color(0xFF13B1F2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(24.r),
      itemCount: evaluations.length,
      separatorBuilder: (_, __) => SizedBox(height: 16.h),
      itemBuilder: (context, index) {
        final evaluation = evaluations[index];
        final empIdx = employees.indexWhere((e) => e.id == evaluation.driverId);
        final employee = empIdx != -1 ? employees[empIdx] : null;

        VehicleEntity? vehicle;
        if (evaluation.vehicleId != null) {
          final vIdx = vehicles.indexWhere((v) => v.id == evaluation.vehicleId);
          if (vIdx != -1) {
            vehicle = vehicles[vIdx];
          }
        }

        return _EvaluationTile(
          evaluation: evaluation,
          employee: employee,
          vehicle: vehicle,
          onDelete: () => _showDeleteConfirmationDialog(
            context,
            evaluation.id,
            evaluation.driverName,
          ),
          onShare: () => _showShareDialog(
            context,
            evaluation.id,
            evaluation.driverName,
            employee: employee,
          ),
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(
    BuildContext context,
    String id,
    String driverName,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Delete Evaluation'),
          content: Text(
            'Are you sure you want to permanently delete the evaluation for $driverName?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogCtx); // Close dialog
                final provider = context.read<AdminEvaluationProvider>();
                final success = await provider.deleteEvaluation(id);
                if (context.mounted) {
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Evaluation deleted successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          provider.errorMessage ??
                              'Failed to delete evaluation',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showShareDialog(
    BuildContext context,
    String id,
    String driverName, {
    EmployeeEntity? employee,
  }) {
    final host = Uri.base.origin;
    final url = '$host/evaluate?id=$id';
    final message =
        'Hi $driverName,\n\nPlease fill out your driver evaluation form using this link:\n\n$url';

    showDialog(
      context: context,
      builder: (context) {
        return ShareDialog(
          url: url,
          title: 'Driver Evaluation Link',
          recipientName: driverName,
          recipientPhone: employee?.phoneNumber,
          recipientEmail: employee?.email,
          shareMessage: message,
        );
      },
    ).then((_) {
      if (context.mounted) {
        context.read<AdminEvaluationProvider>().loadPendingEvaluations();
      }
    });
  }

  void _showGenerateLinkDialog(BuildContext dialogCtx) {
    showDialog(
      context: dialogCtx,
      builder: (context) {
        EmployeeEntity? selectedEmployee;
        VehicleEntity? selectedVehicle;

        return StatefulBuilder(
          builder: (context, setState) {
            final employees = context.read<EmployeeProvider>().employees;
            final vehicles = context.read<VehicleProvider>().vehicles;

            return AlertDialog(
              title: const Text('Generate Evaluation Link'),
              content: SizedBox(
                width: 400.w,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SearchableDropdown<EmployeeEntity>(
                      labelText: 'Select Driver',
                      searchHint: 'Search driver by name…',
                      items: employees,
                      value: selectedEmployee,
                      itemToString: (emp) => emp.fullName,
                      onChanged: (val) {
                        setState(() {
                          selectedEmployee = val;
                        });
                      },
                    ),
                    SizedBox(height: 16.h),
                    SearchableDropdown<VehicleEntity>(
                      labelText: 'Select Vehicle (Optional)',
                      searchHint: 'Search vehicle make, model, or plate…',
                      items: vehicles,
                      value: selectedVehicle,
                      itemToString: (veh) =>
                          '${veh.make} ${veh.model} (${veh.plateNumber})',
                      onChanged: (val) {
                        setState(() {
                          selectedVehicle = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedEmployee == null
                      ? null
                      : () async {
                          final provider = dialogCtx
                              .read<AdminEvaluationProvider>();
                          final id = await provider.generateLink(
                            selectedEmployee!.id,
                            selectedEmployee!.fullName,
                            selectedVehicle?.id,
                          );

                          if (context.mounted) {
                            Navigator.pop(context); // Close inputs dialog
                            if (id != null) {
                              _showShareDialog(
                                dialogCtx,
                                id,
                                selectedEmployee!.fullName,
                                employee: selectedEmployee,
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF13B1F2),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Generate'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _EvaluationTile extends StatefulWidget {
  final EvaluationEntity evaluation;
  final EmployeeEntity? employee;
  final VehicleEntity? vehicle;
  final VoidCallback onDelete;
  final VoidCallback onShare;

  const _EvaluationTile({
    required this.evaluation,
    this.employee,
    this.vehicle,
    required this.onDelete,
    required this.onShare,
  });

  @override
  State<_EvaluationTile> createState() => _EvaluationTileState();
}

class _EvaluationTileState extends State<_EvaluationTile> {
  bool _isExpanded = false;

  double _calculateAvgRating() {
    if (widget.evaluation.scores == null) return 0.0;
    final app = widget.evaluation.scores!['appearance'] as int? ?? 0;
    final veh = widget.evaluation.scores!['vehicle'] as int? ?? 0;
    return (app + veh) / 2.0;
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.evaluation;
    final isSubmitted = e.submittedAt != null;
    final isEvaluated = e.status == 'evaluated';
    final hasPhotos = e.media.isNotEmpty;

    // Determine status badge color
    Color badgeBg;
    Color badgeBorder;
    Color badgeText;
    String statusLabel;

    if (isEvaluated) {
      final passed = e.scores?['passed'] as bool? ?? true;
      statusLabel = passed ? 'Passed' : 'Failed';
      badgeBg = passed ? const Color(0xFFECFDF5) : const Color(0xFFFEE2E2);
      badgeBorder = passed ? const Color(0xFFA7F3D0) : const Color(0xFFFCA5A5);
      badgeText = passed ? const Color(0xFF059669) : const Color(0xFFDC2626);
    } else {
      statusLabel = isSubmitted ? 'Submitted' : 'Pending Submission';
      badgeBg = isSubmitted ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7);
      badgeBorder = isSubmitted
          ? const Color(0xFFA7F3D0)
          : const Color(0xFFFDE68A);
      badgeText = isSubmitted
          ? const Color(0xFF059669)
          : const Color(0xFFD97706);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(20.r),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22.r,
                  backgroundColor: isEvaluated
                      ? ((e.scores?['passed'] as bool? ?? true)
                            ? const Color(0xFFECFDF5)
                            : const Color(0xFFFEE2E2))
                      : const Color(0xFFF1F5F9),
                  child: Text(
                    e.driverName.isNotEmpty
                        ? e.driverName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: isEvaluated
                          ? ((e.scores?['passed'] as bool? ?? true)
                                ? const Color(0xFF059669)
                                : const Color(0xFFDC2626))
                          : const Color(0xFF64748B),
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            e.driverName,
                            style: GoogleFonts.inter(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(100.r),
                              border: Border.all(
                                color: badgeBorder,
                                width: 1.w,
                              ),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: badgeText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Wrap(
                        spacing: 16.w,
                        runSpacing: 6.h,
                        children: [
                          _buildMetaChip(
                            icon: Icons.directions_car_filled,
                            label: widget.vehicle != null
                                ? '${widget.vehicle!.make} ${widget.vehicle!.model} (${widget.vehicle!.plateNumber})'
                                : 'No vehicle assigned',
                          ),
                          _buildMetaChip(
                            icon: Icons.calendar_month,
                            label: 'Generated ${timeago.format(e.createdAt)}',
                          ),
                          if (isSubmitted)
                            _buildMetaChip(
                              icon: Icons.done_all,
                              label:
                                  'Submitted ${timeago.format(e.submittedAt!)}',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isEvaluated) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            color: Colors.amber[600],
                            size: 20.sp,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            _calculateAvgRating().toStringAsFixed(1),
                            style: GoogleFonts.inter(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            ' / 5',
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                    ],
                    IconButton(
                      icon: Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: const Color(0xFF64748B),
                      ),
                      onPressed: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isExpanded) ...[
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: EdgeInsets.all(20.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isEvaluated) ...[
                    Text(
                      'RATINGS BREAKDOWN',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Row(
                      children: [
                        Expanded(
                          child: _buildBreakdownRow(
                            'Driver Appearance',
                            e.scores?['appearance'] as int? ?? 0,
                          ),
                        ),
                        SizedBox(width: 32.w),
                        Expanded(
                          child: _buildBreakdownRow(
                            'Vehicle Condition',
                            e.scores?['vehicle'] as int? ?? 0,
                          ),
                        ),
                      ],
                    ),
                    if (e.scores?['remarks'] != null &&
                        (e.scores!['remarks'] as String).isNotEmpty) ...[
                      SizedBox(height: 16.h),
                      Text(
                        'Remarks:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.sp,
                          color: const Color(0xFF475569),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        e.scores!['remarks'] as String,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                    SizedBox(height: 20.h),
                    const Divider(color: Color(0xFFE2E8F0)),
                  ],
                  if (hasPhotos) ...[
                    SizedBox(height: 12.h),
                    Text(
                      'SUBMITTED PHOTOS',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    SizedBox(
                      height: 90.h,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: e.media.entries.map((entry) {
                          final photoKey = entry.key;
                          final photoData = entry.value as Map<String, dynamic>;
                          final url = photoData['url'] as String;
                          final label = _getPhotoLabel(photoKey);

                          return Container(
                            margin: EdgeInsets.only(right: 12.w),
                            width: 90.w,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8.r),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: url,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    errorWidget: (_, __, ___) =>
                                        const Icon(Icons.error, size: 20),
                                  ),
                                  Positioned.fill(
                                    child: Material(
                                      color: Colors.transparent,
                                      child: Tooltip(
                                        message: 'View $label',
                                        child: InkWell(
                                          onTap: () => _showFullscreenImage(
                                            context,
                                            url,
                                            label,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    SizedBox(height: 20.h),
                    const Divider(color: Color(0xFFE2E8F0)),
                  ],
                  SizedBox(height: 8.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!isEvaluated) ...[
                        IconButton(
                          icon: const Icon(
                            Icons.share,
                            color: Color(0xFF64748B),
                          ),
                          tooltip: 'Share / Copy Link',
                          onPressed: widget.onShare,
                        ),
                        SizedBox(width: 8.w),
                      ],
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        tooltip: 'Delete Evaluation',
                        onPressed: widget.onDelete,
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  EvaluationDetailScreen(evaluation: e),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF13B1F2),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 20.w,
                            vertical: 12.h,
                          ),
                        ),
                        child: Text(isEvaluated ? 'Re-evaluate' : 'Evaluate'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaChip({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF94A3B8), size: 14.sp),
        SizedBox(width: 6.w),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownRow(String label, int score) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: GoogleFonts.inter(
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF475569),
          ),
        ),
        const Spacer(),
        Row(
          children: List.generate(5, (index) {
            final starIndex = index + 1;
            return Icon(
              starIndex <= score
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              color: starIndex <= score
                  ? const Color(0xFFFBBF24)
                  : const Color(0xFFCBD5E1),
              size: 20.sp,
            );
          }),
        ),
      ],
    );
  }

  void _showFullscreenImage(BuildContext context, String url, String label) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(40.r),
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16.r),
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                    placeholder: (_, __) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.error, color: Colors.white),
                  ),
                ),
              ),
              Positioned(
                top: 16.h,
                right: 16.w,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  tooltip: 'Close preview',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Positioned(
                bottom: 24.h,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.w,
                    vertical: 12.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(100.r),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getPhotoLabel(String key) {
    switch (key) {
      case 'full_body':
        return 'Full Body Uniform';
      case 'shoes':
        return 'Shoes Condition';
      case 'vehicle_front':
        return 'Vehicle Front';
      case 'vehicle_back':
        return 'Vehicle Back';
      case 'vehicle_left':
        return 'Vehicle Left';
      case 'vehicle_right':
        return 'Vehicle Right';
      case 'cabin_front':
        return 'Front Cabin Interior';
      case 'cabin_rear':
        return 'Rear Cabin Interior';
      default:
        return key;
    }
  }
}
