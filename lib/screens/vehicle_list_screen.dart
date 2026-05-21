import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../features/employee/domain/entities/employee_entity.dart';
import '../features/employee/presentation/providers/employee_provider.dart';
import '../features/vehicle/domain/entities/vehicle_entity.dart';
import '../features/vehicle/presentation/providers/vehicle_provider.dart';
import '../features/notifications/presentation/providers/notification_provider.dart';
import '../core/widgets/action_items_dialog.dart';
import 'vehicle_detail_screen.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fleet Management'),
        actions: [
          IconButton(
            onPressed: () => context.push('/vehicles/masters'), // Go to Masters
            icon: const Icon(Icons.copy_all),
            tooltip: 'Manage Templates',
          ),
          IconButton(
            onPressed: () => _navigateToAddEdit(),
            icon: const Icon(Icons.add),
            tooltip: 'Add Vehicle',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : vehicles.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                  separatorBuilder: (context, index) => SizedBox(height: 16.h),
                  itemBuilder: (context, index) {
                    final vehicle = vehicles[index];
                    final driver = vehicle.currentDriverId != null
                        ? driversMap[vehicle.currentDriverId]
                        : null;

                    return Card(
                      child: ListTile(
                        leading: Container(
                          width: 60.w,
                          height: 60.w,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8.r),
                            image: vehicle.imageUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(vehicle.imageUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: vehicle.imageUrl == null
                              ? Icon(
                                  Icons.directions_car,
                                  color: Colors.grey[500],
                                )
                              : null,
                        ),
                        title: Text(
                          '${vehicle.make} ${vehicle.model} (${vehicle.year})',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16.sp,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 4.h),
                            Text(
                              'Plate: ${vehicle.plateNumber} • ${vehicle.color}',
                            ),
                            SizedBox(height: 4.h),
                            Row(
                              children: [
                                Icon(
                                  Icons.person,
                                  size: 14.sp,
                                  color: Colors.blueGrey,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  driver != null
                                      ? driver.fullName
                                      : 'No Tafweed Issued',
                                  style: TextStyle(
                                    color: driver != null
                                        ? Colors.black87
                                        : Colors.orange,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4.h),
                            Row(
                              children: [
                                Icon(
                                  Icons.speed,
                                  size: 14.sp,
                                  color: Colors.blueGrey,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  'Odometer: ${vehicle.currentOdometer ?? 0} KM',
                                  style: TextStyle(
                                    color: Colors.black87,
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
                              onPressed: () => _showDetails(vehicle),
                              tooltip: 'View Details',
                            ),
                            Consumer<NotificationProvider>(
                              builder: (context, provider, _) {
                                final alerts = provider
                                    .getNotificationsByRelatedId(vehicle.id);
                                if (alerts.isEmpty) {
                                  return const SizedBox.shrink();
                                }

                                return IconButton(
                                  onPressed:
                                      () => ActionItemsDialog.show(
                                        context,
                                        '${vehicle.make} ${vehicle.model} (${vehicle.plateNumber})',
                                        vehicle.id,
                                      ),
                                  icon: Badge(
                                    label: Text(
                                      alerts.length.toString(),
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        color: Colors.white,
                                      ),
                                    ),
                                    backgroundColor: Colors.red,
                                    child: Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.red,
                                      size: 24.sp,
                                    ),
                                  ),
                                  tooltip: 'Action Items',
                                );
                              },
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
                                      Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
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
                        onTap: () => _showDetails(
                          vehicle,
                        ), // Tap opens details now instead of edit
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  void _showDetails(VehicleEntity vehicle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            VehicleDetailScreen(vehicle: vehicle),
      ),
    );
  }

}
