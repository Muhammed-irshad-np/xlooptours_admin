import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../features/vehicle/domain/entities/vehicle_entity.dart';
import '../features/vehicle/domain/entities/vehicle_documents.dart';
import '../features/employee/domain/entities/employee_entity.dart';
import '../features/vehicle/domain/entities/maintenance_type_entity.dart';
import '../features/vehicle/presentation/providers/vehicle_provider.dart';
import '../features/employee/presentation/providers/employee_provider.dart';
import 'vehicle_maintenance_history_screen.dart';
import 'document_viewer_screen.dart';
import '../core/utils/share_helper.dart';
import '../core/widgets/modern_app_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../features/auth/presentation/providers/auth_provider.dart';

import '../widgets/add_maintenance_record_dialog.dart';
import 'tafweed_history_view_all_screen.dart';
import '../features/vehicle/presentation/widgets/authorize_driver_to_vehicle_dialog.dart';

class VehicleDetailScreen extends StatelessWidget {
  final VehicleEntity vehicle;
  final EmployeeEntity? driver;

  const VehicleDetailScreen({super.key, required this.vehicle, this.driver});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<VehicleProvider>(context);
    final isAdmin = context.watch<AuthProvider>().user?.isAdmin ?? false;

    // Find the latest version of this vehicle in the provider's list
    // to ensure the UI refreshes when maintenance records are added.
    final currentVehicle = provider.vehicles.cast<VehicleEntity>().firstWhere(
      (v) => v.id == vehicle.id,
      orElse: () => vehicle,
    );

    final missingTypes = provider.maintenanceTypes.where((type) {
      final wasPerformed =
          currentVehicle.maintenanceHistory?.any(
            (record) =>
                record.serviceType?.toLowerCase() == type.name.toLowerCase(),
          ) ??
          false;
      return !wasPerformed;
    }).toList();

