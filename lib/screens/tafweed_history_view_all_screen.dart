import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../features/employee/domain/entities/employee_entity.dart';
import '../features/vehicle/domain/entities/vehicle_documents.dart';
import '../features/employee/presentation/providers/employee_provider.dart';
import '../features/vehicle/presentation/providers/vehicle_provider.dart';
import '../core/widgets/modern_app_bar.dart';

enum TafweedHistoryType { employee, vehicle }

class TafweedHistoryViewAllScreen extends StatelessWidget {
  final String title;
  final String id; // Employee ID or Vehicle ID
  final TafweedHistoryType type;

  const TafweedHistoryViewAllScreen({
    super.key,
    required this.title,
    required this.id,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(title: title),
      body: Consumer2<EmployeeProvider, VehicleProvider>(
        builder: (context, empProvider, vehicleProvider, child) {
          final List<_GenericTafweedEntry> entries = [];

          if (type == TafweedHistoryType.employee) {
            final vehicles = vehicleProvider.vehicles;
            for (final vehicle in vehicles) {
              // Active
              final active = vehicle.tafweeds?.where((t) => t.driverId == id) ?? [];
              for (final t in active) {
                entries.add(_GenericTafweedEntry(
                  record: t,
                  title: '${vehicle.make} ${vehicle.model}',
                  subtitle: 'Plate: ${vehicle.plateNumber}',
                  isActive: true,
                ));
              }
              // History
              final history = vehicle.tafweedHistory?.where((t) => t.driverId == id) ?? [];
              for (final t in history) {
                entries.add(_GenericTafweedEntry(
                  record: t,
                  title: '${vehicle.make} ${vehicle.model}',
                  subtitle: 'Plate: ${vehicle.plateNumber}',
                  isActive: false,
                ));
              }
            }
          } else {
            final vehicle = vehicleProvider.vehicles.firstWhere((v) => v.id == id);
            // Active
            if (vehicle.tafweeds != null) {
              for (final t in vehicle.tafweeds!) {
                final driver = empProvider.employees.firstWhere((e) => e.id == t.driverId, orElse: () => EmployeeEntity.empty());
                entries.add(_GenericTafweedEntry(
                  record: t,
                  title: driver.fullName.isEmpty ? 'Unknown Driver' : driver.fullName,
                  subtitle: 'Tafweed Authorization',
                  isActive: true,
                ));
              }
            }
            // History
            if (vehicle.tafweedHistory != null) {
              for (final t in vehicle.tafweedHistory!) {
                final driver = empProvider.employees.firstWhere((e) => e.id == t.driverId, orElse: () => EmployeeEntity.empty());
                entries.add(_GenericTafweedEntry(
                  record: t,
                  title: driver.fullName.isEmpty ? 'Unknown Driver' : driver.fullName,
                  subtitle: 'Historical Authorization',
                  isActive: false,
                ));
              }
            }
          }

          entries.sort((a, b) => b.record.issuedDate.compareTo(a.record.issuedDate));

          if (entries.isEmpty) {
            return const Center(child: Text('No history found.'));
          }

          return ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              return _buildHistoryCard(entries[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildHistoryCard(_GenericTafweedEntry entry) {
    final now = DateTime.now();
    final isExpired = entry.record.expiryDate.isBefore(now);

    final Color statusColor;
    final String statusLabel;
    final IconData statusIcon;

    if (entry.isActive && !isExpired) {
      statusColor = Colors.green;
      statusLabel = 'Active';
      statusIcon = Icons.check_circle_outline;
    } else if (entry.isActive && isExpired) {
      statusColor = Colors.red;
      statusLabel = 'Expired';
      statusIcon = Icons.warning_amber_outlined;
    } else {
      statusColor = Colors.grey;
      statusLabel = 'Historical';
      statusIcon = Icons.archive_outlined;
    }

    return Card(
      elevation: 1,
      margin: EdgeInsets.only(bottom: 12.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(
          color: statusColor.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4.w,
              height: 64.h,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.title,
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              entry.subtitle,
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 13.sp, color: statusColor),
                            SizedBox(width: 4.w),
                            Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 13.sp,
                        color: Colors.grey[500],
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        'Issued: ${DateFormat('dd MMM yyyy').format(entry.record.issuedDate)}',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Icon(
                        Icons.event_outlined,
                        size: 13.sp,
                        color: isExpired ? Colors.red[400] : Colors.grey[500],
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        'Expiry: ${DateFormat('dd MMM yyyy').format(entry.record.expiryDate)}',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: isExpired ? FontWeight.bold : FontWeight.normal,
                          color: isExpired ? Colors.red : Colors.grey[700],
                        ),
                      ),
                    ],
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

class _GenericTafweedEntry {
  final TafweedRecord record;
  final String title;
  final String subtitle;
  final bool isActive;

  const _GenericTafweedEntry({
    required this.record,
    required this.title,
    required this.subtitle,
    required this.isActive,
  });
}
