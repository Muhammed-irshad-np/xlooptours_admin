import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../features/vehicle/domain/entities/vehicle_entity.dart';
import '../features/vehicle/domain/entities/vehicle_documents.dart';
import '../features/employee/domain/entities/employee_entity.dart';
import 'vehicle_maintenance_history_screen.dart';
import 'document_viewer_screen.dart';
import '../core/utils/share_helper.dart';
import '../core/widgets/modern_app_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class VehicleDetailScreen extends StatelessWidget {
  final VehicleEntity vehicle;
  final EmployeeEntity? driver;

  const VehicleDetailScreen({super.key, required this.vehicle, this.driver});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ModernAppBar(title: 'Vehicle Details'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (vehicle.imageUrl != null)
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
                  vehicle.imageUrl!,
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
              '${vehicle.make} ${vehicle.model}',
              Icons.directions_car,
            ),
            _buildDetailRow(
              context,
              'Year',
              vehicle.year.toString(),
              Icons.calendar_today,
            ),
            _buildDetailRow(context, 'Color', vehicle.color, Icons.color_lens),
            _buildDetailRow(
              context,
              'Plate Number',
              vehicle.plateNumber,
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
              vehicle.status ?? 'Active',
              Icons.info_outline,
            ),
            _buildDetailRow(
              context,
              'Department',
              vehicle.department ?? 'N/A',
              Icons.business_outlined,
            ),
            const Divider(height: 32),
            _buildSectionHeader('Vehicle Specifications'),
            _buildDetailRow(
              context,
              'VIN Number',
              vehicle.vinNumber ?? 'N/A',
              Icons.fingerprint,
            ),
            _buildDetailRow(
              context,
              'Engine Number',
              vehicle.engineNumber ?? 'N/A',
              Icons.engineering,
            ),
            Row(
              children: [
                Expanded(
                  child: _buildDetailRow(
                    context,
                    'Fuel Type',
                    vehicle.fuelType ?? 'N/A',
                    Icons.local_gas_station,
                  ),
                ),
                Expanded(
                  child: _buildDetailRow(
                    context,
                    'Transmission',
                    vehicle.transmission ?? 'N/A',
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
                    vehicle.gvwr ?? 'N/A',
                    Icons.monitor_weight,
                  ),
                ),
                Expanded(
                  child: _buildDetailRow(
                    context,
                    'Tire Size',
                    vehicle.tireSize ?? 'N/A',
                    Icons.tire_repair,
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            _buildSectionHeader('Purchase Information'),
            _buildDetailRow(
              context,
              'Purchase Date',
              vehicle.purchaseDate != null
                  ? DateFormat('yyyy-MM-dd').format(vehicle.purchaseDate!)
                  : 'N/A',
              Icons.shopping_bag_outlined,
            ),
            Row(
              children: [
                Expanded(
                  child: _buildDetailRow(
                    context,
                    'Purchase Price',
                    vehicle.purchasePrice != null
                        ? vehicle.purchasePrice!.toStringAsFixed(2)
                        : 'N/A',
                    Icons.money,
                  ),
                ),
                Expanded(
                  child: _buildDetailRow(
                    context,
                    'Current Odometer',
                    vehicle.currentOdometer != null
                        ? '${vehicle.currentOdometer} KM'
                        : 'N/A',
                    Icons.speed,
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            _buildSectionHeader('Documents'),
            _buildDetailRow(
              context,
              'Insurance Expiry',
              vehicle.insurance?.expiryDate != null
                  ? DateFormat(
                      'yyyy-MM-dd',
                    ).format(vehicle.insurance!.expiryDate)
                  : 'N/A',
              Icons.security_outlined,
              attachmentUrl: vehicle.insurance?.attachmentUrl,
            ),
            _buildDetailRow(
              context,
              'Isthimara (Registration) Expiry',
              vehicle.registration?.expiryDate != null
                  ? DateFormat(
                      'yyyy-MM-dd',
                    ).format(vehicle.registration!.expiryDate)
                  : 'N/A',
              Icons.description_outlined,
              attachmentUrl: vehicle.registration?.attachmentUrl,
            ),
            _buildDetailRow(
              context,
              'Fahas Expiry',
              vehicle.fahas?.expiryDate != null
                  ? DateFormat('yyyy-MM-dd').format(vehicle.fahas!.expiryDate)
                  : 'N/A',
              Icons.fact_check_outlined,
              attachmentUrl: vehicle.fahas?.attachmentUrl,
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                            VehicleMaintenanceHistoryScreen(vehicle: vehicle),
                      ),
                    );
                  },
                ),
              ],
            ),
            if (vehicle.maintenanceHistory != null &&
                vehicle.maintenanceHistory!.isNotEmpty) ...[
              ...((List<MaintenanceRecord>.from(vehicle.maintenanceHistory!))
                    ..sort((a, b) => b.date.compareTo(a.date)))
                  .take(5)
                  .map((record) => _buildHistoryItem(context, record)),
            ] else
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.history_outlined,
                          size: 48, color: Colors.grey[300]),
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
    );
  }

  Widget _buildHistoryItem(BuildContext context, MaintenanceRecord record) {
    final dateStr = DateFormat('yyyy-MM-dd').format(record.date);
    
    // Attempt to find a suitable icon based on service type
    IconData icon = Icons.build_circle_outlined;
    final type = record.serviceType?.toLowerCase() ?? '';
    if (type.contains('oil')) icon = Icons.oil_barrel_outlined;
    if (type.contains('tyre') || type.contains('tire')) icon = Icons.tire_repair_outlined;
    if (type.contains('battery')) icon = Icons.battery_charging_full_outlined;
    if (type.contains('brake')) icon = Icons.settings_backup_restore_outlined;
    if (type.contains('filter')) icon = Icons.filter_alt_outlined;
    if (type.contains('ac')) icon = Icons.ac_unit_outlined;

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
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
            color: Colors.blue.withOpacity(0.1),
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


  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    String? attachmentUrl,
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
          if (attachmentUrl != null && attachmentUrl.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.share, color: Color(0xFF13b1f2)),
              onPressed: () {
                ShareHelper.shareDocument(
                  context,
                  url: attachmentUrl,
                  title: label,
                );
              },
              tooltip: 'Share Attachment',
            ),
            IconButton(
              icon: const Icon(
                Icons.remove_red_eye_outlined,
                color: Colors.blue,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DocumentViewerScreen(
                      attachmentUrl: attachmentUrl,
                      title: label,
                    ),
                  ),
                );
              },
              tooltip: 'View Attachment',
            ),
          ],
        ],
      ),
    );
  }
}
