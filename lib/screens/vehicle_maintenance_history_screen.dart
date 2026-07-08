import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_entity.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_documents.dart';
import 'package:xloop_invoice/features/vehicle/presentation/providers/vehicle_provider.dart';
import 'package:xloop_invoice/core/widgets/modern_app_bar.dart';
import 'package:xloop_invoice/screens/document_viewer_screen.dart';
import 'package:xloop_invoice/features/auth/presentation/providers/auth_provider.dart';
import 'package:xloop_invoice/widgets/complete_follow_up_dialog.dart';

class VehicleMaintenanceHistoryScreen extends StatefulWidget {
  final VehicleEntity vehicle;

  const VehicleMaintenanceHistoryScreen({super.key, required this.vehicle});

  @override
  State<VehicleMaintenanceHistoryScreen> createState() =>
      _VehicleMaintenanceHistoryScreenState();
}

class _VehicleMaintenanceHistoryScreenState
    extends State<VehicleMaintenanceHistoryScreen> {
  String _selectedFilter = 'All'; // 'All', 'Follow-ups', 'Extensions'

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().user?.isAdmin ?? false;
    return Consumer<VehicleProvider>(
      builder: (context, vehicleProvider, child) {
        final matches = vehicleProvider.vehicles.where(
          (v) => v.id == widget.vehicle.id,
        );
        final VehicleEntity currentVehicle = matches.isNotEmpty
            ? matches.first
            : widget.vehicle;

        final List<MaintenanceRecord> history = _gatherAllHistory(
          currentVehicle,
        );
        history.sort((a, b) => b.date.compareTo(a.date));

        final filteredHistory = history.where((record) {
          if (_selectedFilter == 'Follow-ups') {
            return record.isFollowUpRequired == true;
          } else if (_selectedFilter == 'Extensions') {
            return (record.serviceType != null &&
                    record.serviceType!.startsWith('Extension:'));
          }
          return true; // 'All'
        }).toList();

        return Scaffold(
          appBar: ModernAppBar(
            title: '${currentVehicle.make} ${currentVehicle.model} - History',
          ),
          body: Column(
            children: [
              _buildFilterBar(),
              Expanded(
                child: filteredHistory.isEmpty
                    ? Center(
                        child: Text(
                          'No ${_selectedFilter.toLowerCase()} available.',
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredHistory.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final record = filteredHistory[index];
                          return _buildHistoryCard(
                            context,
                            currentVehicle,
                            record,
                            isAdmin: isAdmin,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterBar() {
    final filters = ['All', 'Follow-ups', 'Extensions'];
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
      color: Colors.white,
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: ChoiceChip(
              label: Text(
                filter,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13.sp,
                ),
              ),
              selected: isSelected,
              onSelected: (val) {
                if (val) {
                  setState(() {
                    _selectedFilter = filter;
                  });
                }
              },
              selectedColor: Colors.blue[700],
              backgroundColor: Colors.grey[100],
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
                side: BorderSide(
                  color: isSelected
                      ? Colors.blue.shade700
                      : Colors.grey.shade300,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<MaintenanceRecord> _gatherAllHistory(VehicleEntity vehicle) {
    final List<MaintenanceRecord> history = List.from(
      vehicle.maintenanceHistory ?? [],
    );

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

  void _addRecordIfNotNull(
    List<MaintenanceRecord> history,
    MaintenanceRecord? record,
    String overrideType,
  ) {
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

  Widget _buildHistoryCard(
    BuildContext context,
    VehicleEntity currentVehicle,
    MaintenanceRecord record, {
    required bool isAdmin,
  }) {
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        onPressed: () => _showDeleteConfirmation(
                          context,
                          currentVehicle,
                          record,
                        ),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (record.isFollowUpRequired == true) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: record.isFollowUpCompleted == true
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: record.isFollowUpCompleted == true
                            ? Colors.green.shade300
                            : Colors.orange.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          record.isFollowUpCompleted == true
                              ? Icons.check_circle_outline
                              : Icons.warning_amber_rounded,
                          size: 14,
                          color: record.isFollowUpCompleted == true
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          record.isFollowUpCompleted == true
                              ? 'Follow-up Completed'
                              : 'Follow-up Pending',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: record.isFollowUpCompleted == true
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (record.isFollowUpCompleted != true) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _markFollowUpAsCompleted(
                        context,
                        currentVehicle,
                        record,
                      ),
                      icon: const Icon(Icons.check, size: 14),
                      label: const Text(
                        'Mark Completed',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const Divider(height: 24),
            _buildInfoRow(Icons.speed, 'Mileage', '${record.mileage} KM'),
            if (record.isFollowUpRequired == true) ...[
              _buildInfoRow(
                Icons.info_outline,
                'Follow-up Reason',
                record.followUpReason ?? 'General Revisit',
              ),
              if (record.nextServiceDate != null)
                _buildInfoRow(
                  Icons.calendar_month,
                  'Follow-up Date',
                  DateFormat('MMM dd, yyyy').format(record.nextServiceDate!),
                ),
              if (record.nextServiceMileage != null && record.nextServiceMileage! > 0)
                _buildInfoRow(
                  Icons.speed,
                  'Follow-up Odometer',
                  '${record.nextServiceMileage} KM',
                ),
            ],
            if (record.serviceProvider != null &&
                record.serviceProvider!.isNotEmpty)
              _buildInfoRow(
                Icons.build_circle,
                'Provider',
                record.serviceProvider!,
              ),
            if (record.workOrderNumber != null &&
                record.workOrderNumber!.isNotEmpty)
              _buildInfoRow(
                Icons.receipt_long,
                'Work Order',
                record.workOrderNumber!,
              ),
            if (record.cost != null)
              _buildInfoRow(
                Icons.attach_money,
                'Total Cost',
                '\$${record.cost!.toStringAsFixed(2)}',
              ),
            if (record.notes != null && record.notes!.isNotEmpty)
              _buildInfoRow(Icons.notes, 'Notes', record.notes!),
            if (record.performedBy != null && record.performedBy!.isNotEmpty)
              _buildInfoRow(Icons.person_outline, 'Logged by', record.performedBy!),
            if (record.followUpCompletions != null && record.followUpCompletions!.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                'Follow-up Visits Logged (${record.followUpCompletions!.length}/${record.followUpTimesCount ?? 1}):',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
              const SizedBox(height: 8),
              ...record.followUpCompletions!.asMap().entries.map((entry) {
                final index = entry.key;
                final completion = entry.value;
                final dateStr = DateFormat('MMM dd, yyyy').format(completion.date);
                
                return Container(
                  margin: EdgeInsets.only(bottom: 8.h),
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Visit #${index + 1}',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                          Text(
                            dateStr,
                            style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Icon(Icons.speed, size: 12.sp, color: Colors.grey[600]),
                          SizedBox(width: 4.w),
                          Text('${completion.mileage} KM', style: TextStyle(fontSize: 12.sp)),
                          SizedBox(width: 16.w),
                          Icon(Icons.attach_money, size: 12.sp, color: Colors.grey[600]),
                          SizedBox(width: 4.w),
                          Text('${completion.cost.toStringAsFixed(2)} SAR', style: TextStyle(fontSize: 12.sp)),
                        ],
                      ),
                      if (completion.notes != null && completion.notes!.isNotEmpty) ...[
                        SizedBox(height: 4.h),
                        Text(
                          'Notes: ${completion.notes!}',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.grey[700],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      if (completion.performedBy != null && completion.performedBy!.isNotEmpty) ...[
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            Icon(Icons.person_outline, size: 12.sp, color: Colors.grey[600]),
                            SizedBox(width: 4.w),
                            Text(
                              'Completed by: ${completion.performedBy!}',
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (completion.attachmentUrls != null && completion.attachmentUrls!.isNotEmpty) ...[
                        SizedBox(height: 4.h),
                        Wrap(
                          spacing: 6.w,
                          children: completion.attachmentUrls!.asMap().entries.map((attachEntry) {
                            final fileIdx = attachEntry.key;
                            final url = attachEntry.value;
                            return ActionChip(
                              avatar: Icon(
                                Icons.file_present_rounded,
                                size: 12.sp,
                                color: Colors.blue.shade700,
                              ),
                              label: Text('Receipt #${fileIdx + 1}', style: TextStyle(fontSize: 10.sp)),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              backgroundColor: Colors.blue.shade50.withValues(alpha: 0.5),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DocumentViewerScreen(
                                      attachmentUrl: url,
                                      title: 'Completion Receipt',
                                    ),
                                  ),
                                );
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ],
            (() {
              final List<String> urls = [];
              if (record.attachmentUrls != null && record.attachmentUrls!.isNotEmpty) {
                urls.addAll(record.attachmentUrls!);
              } else if (record.attachmentUrl != null && record.attachmentUrl!.isNotEmpty) {
                urls.add(record.attachmentUrl!);
              }

              if (urls.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Documents:',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: urls.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final url = entry.value;
                      final displayName = urls.length == 1 ? 'Receipt' : 'Receipt #${idx + 1}';

                      return ActionChip(
                        avatar: Icon(
                          Icons.file_present_rounded,
                          size: 16.sp,
                          color: Colors.blue.shade700,
                        ),
                        label: Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        backgroundColor: Colors.blue.shade50.withValues(alpha: 0.5),
                        side: BorderSide(color: Colors.blue.shade100),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DocumentViewerScreen(
                                attachmentUrl: url,
                                title: '${record.serviceType ?? 'Maintenance'} - $displayName',
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                ],
              );
            })(),
          ],
        ),
      ),
    );
  }

  Future<void> _markFollowUpAsCompleted(
    BuildContext context,
    VehicleEntity currentVehicle,
    MaintenanceRecord record,
  ) async {
    showDialog(
      context: context,
      builder: (context) => CompleteFollowUpDialog(
        vehicle: currentVehicle,
        record: record,
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    VehicleEntity currentVehicle,
    MaintenanceRecord record,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Record'),
        content: const Text(
          'Are you sure you want to delete this maintenance record? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<VehicleProvider>().deleteMaintenanceRecord(
                currentVehicle,
                record,
              );
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
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
