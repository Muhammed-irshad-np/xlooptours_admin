import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../features/employee/presentation/providers/employee_provider.dart';
import '../features/vehicle/presentation/providers/vehicle_provider.dart';
import '../features/customer/presentation/providers/customer_provider.dart';
import '../features/notifications/presentation/providers/notification_provider.dart';
import '../features/notifications/domain/entities/notification_entity.dart';
import '../features/vehicle/domain/usecases/get_vehicles_needing_odo_update_usecase.dart';
import '../features/vehicle/domain/entities/vehicle_entity.dart';
import '../widgets/responsive_layout.dart';
import '../injection_container.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<EmployeeProvider>().fetchAllEmployees();
        context.read<VehicleProvider>().fetchAllVehicles();
        context.read<CustomerProvider>().fetchAllCustomers();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Dashboard',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 24.sp,
            color: Colors.indigo[900],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverviewSummary(),
            SizedBox(height: 32.h),
            ResponsiveLayout(
              mobile: Column(
                children: [
                  _buildExpiriesSection(),
                  SizedBox(height: 32.h),
                  _buildRecentActivitySection(),
                  SizedBox(height: 32.h),
                  _buildOdometerUpdateSection(),
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
                  SizedBox(width: 32.w),
                  Expanded(flex: 2, child: _buildOdometerUpdateSection()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: GoogleFonts.inter(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: Colors.indigo[900],
          ),
        ),
        SizedBox(height: 16.h),
        ResponsiveLayout(
          mobile: Column(
            children: [
              _buildSummaryCard(
                title: 'Employees',
                value: context
                    .watch<EmployeeProvider>()
                    .employees
                    .length
                    .toString(),
                icon: Icons.badge,
                color: Colors.blue,
              ),
              SizedBox(height: 16.h),
              _buildSummaryCard(
                title: 'Vehicles',
                value: context
                    .watch<VehicleProvider>()
                    .vehicles
                    .length
                    .toString(),
                icon: Icons.directions_bus,
                color: Colors.green,
              ),
              SizedBox(height: 16.h),
              _buildSummaryCard(
                title: 'Customers',
                value: context
                    .watch<CustomerProvider>()
                    .customers
                    .length
                    .toString(),
                icon: Icons.people,
                color: Colors.orange,
              ),
            ],
          ),
          tablet: Wrap(
            spacing: 16.w,
            runSpacing: 16.h,
            children: [
              _buildSummaryCard(
                title: 'Employees',
                value: context
                    .watch<EmployeeProvider>()
                    .employees
                    .length
                    .toString(),
                icon: Icons.badge,
                color: Colors.blue,
                width: 250,
              ),
              _buildSummaryCard(
                title: 'Vehicles',
                value: context
                    .watch<VehicleProvider>()
                    .vehicles
                    .length
                    .toString(),
                icon: Icons.directions_bus,
                color: Colors.green,
                width: 250,
              ),
              _buildSummaryCard(
                title: 'Customers',
                value: context
                    .watch<CustomerProvider>()
                    .customers
                    .length
                    .toString(),
                icon: Icons.people,
                color: Colors.orange,
                width: 250,
              ),
            ],
          ),
          desktop: Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  title: 'Employees',
                  value: context
                      .watch<EmployeeProvider>()
                      .employees
                      .length
                      .toString(),
                  icon: Icons.badge,
                  color: Colors.blue,
                ),
              ),
              SizedBox(width: 24.w),
              Expanded(
                child: _buildSummaryCard(
                  title: 'Vehicles',
                  value: context
                      .watch<VehicleProvider>()
                      .vehicles
                      .length
                      .toString(),
                  icon: Icons.directions_bus,
                  color: Colors.green,
                ),
              ),
              SizedBox(width: 24.w),
              Expanded(
                child: _buildSummaryCard(
                  title: 'Customers',
                  value: context
                      .watch<CustomerProvider>()
                      .customers
                      .length
                      .toString(),
                  icon: Icons.people,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    double? width,
  }) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: EdgeInsets.all(24.w),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, color: color, size: 32.sp),
          ),
          SizedBox(width: 24.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: Colors.grey[600],
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo[900],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpiriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Action Items / Expiries', Icons.warning_amber),
        SizedBox(height: 16.h),
        Consumer<NotificationProvider>(
          builder: (context, provider, child) {
            final expiries = provider.notifications
                .where((n) => n.type == NotificationType.expiry)
                .toList();

            if (expiries.isEmpty) {
              return _buildEmptyState(
                'No urgent action items',
                Icons.check_circle_outline,
                Colors.green,
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: expiries.length > 5 ? 5 : expiries.length,
              separatorBuilder: (_, __) => SizedBox(height: 12.h),
              itemBuilder: (context, index) {
                final alert = expiries[index];
                return _buildExpiryCard(alert);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildExpiryCard(NotificationEntity alert) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
        leading: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.error_outline, color: Colors.red, size: 24.sp),
        ),
        title: Text(
          alert.title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 16.sp,
            color: Colors.red[900],
          ),
        ),
        subtitle: Padding(
          padding: EdgeInsets.only(top: 8.h),
          child: Text(
            alert.message,
            style: GoogleFonts.inter(fontSize: 14.sp, color: Colors.red[800]),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Recent Activity', Icons.history),
        SizedBox(height: 16.h),
        Consumer<NotificationProvider>(
          builder: (context, provider, child) {
            final activities = provider.notifications
                .where((n) => n.type != NotificationType.expiry)
                .toList();

            // Assuming notifications are already sorted by timestamp descending
            if (activities.isEmpty) {
              return _buildEmptyState(
                'No recent activity',
                Icons.hourglass_empty,
                Colors.grey,
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activities.length > 5 ? 5 : activities.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.grey.withOpacity(0.1),
                ),
                itemBuilder: (context, index) {
                  final activity = activities[index];
                  return _buildActivityTile(activity);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActivityTile(NotificationEntity activity) {
    IconData icon;
    Color color;

    switch (activity.type) {
      case NotificationType.registration:
        icon = Icons.person_add;
        color = Colors.green;
        break;
      case NotificationType.invoice:
        icon = Icons.receipt;
        color = Colors.blue;
        break;
      case NotificationType.system:
      default:
        icon = Icons.info;
        color = Colors.orange;
        break;
    }

    return ListTile(
      contentPadding: EdgeInsets.all(16.w),
      leading: CircleAvatar(
        radius: 20.r,
        backgroundColor: color.withOpacity(0.1),
        child: Icon(icon, color: color, size: 20.sp),
      ),
      title: Text(
        activity.title,
        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14.sp),
      ),
      subtitle: Padding(
        padding: EdgeInsets.only(top: 4.h),
        child: Text(
          activity.message,
          style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.grey[600]),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing: Text(
        timeago.format(activity.timestamp),
        style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.grey[400]),
      ),
    );
  }

  Widget _buildOdometerUpdateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Weekly Odometer Updates', Icons.speed),
        SizedBox(height: 16.h),
        Consumer<VehicleProvider>(
          builder: (context, provider, child) {
            final useCase = sl<GetVehiclesNeedingOdometerUpdateUseCase>();
            final vehiclesNeedingUpdate = useCase(provider.vehicles);

            if (vehiclesNeedingUpdate.isEmpty) {
              return _buildEmptyState(
                'All vehicle odometers up to date',
                Icons.check_circle_outline,
                Colors.green,
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: vehiclesNeedingUpdate.length,
              separatorBuilder: (_, __) => SizedBox(height: 12.h),
              itemBuilder: (context, index) {
                final vehicle = vehiclesNeedingUpdate[index];
                return _buildOdometerUpdateCard(vehicle);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildOdometerUpdateCard(VehicleEntity vehicle) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
        leading: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.speed, color: Colors.orange, size: 24.sp),
        ),
        title: Text(
          'Update Odometer',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 16.sp,
            color: Colors.orange[900],
          ),
        ),
        subtitle: Padding(
          padding: EdgeInsets.only(top: 4.h),
          child: Text(
            '${vehicle.make} ${vehicle.model} (${vehicle.plateNumber})\nLast updated: ${vehicle.lastOdometerUpdateDate != null ? timeago.format(vehicle.lastOdometerUpdateDate!) : "Never"}',
            style: GoogleFonts.inter(fontSize: 14.sp, color: Colors.orange[800]),
          ),
        ),
        trailing: ElevatedButton(
          onPressed: () => _showOdometerUpdateDialog(vehicle),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange[700],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
          child: const Text('Capture'),
        ),
      ),
    );
  }

  void _showOdometerUpdateDialog(VehicleEntity vehicle) {
    final controller = TextEditingController(text: vehicle.currentOdometer?.toString() ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Odometer: ${vehicle.plateNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter current mileage for ${vehicle.make} ${vehicle.model}'),
            SizedBox(height: 16.h),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Current Odometer (km)',
                border: OutlineInputBorder(),
                suffixText: 'km',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newMileage = int.tryParse(controller.text);
              if (newMileage != null) {
                context.read<VehicleProvider>().updateVehicleOdometer(vehicle.id, newMileage);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Odometer updated successfully')),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.indigo[900], size: 24.sp),
        SizedBox(width: 12.w),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: Colors.indigo[900],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(32.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48.sp, color: color.withOpacity(0.5)),
          SizedBox(height: 16.h),
          Text(
            message,
            style: GoogleFonts.inter(fontSize: 16.sp, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