    return Scaffold(
      appBar: const ModernAppBar(title: 'Vehicle Details'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (currentVehicle.imageUrl != null)
              Container(
                height: 200,
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  currentVehicle.imageUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 50,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
              ),

            _buildDetailRow(
              context,
              'Make & Model',
              '${currentVehicle.make} ${currentVehicle.model}',
              Icons.directions_car,
            ),
            _buildDetailRow(
              context,
              'Year',
              currentVehicle.year.toString(),
              Icons.calendar_today,
            ),
            _buildDetailRow(
              context,
              'Color',
              currentVehicle.color,
              Icons.color_lens,
            ),
            _buildDetailRow(
              context,
              'Plate Number',
              currentVehicle.plateNumber,
              Icons.confirmation_number,
            ),
            _buildDetailRow(
              context,
              'Assigned Employee',
              driver != null ? driver!.fullName : 'Not Assigned',
              Icons.person,
            ),
            _buildDetailRow(
              context,
              'Status',
              currentVehicle.status ?? 'Active',
              Icons.info_outline,
            ),
            _buildDetailRow(
              context,
              'Department',
              currentVehicle.department ?? 'N/A',
              Icons.business_outlined,
            ),
            const Divider(height: 32),
            _buildSectionHeader('Vehicle Specifications'),
            _buildDetailRow(
              context,
              'VIN Number',
              currentVehicle.vinNumber ?? 'N/A',
              Icons.fingerprint,
            ),
            _buildDetailRow(
              context,
              'Engine Number',
              currentVehicle.engineNumber ?? 'N/A',
              Icons.engineering,
            ),
            Row(
              children: [
                Expanded(
                  child: _buildDetailRow(
                    context,
                    'Fuel Type',
                    currentVehicle.fuelType ?? 'N/A',
                    Icons.local_gas_station,
                  ),
                ),
                Expanded(
                  child: _buildDetailRow(
                    context,
                    'Transmission',
                    currentVehicle.transmission ?? 'N/A',
                    Icons.settings_input_component,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _buildDetailRow(
                    context,
                    'GVWR',
                    currentVehicle.gvwr ?? 'N/A',
                    Icons.monitor_weight,
                  ),
                ),
                Expanded(
                  child: _buildDetailRow(
                    context,
                    'Tire Size',
                    currentVehicle.tireSize ?? 'N/A',
                    Icons.tire_repair,
                  ),
                ),
              ],
            ),
            if (isAdmin) ...[
              const Divider(height: 32),
              _buildSectionHeader('Purchase Information'),
              _buildDetailRow(
                context,
                'Purchase Date',
                currentVehicle.purchaseDate != null
                    ? DateFormat(
                        'yyyy-MM-dd',
                      ).format(currentVehicle.purchaseDate!)
                    : 'N/A',
                Icons.shopping_bag_outlined,
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildDetailRow(
                      context,
                      'Purchase Price',
                      currentVehicle.purchasePrice != null
                          ? currentVehicle.purchasePrice!.toStringAsFixed(2)
                          : 'N/A',
                      Icons.money,
                    ),
                  ),
                  Expanded(
                    child: _buildDetailRow(
                      context,
                      'Current Odometer',
                      currentVehicle.currentOdometer != null
                          ? '${currentVehicle.currentOdometer} KM'
                          : 'N/A',
                      Icons.speed,
                    ),
                  ),
                ],
              ),
            ],
            const Divider(height: 32),
            _buildSectionHeader('Documents'),
            _buildDocumentCard(
              context,
              title: 'Insurance',
              icon: Icons.security_outlined,
              expiryDate: currentVehicle.insurance?.expiryDate,
              attachmentUrl: currentVehicle.insurance?.attachmentUrl,
              onDelete: () {
                _confirmDelete(context, 'Insurance', () {
                  context.read<VehicleProvider>().deleteVehicleDocument(
                    currentVehicle,
                    'Insurance',
                  );
                });
              },
            ),
            _buildDocumentCard(
              context,
              title: 'Isthimara (Registration)',
              icon: Icons.description_outlined,
              expiryDate: currentVehicle.registration?.expiryDate,
              attachmentUrl: currentVehicle.registration?.attachmentUrl,
              onDelete: () {
                _confirmDelete(context, 'Isthimara', () {
                  context.read<VehicleProvider>().deleteVehicleDocument(
                    currentVehicle,
                    'Isthimara',
                  );
                });
              },
            ),
            _buildDocumentCard(
              context,
              title: 'Fahas',
              icon: Icons.fact_check_outlined,
              expiryDate: currentVehicle.fahas?.expiryDate,
              attachmentUrl: currentVehicle.fahas?.attachmentUrl,
              onDelete: () {
                _confirmDelete(context, 'Fahas', () {
                  context.read<VehicleProvider>().deleteVehicleDocument(
                    currentVehicle,
                    'Fahas',
                  );
                });
              },
            ),
            _buildDocumentCard(
              context,
              title: 'Bahrain Insurance',
              icon: Icons.security_outlined,
              expiryDate: currentVehicle.bahrainInsurance?.expiryDate,
              attachmentUrl: currentVehicle.bahrainInsurance?.attachmentUrl,
              onDelete: () {
                _confirmDelete(context, 'Bahrain Insurance', () {
                  context.read<VehicleProvider>().deleteVehicleDocument(
                    currentVehicle,
                    'Bahrain Insurance',
                  );
                });
              },
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader('Tafweed Authorizations'),
                if (currentVehicle.tafweeds == null ||
                    currentVehicle.tafweeds!.isEmpty)
                  TextButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AuthorizeDriverToVehicleDialog(
                          vehicle: currentVehicle,
                        ),
                      );
                    },
                    icon: const Icon(Icons.person_add_alt_1, size: 20),
                    label: const Text('Authorize Driver'),
                  ),
              ],
            ),
            Consumer<EmployeeProvider>(
              builder: (context, empProvider, child) {
                if (currentVehicle.tafweeds == null ||
                    currentVehicle.tafweeds!.isEmpty) {
                  return Card(
                    elevation: 0,
                    color: Colors.grey[100],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.admin_panel_settings_outlined,
                            color: Colors.grey[600],
                            size: 20.sp,
                          ),
                          SizedBox(width: 12.w),
                          Text(
                            'No Authorized Drivers',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...currentVehicle.tafweeds!.map((tafweed) {
                      final driver = empProvider.employees
                          .cast<EmployeeEntity?>()
                          .firstWhere(
                            (e) => e?.id == tafweed.driverId,
                            orElse: () => null,
                          );
                      return _buildDocumentCard(
                        context,
                        title: driver?.fullName ?? 'Unknown Driver',
                        icon: Icons.admin_panel_settings_outlined,
                        expiryDate: tafweed.expiryDate,
                        attachmentUrl: tafweed.attachmentUrl,
                        extraInfo: 'Tafweed Authorization',
                        onCancel: () => _confirmCancelTafweed(
                          context,
                          currentVehicle,
                          tafweed,
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
            const Divider(height: 32),
            _buildTafweedHistorySection(context, currentVehicle),
            const Divider(height: 32),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Maintenance History
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionHeader('Maintenance Records'),
                          TextButton.icon(
                            icon: const Icon(Icons.history, size: 20),
                            label: const Text('View All History'),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      VehicleMaintenanceHistoryScreen(
                                        vehicle: currentVehicle,
                                      ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      if (currentVehicle.maintenanceHistory != null &&
                          currentVehicle.maintenanceHistory!.isNotEmpty) ...[
                        ...((List<MaintenanceRecord>.from(
                              currentVehicle.maintenanceHistory!,
                            ))..sort((a, b) => b.date.compareTo(a.date)))
                            .take(5)
                            .map(
                              (record) => _buildHistoryItem(context, record),
                            ),
                      ] else
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.history_outlined,
                                  size: 48,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No maintenance history available',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(width: 24.w),
                // Right Column: Not Entered Types
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Not Recorded Yet'),
                      if (missingTypes.isNotEmpty)
                        ...missingTypes.map(
                          (type) => _buildMissingTypeItem(
                            context,
                            currentVehicle,
                            type,
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Center(
                            child: Text(
                              'All maintenance types recorded.',
                              style: TextStyle(
                                color: Colors.green[600],
                                fontStyle: FontStyle.italic,
                                fontSize: 13.sp,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissingTypeItem(
    BuildContext context,
    VehicleEntity currentVehicle,
    MaintenanceTypeEntity type,
  ) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange[700],
            size: 16.sp,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              type.name,
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: Colors.orange[900],
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AddMaintenanceRecordDialog(
                  vehicle: currentVehicle,
                  initialMaintenanceTypeId: type.id,
                ),
              );
            },
            icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
            tooltip: 'Add ${type.name}',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, MaintenanceRecord record) {
    final dateStr = DateFormat('yyyy-MM-dd').format(record.date);

    // Attempt to find a suitable icon based on service type
    IconData icon = Icons.build_circle_outlined;
    final type = record.serviceType?.toLowerCase() ?? '';
    if (type.contains('oil')) {
      icon = Icons.oil_barrel_outlined;
    }
    if (type.contains('tyre') || type.contains('tire')) {
      icon = Icons.tire_repair_outlined;
    }
    if (type.contains('battery')) {
      icon = Icons.battery_charging_full_outlined;
    }
    if (type.contains('brake')) {
      icon = Icons.settings_backup_restore_outlined;
    }
    if (type.contains('filter')) {
      icon = Icons.filter_alt_outlined;
    }
    if (type.contains('ac')) {
      icon = Icons.ac_unit_outlined;
    }
    if (type.contains('wash')) {
      icon = Icons.local_car_wash_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.blue, size: 20),
        ),
        title: Text(
          record.serviceType ?? 'General Maintenance',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 15.sp,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4.h),
            Text(
              '$dateStr • ${record.mileage} KM',
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                color: Colors.grey[600],
              ),
            ),
            if (record.notes != null && record.notes!.isNotEmpty) ...[
              SizedBox(height: 4.h),
              Text(
                record.notes!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        trailing: record.cost != null
            ? Text(
                '${record.cost} SAR',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                  fontSize: 14.sp,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildTafweedHistorySection(
    BuildContext context,
    VehicleEntity vehicle,
  ) {
    return Consumer<EmployeeProvider>(
      builder: (context, empProvider, child) {
        final List<_VehicleTafweedHistoryEntry> entries = [];

        // Active tafweeds
        if (vehicle.tafweeds != null) {
          for (final t in vehicle.tafweeds!) {
            final driver = empProvider.employees
                .cast<EmployeeEntity?>()
                .firstWhere((e) => e?.id == t.driverId, orElse: () => null);
            entries.add(
              _VehicleTafweedHistoryEntry(
                record: t,
                driverName: driver?.fullName ?? 'Unknown Driver',
                isActive: true,
              ),
            );
          }
        }

        // Historical tafweeds
        if (vehicle.tafweedHistory != null) {
          for (final t in vehicle.tafweedHistory!) {
            final driver = empProvider.employees
                .cast<EmployeeEntity?>()
                .firstWhere((e) => e?.id == t.driverId, orElse: () => null);
            entries.add(
              _VehicleTafweedHistoryEntry(
                record: t,
                driverName: driver?.fullName ?? 'Unknown Driver',
                isActive: false,
              ),
            );
          }
        }

        if (entries.isEmpty) return const SizedBox.shrink();

        // Sort newest issuedDate first
        entries.sort(
          (a, b) => b.record.issuedDate.compareTo(a.record.issuedDate),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Tafweed History'),
            ...entries
                .take(5)
                .map((entry) => _buildTafweedHistoryItem(context, entry)),
            if (entries.length > 5)
              Padding(
                padding: EdgeInsets.only(top: 8.h),
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TafweedHistoryViewAllScreen(
                          title: 'History: ${vehicle.plateNumber}',
                          id: vehicle.id,
                          type: TafweedHistoryType.vehicle,
                        ),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue[700],
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      side: BorderSide(
                        color: Colors.blue.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  child: const Center(child: Text('View All History')),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTafweedHistoryItem(
    BuildContext context,
    _VehicleTafweedHistoryEntry entry,
  ) {
    final bool isExpired = entry.record.expiryDate.isBefore(DateTime.now());

    Color statusColor = Colors.grey;
    String statusLabel = 'Historical';
    IconData statusIcon = Icons.archive_outlined;

    if (entry.isActive) {
      if (isExpired) {
        statusColor = Colors.red;
        statusLabel = 'Expired';
        statusIcon = Icons.warning_amber_outlined;
      } else {
        statusColor = Colors.green;
        statusLabel = 'Active';
        statusIcon = Icons.check_circle_outline;
      }
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.only(bottom: 12.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(statusIcon, color: statusColor, size: 24.sp),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.driverName,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 12.sp,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '${_formatDate(entry.record.issuedDate)} - ${_formatDate(entry.record.expiryDate)}',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: isExpired && entry.isActive
                              ? Colors.red
                              : Colors.grey[700],
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

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Widget? actionWidget,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (actionWidget != null) actionWidget,
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('dd MMM yyyy').format(date);
  }

  Future<void> _confirmCancelTafweed(
    BuildContext context,
    VehicleEntity currentVehicle,
    TafweedRecord record,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Authorization'),
        content: const Text(
          'Are you sure you want to cancel the current authorization? This will record the end date as today and move it to history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final updatedActiveTafweeds = List<TafweedRecord>.from(
        currentVehicle.tafweeds ?? [],
      )..remove(record);

      final updatedHistory = List<TafweedRecord>.from(
        currentVehicle.tafweedHistory ?? [],
      );
      updatedHistory.add(record.copyWith(expiryDate: DateTime.now()));

      final updatedVehicle = currentVehicle.copyWith(
        tafweeds: updatedActiveTafweeds,
        tafweedHistory: updatedHistory,
      );
      await context.read<VehicleProvider>().updateVehicle(updatedVehicle);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    String title,
    VoidCallback onConfirm,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $title'),
        content: Text(
          'Are you sure you want to delete this document and clear its expiry date?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      onConfirm();
    }
  }

  Widget _buildDocumentCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    DateTime? expiryDate,
    String? attachmentUrl,
    String? extraInfo,
    VoidCallback? onDelete,
    VoidCallback? onCancel,
  }) {
    final bool isExpired =
        expiryDate != null && expiryDate.isBefore(DateTime.now());
    final bool hasAttachment =
        attachmentUrl != null && attachmentUrl.isNotEmpty;

    return Card(
      elevation: 0,
      margin: EdgeInsets.only(bottom: 12.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(icon, color: Colors.blue[700], size: 24.sp),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Text(
                            'Expiry: ${_formatDate(expiryDate)}',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: isExpired ? Colors.red : Colors.grey[700],
                              fontWeight: isExpired
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          if (isExpired) ...[
                            SizedBox(width: 8.w),
                            Icon(Icons.warning, color: Colors.red, size: 14.sp),
                          ],
                        ],
                      ),
                      if (extraInfo != null) ...[
                        SizedBox(height: 4.h),
                        Text(
                          extraInfo,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.red[400],
                      size: 20.sp,
                    ),
                    tooltip: 'Delete Document',
                  ),
              ],
            ),
            if (hasAttachment || onCancel != null) ...[
              SizedBox(height: 12.h),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onCancel != null)
                    Padding(
                      padding: EdgeInsets.only(right: 8.w),
                      child: TextButton.icon(
                        onPressed: onCancel,
                        icon: Icon(Icons.cancel_outlined,
                            color: Colors.orange[700], size: 18.sp),
                        label: Text(
                          'Cancel Authorization',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.orange[50],
                          padding: EdgeInsets.symmetric(horizontal: 12.w),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                      ),
                    ),
                  if (hasAttachment) ...[
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DocumentViewerScreen(
                              attachmentUrl: attachmentUrl,
                              title: title,
                            ),
                          ),
                        );
                      },
                      icon: Icon(Icons.remove_red_eye_outlined, size: 18.sp),
                      label: const Text('Preview'),
                      style: TextButton.styleFrom(foregroundColor: Colors.blue),
                    ),
                    SizedBox(width: 8.w),
                    TextButton.icon(
                      onPressed: () {
                        ShareHelper.shareDocument(
                          context,
                          url: attachmentUrl,
                          title: title,
                        );
                      },
                      icon: Icon(Icons.share_outlined, size: 18.sp),
                      label: const Text('Share'),
                      style: TextButton.styleFrom(foregroundColor: Colors.blue),
                    ),
                  ],
                ],
              ),
            ] else ...[
              SizedBox(height: 12.h),
              const Divider(),
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14.sp,
                    color: Colors.grey[500],
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    'No document attachment found',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VehicleTafweedHistoryEntry {
  final TafweedRecord record;
  final String driverName;
  final bool isActive;

  const _VehicleTafweedHistoryEntry({
    required this.record,
    required this.driverName,
    required this.isActive,
  });
}
