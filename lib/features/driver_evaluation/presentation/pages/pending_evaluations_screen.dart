import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:google_fonts/google_fonts.dart';
import 'package:xloop_invoice/features/driver_evaluation/presentation/providers/admin_evaluation_provider.dart';
import 'package:xloop_invoice/features/driver_evaluation/presentation/pages/evaluation_detail_screen.dart';
import 'package:xloop_invoice/features/employee/presentation/providers/employee_provider.dart';
import 'package:xloop_invoice/features/vehicle/presentation/providers/vehicle_provider.dart';
import 'package:xloop_invoice/features/employee/domain/entities/employee_entity.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_entity.dart';
import 'package:xloop_invoice/core/utils/share_dialog.dart';
import 'package:xloop_invoice/features/driver_evaluation/domain/entities/evaluation_entity.dart';
import 'package:xloop_invoice/widgets/searchable_dropdown.dart';
import 'package:xloop_invoice/widgets/web_safe_image.dart';

class PendingEvaluationsScreen extends StatefulWidget {
  const PendingEvaluationsScreen({super.key});

  @override
  State<PendingEvaluationsScreen> createState() =>
      _PendingEvaluationsScreenState();
}

class _PendingEvaluationsScreenState extends State<PendingEvaluationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _leaderboardSearchController =
      TextEditingController();
  String _leaderboardQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminEvaluationProvider>().loadPendingEvaluations();
      context.read<EmployeeProvider>().fetchAllEmployees();
      context.read<VehicleProvider>().fetchAllVehicles();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _leaderboardSearchController.dispose();
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
                            Tab(text: 'Leaderboard'),
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
                            _buildLeaderboardTab(
                              adminProvider.evaluatedEvaluations,
                              employeeProvider.employees,
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

  Widget _buildLeaderboardTab(
    List<EvaluationEntity> evaluatedEvaluations,
    List<EmployeeEntity> employees,
  ) {
    // Group evaluations by driverId
    final Map<String, List<EvaluationEntity>> grouped = {};
    for (var e in evaluatedEvaluations) {
      if (e.scores != null) {
        grouped.putIfAbsent(e.driverId, () => []).add(e);
      }
    }

    final entries = <_DriverLeaderboardEntry>[];
    grouped.forEach((driverId, evals) {
      double totalScore = 0.0;
      int passCount = 0;
      for (var eval in evals) {
        final app = eval.scores!['appearance'] as int? ?? 0;
        final veh = eval.scores!['vehicle'] as int? ?? 0;
        totalScore += (app + veh) / 2.0;
        if (eval.scores!['passed'] as bool? ?? true) {
          passCount++;
        }
      }
      final avg = evals.isNotEmpty ? totalScore / evals.length : 0.0;
      final passRate = evals.isNotEmpty ? passCount / evals.length : 0.0;
      final driverName = evals.first.driverName;
      final empIdx = employees.indexWhere((e) => e.id == driverId);
      final emp = empIdx != -1 ? employees[empIdx] : null;

      entries.add(
        _DriverLeaderboardEntry(
          driverId: driverId,
          driverName: driverName,
          averageScore: avg,
          completedCount: evals.length,
          passRate: passRate,
          employee: emp,
        ),
      );
    });

    // Sort entries by averageScore desc, then completedCount desc
    entries.sort((a, b) {
      int cmp = b.averageScore.compareTo(a.averageScore);
      if (cmp != 0) return cmp;
      return b.completedCount.compareTo(a.completedCount);
    });

    // Filter based on search query
    final filteredEntries = entries.where((entry) {
      return entry.driverName.toLowerCase().contains(_leaderboardQuery);
    }).toList();

    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 64.r,
              color: const Color(0xFF94A3B8),
            ),
            SizedBox(height: 16.h),
            Text(
              'Leaderboard is empty',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Rankings will appear once drivers are evaluated.',
              style: TextStyle(fontSize: 14.sp, color: const Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    final top3 = filteredEntries.take(3).toList();
    final others = filteredEntries.skip(3).toList();

    return ListView(
      padding: EdgeInsets.all(24.r),
      children: [
        // Search Field
        TextField(
          controller: _leaderboardSearchController,
          onChanged: (val) {
            setState(() {
              _leaderboardQuery = val.trim().toLowerCase();
            });
          },
          style: GoogleFonts.inter(
            fontSize: 14.sp,
            color: const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: 'Search driver on leaderboard…',
            hintStyle: GoogleFonts.inter(
              fontSize: 14.sp,
              color: const Color(0xFF94A3B8),
            ),
            prefixIcon: Icon(
              Icons.search,
              size: 20.sp,
              color: const Color(0xFF64748B),
            ),
            suffixIcon: _leaderboardQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      size: 18.sp,
                      color: const Color(0xFF64748B),
                    ),
                    onPressed: () {
                      _leaderboardSearchController.clear();
                      setState(() {
                        _leaderboardQuery = '';
                      });
                    },
                  )
                : null,
            fillColor: Colors.white,
            filled: true,
            contentPadding: EdgeInsets.symmetric(
              vertical: 12.h,
              horizontal: 16.w,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(
                color: Color(0xFF13B1F2),
                width: 1.5,
              ),
            ),
          ),
        ),
        SizedBox(height: 24.h),

        // Podium (only show if search query is empty)
        if (top3.isNotEmpty && _leaderboardQuery.isEmpty) ...[
          _buildPodium(top3),
          SizedBox(height: 32.h),
        ],

        if (filteredEntries.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40.h),
              child: Text(
                'No drivers match your search',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
          ),

        // Ranked List
        if (others.isNotEmpty ||
            (filteredEntries.isNotEmpty && _leaderboardQuery.isNotEmpty)) ...[
          Text(
            _leaderboardQuery.isNotEmpty ? 'SEARCH RESULTS' : 'OTHER RANKINGS',
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: const Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 12.h),
          ...List.generate(
            _leaderboardQuery.isNotEmpty
                ? filteredEntries.length
                : others.length,
            (index) {
              final entry = _leaderboardQuery.isNotEmpty
                  ? filteredEntries[index]
                  : others[index];
              final rank = _leaderboardQuery.isNotEmpty
                  ? entries.indexOf(entry) + 1
                  : index + 4;
              return _buildLeaderboardTile(entry, rank);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildPodium(List<_DriverLeaderboardEntry> top3) {
    final hasSecond = top3.length > 1;
    final hasThird = top3.length > 2;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (hasSecond) ...[
          Expanded(child: _buildPodiumCard(top3[1], 2)),
          SizedBox(width: 16.w),
        ],
        Expanded(child: _buildPodiumCard(top3[0], 1)),
        if (hasThird) ...[
          SizedBox(width: 16.w),
          Expanded(child: _buildPodiumCard(top3[2], 3)),
        ] else if (!hasSecond) ...[
          const Spacer(),
          const Spacer(),
        ] else ...[
          const Spacer(),
        ],
      ],
    );
  }

  Widget _buildPodiumCard(_DriverLeaderboardEntry entry, int rank) {
    Color medalColor;
    Color bgHighlight;
    Color borderColor;
    IconData icon;
    double height;
    double crownSize;

    if (rank == 1) {
      medalColor = const Color(0xFFD97706);
      bgHighlight = const Color(0xFFFFFBEB);
      borderColor = const Color(0xFFFBBF24);
      icon = Icons.emoji_events;
      height = 230.h;
      crownSize = 32.sp;
    } else if (rank == 2) {
      medalColor = const Color(0xFF475569);
      bgHighlight = const Color(0xFFF8FAFC);
      borderColor = const Color(0xFFCBD5E1);
      icon = Icons.emoji_events;
      height = 195.h;
      crownSize = 26.sp;
    } else {
      medalColor = const Color(0xFF9A3412);
      bgHighlight = const Color(0xFFFFF7ED);
      borderColor = const Color(0xFFFDBA74);
      icon = Icons.emoji_events;
      height = 180.h;
      crownSize = 24.sp;
    }

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: borderColor, width: rank == 1 ? 2.w : 1.w),
        boxShadow: [
          BoxShadow(
            color: medalColor.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: rank == 1 ? -10.h : -5.h,
            child: Icon(icon, color: borderColor, size: crownSize * 1.5),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 16.h),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: rank == 1 ? 26.r : 20.r,
                  backgroundColor: bgHighlight,
                  child: Text(
                    entry.driverName.isNotEmpty
                        ? entry.driverName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: medalColor,
                      fontWeight: FontWeight.bold,
                      fontSize: rank == 1 ? 18.sp : 14.sp,
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  entry.driverName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: rank == 1 ? 14.sp : 12.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 4.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      color: const Color(0xFFFBBF24),
                      size: 16.sp,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      entry.averageScore.toStringAsFixed(1),
                      style: GoogleFonts.inter(
                        fontSize: rank == 1 ? 15.sp : 13.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(100.r),
                  ),
                  child: Text(
                    '${entry.completedCount} evals',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 12.h,
            left: 12.w,
            child: Container(
              padding: EdgeInsets.all(6.r),
              decoration: BoxDecoration(
                color: borderColor,
                shape: BoxShape.circle,
              ),
              child: Text(
                '#$rank',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10.sp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTile(_DriverLeaderboardEntry entry, int rank) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x02000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32.r,
            height: 32.r,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Text(
              '#$rank',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 13.sp,
                color: const Color(0xFF475569),
              ),
            ),
          ),
          SizedBox(width: 16.w),
          CircleAvatar(
            radius: 18.r,
            backgroundColor: const Color(0xFFF1F5F9),
            child: Text(
              entry.driverName.isNotEmpty
                  ? entry.driverName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.bold,
                fontSize: 12.sp,
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.driverName,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.sp,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(100.r),
                        child: LinearProgressIndicator(
                          value: entry.averageScore / 5.0,
                          backgroundColor: const Color(0xFFF1F5F9),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            entry.averageScore >= 4.0
                                ? const Color(0xFF10B981)
                                : entry.averageScore >= 3.0
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFFEF4444),
                          ),
                          minHeight: 6.h,
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      '${entry.completedCount} evals',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 24.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.star_rounded,
                    color: Colors.amber[600],
                    size: 18.sp,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    entry.averageScore.toStringAsFixed(1),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 15.sp,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4.h),
              Text(
                'Pass: ${(entry.passRate * 100).toStringAsFixed(0)}%',
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: entry.passRate >= 0.8
                      ? const Color(0xFF059669)
                      : entry.passRate >= 0.5
                      ? const Color(0xFFD97706)
                      : const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
        ],
      ),
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
    final app = (widget.evaluation.scores!['appearance'] as num? ?? 0)
        .toDouble();
    final veh = (widget.evaluation.scores!['vehicle'] as num? ?? 0).toDouble();
    return (app + veh) / 2.0;
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.evaluation;
    final isSubmitted = e.submittedAt != null;
    final isEvaluated = e.status == 'evaluated';
    final hasPhotos = e.media.isNotEmpty;
    final details = e.scores?['details'] as Map<String, dynamic>?;

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
                    if (details != null) ...[
                      Text(
                        'APPEARANCE DETAILS',
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Expanded(
                            child: _buildBreakdownRow(
                              'Uniform (Full Body)',
                              (details['full_body'] as num? ?? 0).round(),
                            ),
                          ),
                          SizedBox(width: 32.w),
                          Expanded(
                            child: _buildBreakdownRow(
                              'Shoes Condition',
                              (details['shoes'] as num? ?? 0).round(),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        'VEHICLE DETAILS',
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Expanded(
                            child: _buildBreakdownRow(
                              'Vehicle Front',
                              (details['vehicle_front'] as num? ?? 0).round(),
                            ),
                          ),
                          SizedBox(width: 32.w),
                          Expanded(
                            child: _buildBreakdownRow(
                              'Vehicle Back',
                              (details['vehicle_back'] as num? ?? 0).round(),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Expanded(
                            child: _buildBreakdownRow(
                              'Vehicle Left',
                              (details['vehicle_left'] as num? ?? 0).round(),
                            ),
                          ),
                          SizedBox(width: 32.w),
                          Expanded(
                            child: _buildBreakdownRow(
                              'Vehicle Right',
                              (details['vehicle_right'] as num? ?? 0).round(),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Expanded(
                            child: _buildBreakdownRow(
                              'Cabin Front',
                              (details['cabin_front'] as num? ?? 0).round(),
                            ),
                          ),
                          SizedBox(width: 32.w),
                          Expanded(
                            child: _buildBreakdownRow(
                              'Cabin Rear',
                              (details['cabin_rear'] as num? ?? 0).round(),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: _buildBreakdownRow(
                              'Driver Appearance',
                              (e.scores?['appearance'] as num? ?? 0).round(),
                            ),
                          ),
                          SizedBox(width: 32.w),
                          Expanded(
                            child: _buildBreakdownRow(
                              'Vehicle Condition',
                              (e.scores?['vehicle'] as num? ?? 0).round(),
                            ),
                          ),
                        ],
                      ),
                    ],
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
                                  WebSafeImage(
                                    imageUrl: url,
                                    fit: BoxFit.cover,
                                    placeholder: const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    errorWidget:
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
                  child: WebSafeImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                    placeholder:
                        const Center(child: CircularProgressIndicator()),
                    errorWidget:
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

class _DriverLeaderboardEntry {
  final String driverId;
  final String driverName;
  final double averageScore;
  final int completedCount;
  final double passRate;
  final EmployeeEntity? employee;

  _DriverLeaderboardEntry({
    required this.driverId,
    required this.driverName,
    required this.averageScore,
    required this.completedCount,
    required this.passRate,
    this.employee,
  });
}
