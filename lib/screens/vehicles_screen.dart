import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:xloop_invoice/screens/vehicle_master_screen.dart'; // Added
import 'package:xloop_invoice/screens/vehicle_detail_screen.dart';
import 'package:provider/provider.dart';
import '../widgets/add_maintenance_record_dialog.dart';
import '../features/employee/domain/entities/employee_entity.dart';
import '../features/employee/presentation/providers/employee_provider.dart';
import '../features/vehicle/domain/entities/vehicle_entity.dart';
import '../features/vehicle/presentation/providers/vehicle_provider.dart';
import '../core/widgets/modern_app_bar.dart';
import '../core/widgets/modern_tab_bar.dart';

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

  Future<void> _showAddMaintenance(VehicleEntity vehicle) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddMaintenanceRecordDialog(vehicle: vehicle),
    );
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
        appBar: ModernAppBar(
          title: 'Fleet Management',
          actions: [
            IconButton(
              onPressed: () => _navigateToAddEdit(),
              icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
              tooltip: 'Add Vehicle',
            ),
          ],
          bottom: const ModernTabBar(
            tabs: [
              Tab(text: 'Fleet List'),
              Tab(text: 'Vehicle Master'),
            ],
          ),
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
                  value: 'add_maintenance',
                  child: Row(
                    children: [
                      Icon(
                        Icons.build_circle_outlined,
                        size: 20,
                        color: Colors.blueGrey,
                      ),
                      SizedBox(width: 8),
                      Text('Add Maintenance'),
                    ],
                  ),
                ),
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
                if (value == 'add_maintenance') {
                  _showAddMaintenance(vehicle);
                } else if (value == 'edit') {
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            VehicleDetailScreen(vehicle: vehicle, driver: driver),
      ),
    );
  }
}
