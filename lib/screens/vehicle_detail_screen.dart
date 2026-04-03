import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../features/vehicle/domain/entities/vehicle_entity.dart';
import '../features/employee/domain/entities/employee_entity.dart';
import 'vehicle_maintenance_history_screen.dart';
import 'package:provider/provider.dart';
import 'document_viewer_screen.dart';
import '../features/vehicle/presentation/providers/vehicle_provider.dart';
import '../core/utils/share_helper.dart';
import '../core/widgets/modern_app_bar.dart';

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
                  label: const Text('View History'),
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
            if (vehicle.maintenance != null) ...[
              _buildMaintenanceDetail(
                context,
                'Engine Oil',
                vehicle.maintenance!.engineOil,
                Icons.oil_barrel,
                vehicle.currentOdometer,
                _getInterval(context, 'engine_oil'),
              ),
              _buildMaintenanceDetail(
                context,
                'Gear Oil',
                vehicle.maintenance!.gearOil,
                Icons.settings_suggest,
                vehicle.currentOdometer,
                _getInterval(context, 'gear_oil'),
              ),
              _buildMaintenanceDetail(
                context,
                'Housing Oil',
                vehicle.maintenance!.housingOil,
                Icons.format_color_fill,
                vehicle.currentOdometer,
                _getInterval(context, 'housing_oil'),
              ),
              _buildMaintenanceDetail(
                context,
                'Tyre Change',
                vehicle.maintenance!.tyreChange,
                Icons.tire_repair,
                vehicle.currentOdometer,
                _getInterval(context, 'tyre_change'),
              ),
              _buildMaintenanceDetail(
                context,
                'Battery Change',
                vehicle.maintenance!.batteryChange,
                Icons.battery_charging_full,
                vehicle.currentOdometer,
                _getInterval(context, 'battery_change'),
              ),
              _buildMaintenanceDetail(
                context,
                'Brake Pads',
                vehicle.maintenance!.brakePads,
                Icons.settings_backup_restore,
                vehicle.currentOdometer,
                _getInterval(context, 'brake_pads'),
              ),
              _buildMaintenanceDetail(
                context,
                'Air Filter',
                vehicle.maintenance!.airFilter,
                Icons.air,
                vehicle.currentOdometer,
                _getInterval(context, 'air_filter'),
              ),
              _buildMaintenanceDetail(
                context,
                'AC Service',
                vehicle.maintenance!.acService,
                Icons.ac_unit,
                vehicle.currentOdometer,
                _getInterval(context, 'ac_service'),
              ),
              _buildMaintenanceDetail(
                context,
                'Wheel Alignment',
                vehicle.maintenance!.wheelAlignment,
                Icons.align_horizontal_center,
                vehicle.currentOdometer,
                _getInterval(context, 'wheel_alignment'),
              ),
              _buildMaintenanceDetail(
                context,
                'Spark Plugs',
                vehicle.maintenance!.sparkPlugs,
                Icons.electric_bolt,
                vehicle.currentOdometer,
                _getInterval(context, 'spark_plugs'),
              ),
              _buildMaintenanceDetail(
                context,
                'Coolant Flush',
                vehicle.maintenance!.coolantFlush,
                Icons.water_drop,
                vehicle.currentOdometer,
                _getInterval(context, 'coolant_flush'),
              ),
              _buildMaintenanceDetail(
                context,
                'Wiper Blades',
                vehicle.maintenance!.wiperBlades,
                Icons.cleaning_services,
                vehicle.currentOdometer,
                _getInterval(context, 'wiper_blades'),
              ),
              _buildMaintenanceDetail(
                context,
                'Timing Belt',
                vehicle.maintenance!.timingBelt,
                Icons.conveyor_belt,
                vehicle.currentOdometer,
                _getInterval(context, 'timing_belt'),
              ),
              _buildMaintenanceDetail(
                context,
                'Transmission Fluid',
                vehicle.maintenance!.transmissionFluid,
                Icons.opacity,
                vehicle.currentOdometer,
                _getInterval(context, 'transmission_fluid'),
              ),
              _buildMaintenanceDetail(
                context,
                'Brake Fluid',
                vehicle.maintenance!.brakeFluid,
                Icons.invert_colors,
                vehicle.currentOdometer,
                _getInterval(context, 'brake_fluid'),
              ),
              _buildMaintenanceDetail(
                context,
                'Fuel Filter',
                vehicle.maintenance!.fuelFilter,
                Icons.filter_alt,
                vehicle.currentOdometer,
                _getInterval(context, 'fuel_filter'),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  'No maintenance records available',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  int? _getInterval(BuildContext context, String typeId) {
    try {
      final types = context.read<VehicleProvider>().maintenanceTypes;
      final type = types.firstWhere((t) => t.id == typeId);
      return type.defaultIntervalKm;
    } catch (e) {
      return null;
    }
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

  Widget _buildMaintenanceDetail(
    BuildContext context,
    String label,
    dynamic record, // MaintenanceRecord?
    IconData icon,
    int? currentOdometer,
    int? intervalKm,
  ) {
    if (record == null) {
      return _buildDetailRow(context, label, 'No record', icon);
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(record.date);
    String valueStr = '$dateStr at ${record.mileage} KM';

    if (currentOdometer != null && intervalKm != null) {
      final int remainingKm = (record.mileage + intervalKm) - currentOdometer;
      String statusStr = 'Healthy';
      Color statusColor = Colors.green;

      if (remainingKm <= 0) {
        statusStr = 'Overdue';
        statusColor = Colors.red;
      } else if (remainingKm <= 1000) {
        statusStr = 'Due Soon';
        statusColor = Colors.orange;
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                        valueStr,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          '$statusStr ($remainingKm KM left)',
                          style: TextStyle(
                            fontSize: 12,
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (record.attachmentUrl != null &&
                record.attachmentUrl!.isNotEmpty)
              IconButton(
                icon: const Icon(
                  Icons.remove_red_eye,
                  color: Colors.blue,
                  size: 20,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DocumentViewerScreen(
                        attachmentUrl: record.attachmentUrl!,
                        title: '$label Document',
                      ),
                    ),
                  );
                },
                tooltip: 'View Document',
              ),
          ],
        ),
      );
    }

    // Default row if no interval/odometer
    return _buildDetailRow(
      context,
      label,
      valueStr,
      icon,
      attachmentUrl: record.attachmentUrl,
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
