import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

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
              ResponsiveLayout(
                mobile: Column(
                  children: [
                    _buildExpiriesSection(),
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
                          _buildExpiriesSection(),
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
                  'XLoop Admin Panel',
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

  // ── Expiries section ─────────────────────────────────────────────────────────
  Widget _buildExpiriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Consumer<NotificationProvider>(
          builder: (context, provider, _) {
            final expiries = provider.notifications
                .where((n) => n.type == NotificationType.expiry)
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionLabel(
                  label: 'Action Items / Expiries',
                  icon: Icons.warning_amber_rounded,
                  iconColor: _DT.danger,
                  count: expiries.length,
                ),
                SizedBox(height: 16.h),
                if (expiries.isEmpty)
                  _DashboardEmptyState(
                    message: 'All clear — no urgent action items',
                    icon: Icons.check_circle_outline_rounded,
                    color: _DT.success,
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: 500.h),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
                      itemCount: expiries.length,
                      separatorBuilder: (_, __) => SizedBox(height: 12.h),
                      itemBuilder: (context, i) => _ExpiryCard(
                        alert: expiries[i],
                        onUpdate: () => UpdateDialogHelper.showUpdateDialog(
                          context,
                          expiries[i],
                        ),
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

  // ── Recent activity section ──────────────────────────────────────────────────
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
