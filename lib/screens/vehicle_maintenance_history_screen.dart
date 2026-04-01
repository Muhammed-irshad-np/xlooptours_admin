import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_entity.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_documents.dart';
import 'package:xloop_invoice/screens/document_viewer_screen.dart';

class VehicleMaintenanceHistoryScreen extends StatelessWidget {
  final VehicleEntity vehicle;

  const VehicleMaintenanceHistoryScreen({super.key, required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final List<MaintenanceRecord> history = _gatherAllHistory(vehicle);

    history.sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        title: Text('${vehicle.make} ${vehicle.model} - History'),
        elevation: 0,
      ),
      body: history.isEmpty
          ? const Center(
              child: Text(
                'No maintenance history available.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final record = history[index];
                return _buildHistoryCard(context, record);
              },
            ),
    );
  }

  List<MaintenanceRecord> _gatherAllHistory(VehicleEntity vehicle) {
    final List<MaintenanceRecord> history = List.from(vehicle.maintenanceHistory ?? []);

    // For backwards compatibility, if maintenanceHistory is empty, extract from Maintenance objects
    if (history.isEmpty && vehicle.maintenance != null) {
      final m = vehicle.maintenance!;
      _addRecordIfNotNull(history, m.engineOil, 'Engine Oil');
      _addRecordIfNotNull(history, m.gearOil, 'Gear Oil');
      _addRecordIfNotNull(history, m.housingOil, 'Housing Oil');
      _addRecordIfNotNull(history, m.tyreChange, 'Tyre Change');
      _addRecordIfNotNull(history, m.batteryChange, 'Battery Change');
      _addRecordIfNotNull(history, m.brakePads, 'Brake Pads');
      _addRecordIfNotNull(history, m.airFilter, 'Air Filter');
      _addRecordIfNotNull(history, m.acService, 'AC Service');
      _addRecordIfNotNull(history, m.wheelAlignment, 'Wheel Alignment');
      _addRecordIfNotNull(history, m.sparkPlugs, 'Spark Plugs');
      _addRecordIfNotNull(history, m.coolantFlush, 'Coolant Flush');
      _addRecordIfNotNull(history, m.wiperBlades, 'Wiper Blades');
      _addRecordIfNotNull(history, m.timingBelt, 'Timing Belt');
      _addRecordIfNotNull(history, m.transmissionFluid, 'Transmission Fluid');
      _addRecordIfNotNull(history, m.brakeFluid, 'Brake Fluid');
      _addRecordIfNotNull(history, m.fuelFilter, 'Fuel Filter');
    }

    return history;
  }

  void _addRecordIfNotNull(List<MaintenanceRecord> history, MaintenanceRecord? record, String overrideType) {
    if (record != null) {
      history.add(
        MaintenanceRecord(
          date: record.date,
          mileage: record.mileage,
          attachmentUrl: record.attachmentUrl,
          notificationDays: record.notificationDays,
          cost: record.cost,
          partsCost: record.partsCost,
          laborCost: record.laborCost,
          serviceProvider: record.serviceProvider,
          workOrderNumber: record.workOrderNumber,
          serviceType: record.serviceType ?? overrideType,
          partsReplaced: record.partsReplaced,
          notes: record.notes,
          nextServiceMileage: record.nextServiceMileage,
          nextServiceDate: record.nextServiceDate,
        ),
      );
    }
  }

  Widget _buildHistoryCard(BuildContext context, MaintenanceRecord record) {
    final dateStr = DateFormat('MMM dd, yyyy').format(record.date);
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    record.serviceType?.toUpperCase() ?? 'MAINTENANCE RECORD',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(Icons.speed, 'Mileage', '${record.mileage} KM'),
            if (record.serviceProvider != null && record.serviceProvider!.isNotEmpty)
              _buildInfoRow(Icons.build_circle, 'Provider', record.serviceProvider!),
            if (record.workOrderNumber != null && record.workOrderNumber!.isNotEmpty)
              _buildInfoRow(Icons.receipt_long, 'Work Order', record.workOrderNumber!),
            if (record.cost != null)
              _buildInfoRow(Icons.attach_money, 'Total Cost', '\$${record.cost!.toStringAsFixed(2)}'),
            if (record.notes != null && record.notes!.isNotEmpty)
              _buildInfoRow(Icons.notes, 'Notes', record.notes!),
            
            if (record.attachmentUrl != null && record.attachmentUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.remove_red_eye, size: 18),
                  label: const Text('View Document'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DocumentViewerScreen(
                          attachmentUrl: record.attachmentUrl!,
                          title: '${record.serviceType ?? 'Maintenance'} Document',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
