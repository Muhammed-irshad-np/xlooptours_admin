import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:xloop_invoice/screens/vehicle_master_screen.dart'; // Added
import 'package:xloop_invoice/screens/document_viewer_screen.dart';
import 'package:xloop_invoice/core/utils/share_helper.dart';
import 'package:provider/provider.dart';
import '../features/employee/domain/entities/employee_entity.dart';
import '../features/employee/presentation/providers/employee_provider.dart';
import '../features/vehicle/domain/entities/vehicle_entity.dart';
import '../features/vehicle/presentation/providers/vehicle_provider.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  final ValueNotifier<Map<String, EmployeeEntity>> _driversMap = ValueNotifier(
    {},
  );

  @override
  void dispose() {
    _driversMap.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    try {
      await context.read<VehicleProvider>().fetchAllVehicles();
      if (!mounted) return;
      await context.read<EmployeeProvider>().fetchAllEmployees();
      if (!mounted) return;
      final employees = context.read<EmployeeProvider>().employees;
      final Map<String, EmployeeEntity> driversMap = {
        for (var e in employees) e.id: e,
      };

      if (mounted) {
        _driversMap.value = driversMap;
      }
    } catch (e) {
      debugPrint('Error loading vehicles: \$e');
    }
  }

  Future<void> _navigateToAddEdit({VehicleEntity? vehicle}) async {
    final result = await context.push('/vehicles/form', extra: vehicle);
    if (result == true) {
      _loadData();
    }
  }

  Future<void> _deleteVehicle(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vehicle'),
        content: const Text('Are you sure you want to delete this vehicle?'),
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

    if (confirmed == true && mounted) {
      await context.read<VehicleProvider>().deleteVehicle(id);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicleProvider = context.watch<VehicleProvider>();
    final isLoading = vehicleProvider.isLoading;
    final vehicles = vehicleProvider.vehicles;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Fleet Management'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Fleet List', icon: Icon(Icons.directions_car)),
              Tab(text: 'Vehicle Master', icon: Icon(Icons.settings)),
            ],
          ),
          actions: [
            IconButton(
              onPressed: () => _navigateToAddEdit(),
              icon: const Icon(Icons.add),
              tooltip: 'Add Vehicle',
            ),
          ],
        ),
        body: TabBarView(
          children: [
            // Tab 1: Fleet List (Existing UI)
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : vehicles.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.directions_car_outlined,
                          size: 80.sp,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          'No vehicles found',
                          style: TextStyle(color: Colors.grey, fontSize: 18.sp),
                        ),
                        SizedBox(height: 16.h),
                        ElevatedButton(
                          onPressed: () => _navigateToAddEdit(),
                          child: const Text('Add Vehicle'),
                        ),
                      ],
                    ),
                  )
                : ValueListenableBuilder<Map<String, EmployeeEntity>>(
                    valueListenable: _driversMap,
                    builder: (context, driversMap, _) {
                      return ListView.separated(
                        padding: EdgeInsets.all(16.w),
                        itemCount: vehicles.length,
                        separatorBuilder: (context, index) =>
                            SizedBox(height: 16.h),
                        itemBuilder: (context, index) {
                          final vehicle = vehicles[index];
                          final driver = vehicle.assignedDriverId != null
                              ? driversMap[vehicle.assignedDriverId]
                              : null;

                          return _buildVehicleCard(vehicle, driver);
                        },
                      );
                    },
                  ),

            // Tab 2: Vehicle Master
            const VehicleMasterScreen(),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleCard(VehicleEntity vehicle, EmployeeEntity? driver) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 60.w,
          height: 60.w,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8.r),
          ),
          clipBehavior: Clip.antiAlias,
          child: vehicle.imageUrl != null
              ? Image.network(
                  vehicle.imageUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(Icons.broken_image, color: Colors.grey[500]);
                  },
                )
              : Icon(Icons.directions_car, color: Colors.grey[500]),
        ),
        title: Text(
          '${vehicle.make} ${vehicle.model} (${vehicle.year})',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 4.h),
            Text('Plate: ${vehicle.plateNumber} • ${vehicle.color}'),
            SizedBox(height: 4.h),
            Row(
              children: [
                Icon(Icons.person, size: 14.sp, color: Colors.blueGrey),
                SizedBox(width: 4.w),
                Text(
                  driver != null ? driver.fullName : 'No Employee Assigned',
                  style: TextStyle(
                    color: driver != null ? Colors.black87 : Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(
                Icons.remove_red_eye_outlined,
                color: Colors.blue,
              ),
              onPressed: () => _showDetails(vehicle, driver),
              tooltip: 'View Details',
            ),
            PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  _navigateToAddEdit(vehicle: vehicle);
                } else if (value == 'delete') {
                  _deleteVehicle(vehicle.id);
                }
              },
            ),
          ],
        ),
        onTap: () => _showDetails(vehicle, driver),
      ),
    );
  }

  void _showDetails(VehicleEntity vehicle, EmployeeEntity? driver) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Vehicle Details',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(height: 32),
              Flexible(
                child: SingleChildScrollView(
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
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
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
                        'Make & Model',
                        '${vehicle.make} ${vehicle.model}',
                        Icons.directions_car,
                      ),
                      _buildDetailRow(
                        'Year',
                        vehicle.year.toString(),
                        Icons.calendar_today,
                      ),
                      _buildDetailRow('Color', vehicle.color, Icons.color_lens),
                      _buildDetailRow(
                        'Plate Number',
                        vehicle.plateNumber,
                        Icons.confirmation_number,
                      ),
                      _buildDetailRow('Type', vehicle.type, Icons.category),
                      _buildDetailRow(
                        'Assigned Employee',
                        driver != null ? driver.fullName : 'Not Assigned',
                        Icons.person,
                      ),
                      const Divider(height: 32),
                      _buildSectionHeader('Documents'),
                       _buildDetailRow(
                        'Insurance Expiry',
                        vehicle.insurance?.expiryDate != null
                            ? DateFormat('yyyy-MM-dd').format(vehicle.insurance!.expiryDate)
                            : 'N/A',
                        Icons.security_outlined,
                        attachmentUrl: vehicle.insurance?.attachmentUrl,
                      ),
                       _buildDetailRow(
                        'Isthimara (Registration) Expiry',
                        vehicle.registration?.expiryDate != null
                            ? DateFormat('yyyy-MM-dd').format(vehicle.registration!.expiryDate)
                            : 'N/A',
                        Icons.description_outlined,
                        attachmentUrl: vehicle.registration?.attachmentUrl,
                      ),
                       _buildDetailRow(
                        'Fahas Expiry',
                        vehicle.fahas?.expiryDate != null
                            ? DateFormat('yyyy-MM-dd').format(vehicle.fahas!.expiryDate)
                            : 'N/A',
                        Icons.fact_check_outlined,
                        attachmentUrl: vehicle.fahas?.attachmentUrl,
                      ),
                      const Divider(height: 32),
                      _buildSectionHeader('Maintenance Records'),
                      if (vehicle.maintenance != null) ...[
                        _buildMaintenanceDetail(
                          'Engine Oil',
                          vehicle.maintenance!.engineOil,
                          Icons.oil_barrel,
                        ),
                        _buildMaintenanceDetail(
                          'Gear Oil',
                          vehicle.maintenance!.gearOil,
                          Icons.settings_suggest,
                        ),
                        _buildMaintenanceDetail(
                          'Housing Oil',
                          vehicle.maintenance!.housingOil,
                          Icons.format_color_fill,
                        ),
                        _buildMaintenanceDetail(
                          'Tyre Change',
                          vehicle.maintenance!.tyreChange,
                          Icons.tire_repair,
                        ),
                        _buildMaintenanceDetail(
                          'Battery Change',
                          vehicle.maintenance!.batteryChange,
                          Icons.battery_charging_full,
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
              ),
            ],
          ),
        ),
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

   Widget _buildMaintenanceDetail(
    String label,
    dynamic record, // MaintenanceRecord?
    IconData icon,
  ) {
    if (record == null) {
      return _buildDetailRow(label, 'No record', icon);
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(record.date);
    return _buildDetailRow(
      label,
      '$dateStr at ${record.mileage} KM',
      icon,
      attachmentUrl: record.attachmentUrl,
    );
  }

  Widget _buildDetailRow(
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
              icon: const Icon(Icons.remove_red_eye_outlined, color: Colors.blue),
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
