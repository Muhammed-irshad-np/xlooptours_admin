import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:xloop_invoice/screens/vehicle_master_screen.dart'; // Added
import '../models/vehicle_model.dart';
import '../models/employee_model.dart';
import '../services/database_service.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  List<VehicleModel> _vehicles = [];
  Map<String, EmployeeModel> _driversMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);
      // Load vehicles
      final vehicles = await DatabaseService.instance.getAllVehicles();

      // Load drivers (employees) to resolve names
      final employees = await DatabaseService.instance.getAllEmployees();
      final Map<String, EmployeeModel> driversMap = {
        for (var e in employees) e.id: e,
      };

      if (mounted) {
        setState(() {
          _vehicles = vehicles;
          _driversMap = driversMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading vehicles: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _navigateToAddEdit({VehicleModel? vehicle}) async {
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

    if (confirmed == true) {
      await DatabaseService.instance.deleteVehicle(id);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
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
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _vehicles.isEmpty
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
                : ListView.separated(
                    padding: EdgeInsets.all(16.w),
                    itemCount: _vehicles.length,
                    separatorBuilder: (context, index) =>
                        SizedBox(height: 16.h),
                    itemBuilder: (context, index) {
                      final vehicle = _vehicles[index];
                      final driver = vehicle.assignedDriverId != null
                          ? _driversMap[vehicle.assignedDriverId]
                          : null;

                      return _buildVehicleCard(vehicle, driver);
                    },
                  ),

            // Tab 2: Vehicle Master
            const VehicleMasterScreen(),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleCard(VehicleModel vehicle, EmployeeModel? driver) {
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
          children: [
            SizedBox(height: 4.h),
            Text('Plate: ${vehicle.plateNumber} • ${vehicle.color}'),
            SizedBox(height: 4.h),
            Row(
              children: [
                Icon(Icons.person, size: 14.sp, color: Colors.blueGrey),
                SizedBox(width: 4.w),
                Text(
                  driver != null ? driver.fullName : 'No Driver Assigned',
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

  void _showDetails(VehicleModel vehicle, EmployeeModel? driver) {
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
                        'Assigned Driver',
                        driver != null ? driver.fullName : 'Not Assigned',
                        Icons.person,
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

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Column(
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
        ],
      ),
    );
  }
}
