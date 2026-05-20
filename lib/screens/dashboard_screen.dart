import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:xloop_invoice/features/employee/domain/entities/employee_entity.dart';
import 'package:xloop_invoice/features/employee/presentation/providers/employee_provider.dart';
import 'package:xloop_invoice/features/vehicle/presentation/providers/vehicle_provider.dart';
import 'package:xloop_invoice/features/customer/presentation/providers/customer_provider.dart';
import 'package:xloop_invoice/features/notifications/presentation/providers/notification_provider.dart';
import 'package:xloop_invoice/features/notifications/domain/entities/notification_entity.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/get_vehicles_needing_odo_update_usecase.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_entity.dart';
import 'package:xloop_invoice/widgets/responsive_layout.dart';
import 'package:xloop_invoice/injection_container.dart';
import 'package:xloop_invoice/core/utils/update_dialog_helper.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
class _DT {
  // Background
  static const bgPage = Color(0xFFF4F6FB);
  static const bgCard = Colors.white;
  static const bgCardDark = Color(0xFF1E2235);

  // Brand
  static const brand = Color(0xFF4F46E5); // indigo-600
  static const brandDark = Color(0xFF312E81); // indigo-900

  // Semantic
  static const danger = Color(0xFFDC2626); // red-600
  static const dangerBg = Color(0xFFFFF1F2);
  static const dangerBorder = Color(0xFFFFCDD2);

  static const warning = Color(0xFFD97706); // amber-600
  static const warningBg = Color(0xFFFFFBEB);
  static const warningBorder = Color(0xFFFDE68A);

  static const success = Color(0xFF16A34A); // green-600
  static const successBg = Color(0xFFF0FDF4);

  // Text
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);

  // Border
  static const border = Color(0xFFE5E7EB);
  static const borderLight = Color(0xFFF3F4F6);

  // Shadow
  static const shadow = Color(0x0A000000);
}

