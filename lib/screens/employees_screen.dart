import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../features/employee/domain/entities/employee_entity.dart';
import '../features/employee/presentation/providers/employee_provider.dart';
import '../features/vehicle/domain/entities/vehicle_entity.dart';
import '../features/vehicle/presentation/providers/vehicle_provider.dart';

import '../widgets/responsive_layout.dart';
import 'employee_details_screen.dart';
import 'employee_form_screen.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen>
    with SingleTickerProviderStateMixin {
  List<EmployeeEntity> _allEmployees = [];
  String _searchQuery = '';
  late TabController _tabController;

  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _showInactive = ValueNotifier<bool>(false);
  final ValueNotifier<List<EmployeeEntity>> _filteredEmployees =
      ValueNotifier<List<EmployeeEntity>>([]);
  final ValueNotifier<Map<String, VehicleEntity>> _assignedVehicles =
      ValueNotifier<Map<String, VehicleEntity>>({});

  final List<String> _tabs = ['All', 'Management', 'Office', 'Drivers'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_filterEmployees);
    _loadEmployees();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _isLoading.dispose();
    _showInactive.dispose();
    _filteredEmployees.dispose();
    _assignedVehicles.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    _isLoading.value = true;
    try {
      if (mounted) {
        await context.read<EmployeeProvider>().fetchAllEmployees();
        if (!mounted) return;
        await context.read<VehicleProvider>().fetchAllVehicles();
      }
      if (!mounted) return;
      final vehicles = context.read<VehicleProvider>().vehicles;

      // Map vehicles by driver ID for quick lookup
      final vehicleMap = <String, VehicleEntity>{};
      for (var v in vehicles) {
        if (v.assignedDriverId != null) {
          vehicleMap[v.assignedDriverId!] = v;
        }
      }

      _allEmployees = context.read<EmployeeProvider>().employees;
      _assignedVehicles.value = vehicleMap;
      _isLoading.value = false;

      _filterEmployees();
    } catch (e) {
      if (mounted) {
        _isLoading.value = false;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading employees: $e')));
      }
    }
  }

  void _filterEmployees() {
    List<EmployeeEntity> temp = _allEmployees;

    // 1. Filter by Active/Inactive
    if (!_showInactive.value) {
      temp = temp.where((e) => e.isActive).toList();
    }

    // 2. Filter by Search
    if (_searchQuery.isNotEmpty) {
      temp = temp
          .where(
            (e) =>
                e.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                e.position.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                e.phoneNumber.contains(_searchQuery),
          )
          .toList();
    }

    // 3. Filter by Tab (Role)
    if (_tabController.index != 0) {
      // 0 is All
      String selectedTab = _tabs[_tabController.index];
      if (selectedTab == 'Management') {
        temp = temp
            .where(
              (e) => ['CEO', 'COO', 'CFO'].contains(e.position),
            ) // Simplified logic
            .toList();
      } else if (selectedTab == 'Office') {
        temp = temp
            .where(
              (e) => [
                'Administrative Officer',
                'Senior Software Developer',
              ].contains(e.position),
            )
            .toList();
      } else if (selectedTab == 'Drivers') {
        temp = temp.where((e) => e.position == 'Driver').toList();
      }
    }

    _filteredEmployees.value = List.from(temp);
  }

  Future<void> _navigateToForm(EmployeeEntity? employee) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmployeeFormScreen(employee: employee),
      ),
    );

    if (result == true) {
      _loadEmployees();
    }
  }

  Future<void> _deleteEmployee(EmployeeEntity employee) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Employee'),
        content: Text('Are you sure you want to delete ${employee.fullName}?'),
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
      await context.read<EmployeeProvider>().deleteEmployee(employee.id);
      _loadEmployees();
    }
  }

  Future<void> _toggleStatus(EmployeeEntity employee, bool isActive) async {
    final updatedEmployee = employee.copyWith(isActive: isActive);
    if (mounted) {
      await context.read<EmployeeProvider>().updateEmployee(updatedEmployee);
      _loadEmployees();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employees'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
        actions: [
          // Filter Toggle
          Row(
            children: [
              Text(
                'Show Inactive',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: _showInactive,
                builder: (context, showInactive, _) {
                  return Switch(
                    value: showInactive,
                    onChanged: (val) {
                      _showInactive.value = val;
                      _filterEmployees();
                    },
                  );
                },
              ),
            ],
          ),
          SizedBox(width: 16.w),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToForm(null),
            tooltip: 'Add Employee',
          ),
          SizedBox(width: 16.w),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search employees...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (val) {
                _searchQuery = val;
                _filterEmployees();
              },
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: _isLoading,
              builder: (context, isLoading, _) {
                if (isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ValueListenableBuilder<List<EmployeeEntity>>(
                  valueListenable: _filteredEmployees,
                  builder: (context, filteredEmployees, _) {
                    if (filteredEmployees.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_off_outlined,
                              size: 64.sp,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              'No employees found',
                              style: TextStyle(
                                fontSize: 18.sp,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ValueListenableBuilder<Map<String, VehicleEntity>>(
                      valueListenable: _assignedVehicles,
                      builder: (context, assignedVehicles, _) {
                        return ResponsiveLayout(
                          mobile: ListView.builder(
                            itemCount: filteredEmployees.length,
                            padding: const EdgeInsets.all(8),
                            itemBuilder: (context, index) => _buildEmployeeCard(
                              filteredEmployees[index],
                              assignedVehicles,
                            ),
                          ),
                          desktop: GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 430.w,
                                  childAspectRatio: 1.5,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                            itemCount: filteredEmployees.length,
                            itemBuilder: (context, index) => _buildEmployeeCard(
                              filteredEmployees[index],
                              assignedVehicles,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToForm(null),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmployeeCard(
    EmployeeEntity employee,
    Map<String, VehicleEntity> assignedVehicles,
  ) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: (employee.imageUrl != null && employee.imageUrl!.isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: employee.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.red, size: 20),
                          )
                        : Center(
                            child: Text(
                              employee.fullName.isNotEmpty
                                  ? employee.fullName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.fullName,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment
                            .start, // Changed from center to start
                        children: [
                          Text(
                            employee.position,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                            // textAlign: TextAlign.center, // Removed as it's in a Row with start alignment
                          ),
                          if (employee.position == 'Driver' &&
                              employee.driverType != null) ...[
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: employee.driverType == 'Internal'
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4.r),
                                border: Border.all(
                                  color: employee.driverType == 'Internal'
                                      ? Colors.green
                                      : Colors.orange,
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                employee.driverType!,
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: employee.driverType == 'Internal'
                                      ? Colors.green
                                      : Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.remove_red_eye,
                        color: Colors.blue,
                      ),
                      tooltip: 'View Details',
                      onPressed: () => _showDetails(employee),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _navigateToForm(employee);
                        } else if (value == 'delete') {
                          _deleteEmployee(employee);
                        }
                      },
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
                              Icon(Icons.delete, size: 20, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Icon(Icons.phone, size: 14.sp, color: Colors.grey),
                SizedBox(width: 8.w),
                Text(
                  employee.phoneNumber,
                  style: TextStyle(fontSize: 13.sp, color: Colors.grey[800]),
                ),
              ],
            ),
            if (employee.email.isNotEmpty) ...[
              SizedBox(height: 4.h),
              Row(
                children: [
                  Icon(Icons.email, size: 14.sp, color: Colors.grey),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      employee.email,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey[800],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            // Show Assigned Vehicle for Drivers
            if (assignedVehicles.isNotEmpty &&
                assignedVehicles[employee.id] != null) ...[
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.directions_car,
                      size: 16.sp,
                      color: Colors.blue[700],
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        '${assignedVehicles[employee.id]?.make ?? ''} ${assignedVehicles[employee.id]?.model ?? ''} (${assignedVehicles[employee.id]?.plateNumber ?? ''})',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Colors.blue[900],
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: 16.h),
            Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  employee.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    color: employee.isActive ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.sp,
                  ),
                ),
                Switch(
                  value: employee.isActive,
                  onChanged: (val) => _toggleStatus(employee, val),
                  activeThumbColor: Colors.white,
                  activeTrackColor: Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(EmployeeEntity employee) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmployeeDetailsScreen(
          employee: employee,
          assignedVehicle: _assignedVehicles.value[employee.id],
        ),
      ),
    );
  }
}