// ── Stat card data ─────────────────────────────────────────────────────────────
class _StatData {
  final String label;
  final String value;
  final IconData icon;
  final Color startColor;
  final Color endColor;
  const _StatData({
    required this.label,
    required this.value,
    required this.icon,
    required this.startColor,
    required this.endColor,
  });
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final vehicleProvider = context.read<VehicleProvider>();
      // Fetch vehicles + maintenance types (needed for interval config) together,
      // then refresh alerts so NotificationProvider has all data it needs.
      context.read<EmployeeProvider>().fetchAllEmployees();
      context.read<CustomerProvider>().fetchAllCustomers();
      await Future.wait([
        vehicleProvider.fetchAllVehicles(),
        vehicleProvider.fetchAllMaintenanceTypes(),
      ]);
      if (!mounted) return;
      await context.read<NotificationProvider>().refreshAlerts(
        vehicles: vehicleProvider.vehicles,
        maintenanceTypes: vehicleProvider.maintenanceTypes,
      );
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DT.bgPage,
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeIn,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24.w, 28.h, 24.w, 40.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeBanner(),
              SizedBox(height: 28.h),
              _buildStatsRow(),
              SizedBox(height: 36.h),
              const _CelebrationsSection(),
              ResponsiveLayout(
                mobile: Column(
                  children: [
                    const _ExpiriesSection(),
                    SizedBox(height: 32.h),
                    _buildRecentActivitySection(),
                    SizedBox(height: 32.h),
                    _buildOdometerSection(),
                  ],
                ),
                desktop: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          const _ExpiriesSection(),
                          SizedBox(height: 32.h),
                          _buildRecentActivitySection(),
                        ],
                      ),
                    ),
                    SizedBox(width: 28.w),
                    Expanded(flex: 2, child: _buildOdometerSection()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── App bar ──────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      scrolledUnderElevation: 1,
      surfaceTintColor: Colors.white,
      title: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(
              Icons.dashboard_rounded,
              color: Colors.white,
              size: 20.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Text(
            'Dashboard',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 22.sp,
              color: _DT.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
      actions: [
        if (const String.fromEnvironment('ENV', defaultValue: 'prod') == 'dev')
          Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: _DT.warningBg,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: _DT.warningBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.terminal_rounded,
                    size: 14.sp,
                    color: _DT.warning,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    'Development',
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      color: _DT.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.only(right: 16.w),
          child: _AppBarChip(
            label: _DateLabel(),
            icon: Icons.calendar_today_rounded,
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(1.h),
        child: Container(height: 1.h, color: _DT.border),
      ),
    );
  }

  // ── Welcome banner ───────────────────────────────────────────────────────────
  Widget _buildWelcomeBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back 👋',
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'Xloop Admin Panel',
                  style: GoogleFonts.inter(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Manage your fleet, employees and customers.',
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.rocket_launch_rounded,
            size: 64.sp,
            color: Colors.white.withOpacity(0.12),
          ),
        ],
      ),
    );
  }

  // ── Stats row ────────────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: 'Overview'),
        SizedBox(height: 16.h),
        Consumer3<EmployeeProvider, VehicleProvider, CustomerProvider>(
          builder: (context, emp, veh, cust, _) {
            final stats = [
              _StatData(
                label: 'Employees',
                value: emp.employees.length.toString(),
                icon: Icons.badge_rounded,
                startColor: const Color(0xFF3B82F6),
                endColor: const Color(0xFF1D4ED8),
              ),
              _StatData(
                label: 'Vehicles',
                value: veh.vehicles.length.toString(),
                icon: Icons.directions_bus_rounded,
                startColor: const Color(0xFF10B981),
                endColor: const Color(0xFF059669),
              ),
              _StatData(
                label: 'Customers',
                value: cust.customers.length.toString(),
                icon: Icons.people_alt_rounded,
                startColor: const Color(0xFFF59E0B),
                endColor: const Color(0xFFD97706),
              ),
            ];

            return ResponsiveLayout(
              mobile: Column(
                children: stats
                    .map(
                      (s) => Padding(
                        padding: EdgeInsets.only(bottom: 16.h),
                        child: _StatCard(data: s),
                      ),
                    )
                    .toList(),
              ),
              tablet: Wrap(
                spacing: 16.w,
                runSpacing: 16.h,
                children: stats
                    .map(
                      (s) => SizedBox(
                        width: 240.w,
                        child: _StatCard(data: s),
                      ),
                    )
                    .toList(),
              ),
              desktop: Row(
                children:
                    stats
                        .expand(
                          (s) => [
                            Expanded(child: _StatCard(data: s)),
                            SizedBox(width: 20.w),
                          ],
                        )
                        .toList()
                      ..removeLast(),
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Expiries section (moved to Stateful Widget below) ───────────────────────
  Widget _buildRecentActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Consumer<NotificationProvider>(
          builder: (context, provider, _) {
            final activities = provider.notifications
                .where((n) => n.type != NotificationType.expiry)
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionLabel(
                  label: 'Recent Activity',
                  icon: Icons.history_rounded,
                  iconColor: _DT.brand,
                  count: activities.length,
                ),
                SizedBox(height: 16.h),
                if (activities.isEmpty)
                  const _DashboardEmptyState(
                    message: 'No recent activity yet',
                    icon: Icons.hourglass_empty_rounded,
                    color: _DT.textMuted,
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: 500.h),
                    child: _DashboardCard(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        itemCount: activities.length,
                        separatorBuilder: (_, __) => Container(
                          height: 1.h,
                          margin: EdgeInsets.symmetric(horizontal: 20.w),
                          color: _DT.borderLight,
                        ),
                        itemBuilder: (context, i) =>
                            _ActivityTile(activity: activities[i]),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ── Odometer section ─────────────────────────────────────────────────────────
  Widget _buildOdometerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(
          label: 'Weekly Odometer Updates',
          icon: Icons.speed_rounded,
          iconColor: _DT.warning,
        ),
        SizedBox(height: 16.h),
        Consumer<VehicleProvider>(
          builder: (context, provider, _) {
            final useCase = sl<GetVehiclesNeedingOdometerUpdateUseCase>();
            final needsUpdate = useCase(provider.vehicles);

            if (needsUpdate.isEmpty) {
              return const _DashboardEmptyState(
                message: 'All odometers up to date',
                icon: Icons.check_circle_outline_rounded,
                color: _DT.success,
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: needsUpdate.length,
              separatorBuilder: (_, __) => SizedBox(height: 12.h),
              itemBuilder: (context, i) => _OdometerCard(
                vehicle: needsUpdate[i],
                onCapture: () => _showOdometerDialog(needsUpdate[i]),
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Odometer dialog ──────────────────────────────────────────────────────────
  void _showOdometerDialog(VehicleEntity vehicle) {
    final controller = TextEditingController(
      text: vehicle.currentOdometer?.toString() ?? '',
    );
    showDialog(
      context: context,
      builder: (ctx) => _OdometerDialog(
        vehicle: vehicle,
        controller: controller,
        onConfirm: (km) {
          context.read<VehicleProvider>().updateVehicleOdometer(vehicle.id, km);
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              backgroundColor: _DT.success,
              content: Text(
                'Odometer updated successfully',
                style: GoogleFonts.inter(color: Colors.white),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Shared Widgets
// ═══════════════════════════════════════════════════════════════════════════════

/// Card glass container
class _DashboardCard extends StatelessWidget {
  final Widget child;
  const _DashboardCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _DT.bgCard,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _DT.border),
        boxShadow: const [
          BoxShadow(color: _DT.shadow, blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }
}

/// Section label with optional icon
class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? iconColor;
  final int? count;
  const _SectionLabel({
    required this.label,
    this.icon,
    this.iconColor,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20.sp, color: iconColor ?? _DT.brand),
          SizedBox(width: 8.w),
        ],
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: _DT.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        if (count != null && count! > 0) ...[
          SizedBox(width: 8.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: (iconColor ?? _DT.brand).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: (iconColor ?? _DT.brand).withOpacity(0.3),
              ),
            ),
            child: Text(
              count.toString(),
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: iconColor ?? _DT.brand,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Empty state widget
class _DashboardEmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color color;
  const _DashboardEmptyState({
    required this.message,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 36.h, horizontal: 24.w),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32.sp, color: color),
            ),
            SizedBox(height: 14.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                color: _DT.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// App bar date chip
class _AppBarChip extends StatelessWidget {
  final Widget label;
  final IconData icon;
  const _AppBarChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: _DT.bgPage,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: _DT.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: _DT.brand),
          SizedBox(width: 6.w),
          label,
        ],
      ),
    );
  }
}

class _DateLabel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return Text(
      '${now.day} ${months[now.month - 1]} ${now.year}',
      style: GoogleFonts.inter(
        fontSize: 13.sp,
        color: _DT.textSecondary,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Stat Card
// ═══════════════════════════════════════════════════════════════════════════════
class _StatCard extends StatefulWidget {
  final _StatData data;
  const _StatCard({required this.data});

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: _hovered
            ? (Matrix4.identity()..translate(0.0, -3.0))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [d.startColor, d.endColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: d.startColor.withOpacity(_hovered ? 0.35 : 0.2),
              blurRadius: _hovered ? 28 : 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: EdgeInsets.all(24.w),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Icon(d.icon, color: Colors.white, size: 28.sp),
            ),
            SizedBox(width: 20.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.label,
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    d.value,
                    style: GoogleFonts.inter(
                      fontSize: 32.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      // tabular-nums equivalent
                      fontFeatures: const [FontFeature.tabularFigures()],
                      letterSpacing: -1,
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

// ═══════════════════════════════════════════════════════════════════════════════
//  Expiry Card
// ═══════════════════════════════════════════════════════════════════════════════
class _ExpiryCard extends StatefulWidget {
  final NotificationEntity alert;
  final VoidCallback onUpdate;
  const _ExpiryCard({required this.alert, required this.onUpdate});

  @override
  State<_ExpiryCard> createState() => _ExpiryCardState();
}

class _ExpiryCardState extends State<_ExpiryCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: _hovered ? _DT.dangerBg : Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: _hovered ? _DT.danger.withOpacity(0.35) : _DT.dangerBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: _DT.danger.withOpacity(_hovered ? 0.08 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 14.h),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: _DT.danger.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  color: _DT.danger,
                  size: 22.sp,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.alert.title,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.sp,
                        color: _DT.danger,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      widget.alert.message,
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        color: _DT.danger.withOpacity(0.75),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              _ActionButton(
                label: 'Update',
                color: _DT.danger,
                onPressed: widget.onUpdate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Activity Tile
// ═══════════════════════════════════════════════════════════════════════════════
class _ActivityTile extends StatelessWidget {
  final NotificationEntity activity;
  const _ActivityTile({required this.activity});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (activity.type) {
      NotificationType.registration => (Icons.person_add_rounded, _DT.success),
      NotificationType.invoice => (Icons.receipt_long_rounded, _DT.brand),
      _ => (Icons.info_outline_rounded, _DT.warning),
    };

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18.sp),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.sp,
                    color: _DT.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 3.h),
                Text(
                  activity.message,
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: _DT.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          Text(
            timeago.format(activity.timestamp),
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              color: _DT.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Odometer Card
// ═══════════════════════════════════════════════════════════════════════════════
class _OdometerCard extends StatefulWidget {
  final VehicleEntity vehicle;
  final VoidCallback onCapture;
  const _OdometerCard({required this.vehicle, required this.onCapture});

  @override
  State<_OdometerCard> createState() => _OdometerCardState();
}

class _OdometerCardState extends State<_OdometerCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final v = widget.vehicle;
    final lastUpdated = v.lastOdometerUpdateDate != null
        ? timeago.format(v.lastOdometerUpdateDate!)
        : 'Never';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: _hovered ? _DT.warningBg : Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: _hovered ? _DT.warning.withOpacity(0.4) : _DT.warningBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: _DT.warning.withOpacity(_hovered ? 0.1 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 14.h),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: _DT.warning.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.speed_rounded,
                  color: _DT.warning,
                  size: 22.sp,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${v.make} ${v.model}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.sp,
                        color: _DT.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 3.h),
                    Row(
                      children: [
                        _Tag(label: v.plateNumber, color: _DT.warning),
                        SizedBox(width: 8.w),
                        Icon(
                          Icons.speed,
                          size: 12.sp,
                          color: _DT.textSecondary,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          '${v.currentOdometer ?? 0} KM',
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: _DT.textPrimary,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Container(width: 1, height: 12.h, color: _DT.border),
                        SizedBox(width: 8.w),
                        Text(
                          'Last: $lastUpdated',
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            color: _DT.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              _ActionButton(
                label: 'Capture',
                color: _DT.warning,
                onPressed: widget.onCapture,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Shared mini widgets
// ═══════════════════════════════════════════════════════════════════════════════

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(8.r),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Odometer Dialog
// ═══════════════════════════════════════════════════════════════════════════════
class _OdometerDialog extends StatelessWidget {
  final VehicleEntity vehicle;
  final TextEditingController controller;
  final void Function(int km) onConfirm;
  const _OdometerDialog({
    required this.vehicle,
    required this.controller,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      child: Padding(
        padding: EdgeInsets.all(28.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: _DT.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(
                    Icons.speed_rounded,
                    color: _DT.warning,
                    size: 22.sp,
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Update Odometer',
                        style: GoogleFonts.inter(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                          color: _DT.textPrimary,
                        ),
                      ),
                      Text(
                        '${vehicle.make} ${vehicle.model} · ${vehicle.plateNumber}',
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          color: _DT.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),
            Text(
              'Current mileage (km)',
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: _DT.textPrimary,
              ),
            ),
            SizedBox(height: 10.h),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: GoogleFonts.inter(
                fontSize: 16.sp,
                color: _DT.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              decoration: InputDecoration(
                hintText: 'e.g. 45000',
                suffixText: 'km',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: _DT.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: _DT.brand, width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 14.h,
                ),
              ),
            ),
            SizedBox(height: 24.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      color: _DT.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                ElevatedButton(
                  onPressed: () {
                    final km = int.tryParse(controller.text);
                    if (km != null) onConfirm(km);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _DT.brand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                      horizontal: 24.w,
                      vertical: 14.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    'Save',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Expiries Section (Stateful with Tabs & View All)
// ═══════════════════════════════════════════════════════════════════════════════
class _ExpiriesSection extends StatefulWidget {
  const _ExpiriesSection();

  @override
  State<_ExpiriesSection> createState() => _ExpiriesSectionState();
}

class _ExpiriesSectionState extends State<_ExpiriesSection> {
  int _selectedTabIndex = 0;
  final List<String> _tabs = ['All', 'Company', 'Vehicles', 'Employees', 'Other'];

  List<NotificationEntity> _getFilteredExpiries(
      List<NotificationEntity> allExpiries) {
    if (_selectedTabIndex == 0) return allExpiries;
    if (_selectedTabIndex == 1) {
      // Company (Vault)
      return allExpiries.where((n) => n.id.startsWith('vault_')).toList();
    }
    if (_selectedTabIndex == 2) {
      // Vehicles
      return allExpiries
          .where((n) =>
              n.id.startsWith('maintenance_') || n.id.startsWith('v_expiry_'))
          .toList();
    }
    if (_selectedTabIndex == 3) {
      // Employees
      return allExpiries.where((n) => n.id.startsWith('expiry_')).toList();
    }
    // Other
    return allExpiries
        .where((n) =>
            !n.id.startsWith('maintenance_') &&
            !n.id.startsWith('v_expiry_') &&
            !n.id.startsWith('expiry_') &&
            !n.id.startsWith('vault_'))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, _) {
        final expiries = provider.notifications
            .where((n) => n.type == NotificationType.expiry)
            .toList();

        final filtered = _getFilteredExpiries(expiries);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SectionLabel(
                  label: 'Action Items / Expiries',
                  icon: Icons.warning_amber_rounded,
                  iconColor: _DT.danger,
                  count: expiries.length,
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to ExpiriesListScreen
                    context.push('/expiries');
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: _DT.brand,
                    padding:
                        EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All',
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(Icons.arrow_forward_rounded, size: 16.sp),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            if (expiries.isNotEmpty) ...[
              // Custom interactive tabs for better design
              Semantics(
                label: 'Action item tabs',
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: List.generate(_tabs.length, (index) {
                      final isSelected = _selectedTabIndex == index;
                      int tabCount = 0;
                      if (index == 0) tabCount = expiries.length;
                      if (index == 1) {
                        tabCount =
                            expiries.where((n) => n.id.startsWith('vault_')).length;
                      }
                      if (index == 2) {
                        tabCount = expiries
                            .where((n) =>
                                n.id.startsWith('maintenance_') ||
                                n.id.startsWith('v_expiry_'))
                            .length;
                      }
                      if (index == 3) {
                        tabCount = expiries
                            .where((n) => n.id.startsWith('expiry_'))
                            .length;
                      }
                      if (index == 4) {
                        tabCount = expiries
                            .where((n) =>
                                !n.id.startsWith('maintenance_') &&
                                !n.id.startsWith('v_expiry_') &&
                                !n.id.startsWith('expiry_') &&
                                !n.id.startsWith('vault_'))
                            .length;
                      }

                      return Padding(
                        padding: EdgeInsets.only(right: 8.w),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          child: ChoiceChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_tabs[index]),
                                if (tabCount > 0) ...[
                                  SizedBox(width: 6.w),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 6.w, vertical: 2.h),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.white.withOpacity(0.2)
                                          : _DT.brand.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20.r),
                                    ),
                                    child: Text(
                                      tabCount.toString(),
                                      style: GoogleFonts.inter(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? Colors.white
                                            : _DT.brand,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedTabIndex = index;
                                });
                              }
                            },
                            labelStyle: GoogleFonts.inter(
                              color: isSelected
                                  ? Colors.white
                                  : _DT.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              fontSize: 13.sp,
                            ),
                            backgroundColor: Colors.white,
                            selectedColor: _DT.brand,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20.r),
                              side: BorderSide(
                                color: isSelected
                                    ? _DT.brand
                                    : _DT.border.withOpacity(0.8),
                              ),
                            ),
                            elevation: isSelected ? 2 : 0,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
            ],
            if (filtered.isEmpty)
              _DashboardEmptyState(
                message: expiries.isEmpty
                    ? 'All clear — no urgent action items'
                    : 'No action items in this category',
                icon: Icons.check_circle_outline_rounded,
                color: _DT.success,
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 500.h),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => SizedBox(height: 12.h),
                  itemBuilder: (context, i) => _ExpiryCard(
                    alert: filtered[i],
                    onUpdate: () => UpdateDialogHelper.showUpdateDialog(
                      context,
                      filtered[i],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Celebrations Section (Birthdays today and upcoming)
// ═══════════════════════════════════════════════════════════════════════════════
class _CelebrationsSection extends StatelessWidget {
  const _CelebrationsSection();

  int _daysUntilBirthday(DateTime birthDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var nextBirthday = DateTime(now.year, birthDate.month, birthDate.day);
    if (nextBirthday.isBefore(today)) {
      nextBirthday = DateTime(now.year + 1, birthDate.month, birthDate.day);
    }
    return nextBirthday.difference(today).inDays;
  }

  Future<void> _launchWhatsApp(EmployeeEntity emp, BuildContext context) async {
    final greeting = "Hi ${emp.fullName}, wishing you a very Happy Birthday from all of us at Xloop! Have a fantastic day ahead! 🎂🎉";
    String phone = emp.phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid phone number for WhatsApp')),
      );
      return;
    }
    if (emp.countryCode != null && emp.countryCode!.isNotEmpty) {
      final cleanCc = emp.countryCode!.replaceAll(RegExp(r'\D'), '');
      if (!phone.startsWith(cleanCc)) {
        phone = '$cleanCc$phone';
      }
    }
    final whatsappUrl = 'https://wa.me/$phone?text=${Uri.encodeComponent(greeting)}';
    final uri = Uri.parse(whatsappUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch WhatsApp')),
      );
    }
  }

  Future<void> _launchCall(EmployeeEntity emp, BuildContext context) async {
    String phone = emp.phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (emp.countryCode != null && emp.countryCode!.isNotEmpty && !phone.startsWith('+')) {
      final cleanCc = emp.countryCode!.replaceAll(RegExp(r'[^\d+]'), '');
      if (!phone.startsWith(cleanCc)) {
        phone = '+$cleanCc$phone';
      }
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not initiate call')),
      );
    }
  }

  Future<void> _launchEmail(EmployeeEntity emp, BuildContext context) async {
    if (emp.email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email address provided for this employee')),
      );
      return;
    }
    final subject = Uri.encodeComponent("Happy Birthday, ${emp.fullName}! 🎂🎉");
    final body = Uri.encodeComponent(
      "Hi ${emp.fullName},\n\nWishing you a very Happy Birthday from everyone at Xloop! May this year bring you joy, good health, and success in everything you do!\n\nBest regards,\nThe Xloop Team"
    );
    final emailUrl = 'mailto:${emp.email}?subject=$subject&body=$body';
    final uri = Uri.parse(emailUrl);
    if (!await launchUrl(uri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch email client')),
      );
    }
  }

  Widget _buildWishActionCircle({
    required IconData icon,
    required Color iconColor,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 40.w,
            height: 40.w,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 18.sp,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodayBirthdayCard(EmployeeEntity emp, BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobileCard = width < 680;

    final avatarWidget = Container(
      width: isMobileCard ? 56.w : 64.w,
      height: isMobileCard ? 56.w : 64.w,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.w),
      ),
      child: ClipOval(
        child: (emp.imageUrl != null && emp.imageUrl!.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: emp.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                errorWidget: (context, url, error) => const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                ),
              )
            : Center(
                child: Text(
                  emp.fullName.isNotEmpty ? emp.fullName[0].toUpperCase() : '?',
                  style: GoogleFonts.inter(
                    fontSize: isMobileCard ? 20.sp : 24.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
      ),
    );

    final detailsWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome,
                size: 10.sp,
                color: Colors.white,
              ),
              SizedBox(width: 4.w),
              Text(
                "TODAY'S BIRTHDAY",
                style: GoogleFonts.inter(
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          emp.fullName,
          style: GoogleFonts.inter(
            fontSize: isMobileCard ? 16.sp : 18.sp,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.2,
          ),
        ),
        Text(
          emp.position,
          style: GoogleFonts.inter(
            fontSize: isMobileCard ? 12.sp : 13.sp,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.85),
          ),
        ),
      ],
    );

    final actionsWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildWishActionCircle(
          icon: Icons.phone_rounded,
          iconColor: const Color(0xFF4F46E5),
          tooltip: 'Call ${emp.fullName}',
          onTap: () => _launchCall(emp, context),
        ),
        SizedBox(width: 10.w),
        _buildWishActionCircle(
          icon: Icons.chat_bubble_rounded,
          iconColor: const Color(0xFF16A34A),
          tooltip: 'Send WhatsApp Wish',
          onTap: () => _launchWhatsApp(emp, context),
        ),
        SizedBox(width: 10.w),
        _buildWishActionCircle(
          icon: Icons.email_rounded,
          iconColor: const Color(0xFFDC2626),
          tooltip: 'Send Email Wish',
          onTap: () => _launchEmail(emp, context),
        ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.cake_rounded,
              size: 120.sp,
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          Positioned(
            left: 10,
            bottom: -10,
            child: Icon(
              Icons.auto_awesome,
              size: 40.sp,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
            child: isMobileCard
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          avatarWidget,
                          SizedBox(width: 14.w),
                          Expanded(child: detailsWidget),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            "Send wishes: ",
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          const Spacer(),
                          actionsWidget,
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      avatarWidget,
                      SizedBox(width: 16.w),
                      Expanded(child: detailsWidget),
                      SizedBox(width: 16.w),
                      actionsWidget,
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingBirthdaysList(List<EmployeeEntity> list, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.upcoming_rounded,
              size: 18.sp,
              color: _DT.warning,
            ),
            SizedBox(width: 6.w),
            Text(
              'Upcoming Celebrations',
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: _DT.textSecondary,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: list.length,
          separatorBuilder: (_, __) => SizedBox(height: 10.h),
          itemBuilder: (context, i) {
            final emp = list[i];
            final days = _daysUntilBirthday(emp.birthDate!);
            return _UpcomingBirthdayCard(
              employee: emp,
              daysRemaining: days,
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EmployeeProvider>(
      builder: (context, employeeProvider, _) {
        final employees = employeeProvider.employees;

        final todayBirthdays = employees.where((emp) {
          if (!emp.isActive || emp.birthDate == null) return false;
          return _daysUntilBirthday(emp.birthDate!) == 0;
        }).toList();

        final upcomingBirthdays = employees.where((emp) {
          if (!emp.isActive || emp.birthDate == null) return false;
          final days = _daysUntilBirthday(emp.birthDate!);
          return days > 0 && days <= 10;
        }).toList();

        if (todayBirthdays.isEmpty && upcomingBirthdays.isEmpty) {
          return const SizedBox.shrink();
        }

        upcomingBirthdays.sort((a, b) =>
            _daysUntilBirthday(a.birthDate!).compareTo(_daysUntilBirthday(b.birthDate!)));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel(
              label: 'Celebrations',
              icon: Icons.cake_rounded,
              iconColor: const Color(0xFFD946EF),
            ),
            SizedBox(height: 16.h),
            if (todayBirthdays.isNotEmpty && upcomingBirthdays.isNotEmpty) ...[
              ResponsiveLayout(
                mobile: Column(
                  children: [
                    ...todayBirthdays.map((emp) => Padding(
                          padding: EdgeInsets.only(bottom: 16.h),
                          child: _buildTodayBirthdayCard(emp, context),
                        )),
                    _buildUpcomingBirthdaysList(upcomingBirthdays, context),
                  ],
                ),
                desktop: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: todayBirthdays
                            .map((emp) => Padding(
                                  padding: EdgeInsets.only(bottom: 16.h),
                                  child: _buildTodayBirthdayCard(emp, context),
                                ))
                            .toList(),
                      ),
                    ),
                    SizedBox(width: 28.w),
                    Expanded(
                      flex: 2,
                      child: _buildUpcomingBirthdaysList(upcomingBirthdays, context),
                    ),
                  ],
                ),
              ),
            ] else if (todayBirthdays.isNotEmpty) ...[
              ResponsiveLayout(
                mobile: Column(
                  children: todayBirthdays
                      .map((emp) => Padding(
                            padding: EdgeInsets.only(bottom: 16.h),
                            child: _buildTodayBirthdayCard(emp, context),
                          ))
                      .toList(),
                ),
                desktop: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: todayBirthdays
                            .map((emp) => Padding(
                                  padding: EdgeInsets.only(bottom: 16.h),
                                  child: _buildTodayBirthdayCard(emp, context),
                                ))
                            .toList(),
                      ),
                    ),
                    SizedBox(width: 28.w),
                    const Spacer(flex: 2),
                  ],
                ),
              ),
            ] else ...[
              ResponsiveLayout(
                mobile: _buildUpcomingBirthdaysList(upcomingBirthdays, context),
                desktop: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildUpcomingBirthdaysList(upcomingBirthdays, context),
                    ),
                    SizedBox(width: 28.w),
                    const Spacer(flex: 3),
                  ],
                ),
              ),
            ],
            SizedBox(height: 36.h),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Upcoming Birthday Card
// ═══════════════════════════════════════════════════════════════════════════════
class _UpcomingBirthdayCard extends StatefulWidget {
  final EmployeeEntity employee;
  final int daysRemaining;
  const _UpcomingBirthdayCard({
    required this.employee,
    required this.daysRemaining,
  });

  @override
  State<_UpcomingBirthdayCard> createState() => _UpcomingBirthdayCardState();
}

class _UpcomingBirthdayCardState extends State<_UpcomingBirthdayCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final emp = widget.employee;
    final days = widget.daysRemaining;

    String dateStr = '';
    if (emp.birthDate != null) {
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      dateStr = '${emp.birthDate!.day} ${months[emp.birthDate!.month - 1]}';
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: _hovered ? _DT.warningBg : Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: _hovered ? _DT.warning.withOpacity(0.4) : _DT.warningBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: _DT.warning.withOpacity(_hovered ? 0.1 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: _DT.warning.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: (emp.imageUrl != null && emp.imageUrl!.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: emp.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(_DT.warning),
                            ),
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.person_rounded,
                            color: _DT.warning,
                          ),
                        )
                      : Center(
                          child: Text(
                            emp.fullName.isNotEmpty ? emp.fullName[0].toUpperCase() : '?',
                            style: GoogleFonts.inter(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              color: _DT.warning,
                            ),
                          ),
                        ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emp.fullName,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.sp,
                        color: _DT.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      emp.position,
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: _DT.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    dateStr,
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: _DT.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: _DT.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Text(
                      days == 1 ? 'Tomorrow' : 'In $days days',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: _DT.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
