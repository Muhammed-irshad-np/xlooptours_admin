import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/employee_model.dart';
import '../models/vehicle_model.dart'; // Added
import '../services/database_service.dart';
import '../widgets/responsive_layout.dart';
import 'employee_form_screen.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen>
    with SingleTickerProviderStateMixin {
  final _databaseService = DatabaseService.instance;
  List<EmployeeModel> _allEmployees = [];
  List<EmployeeModel> _filteredEmployees = [];
  Map<String, VehicleModel> _assignedVehicles = {}; // Added
  bool _isLoading = true;
  String _searchQuery = '';
  late TabController _tabController;
  bool _showInactive = false; // Filter state

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
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    try {
      final employees = await _databaseService.getAllEmployees();
      final vehicles = await _databaseService.getAllVehicles(); // Added

      // Map vehicles by driver ID for quick lookup
      final vehicleMap = <String, VehicleModel>{};
      for (var v in vehicles) {
        if (v.assignedDriverId != null) {
          vehicleMap[v.assignedDriverId!] = v;
        }
      }

      if (mounted) {
        setState(() {
          _allEmployees = employees;
          _assignedVehicles = vehicleMap; // Added
          _isLoading = false;
        });
        _filterEmployees();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading employees: $e')));
      }
    }
  }

  void _filterEmployees() {
    List<EmployeeModel> temp = _allEmployees;

    // 1. Filter by Active/Inactive
    if (!_showInactive) {
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

    setState(() {
      _filteredEmployees = temp;
    });
  }

  Future<void> _navigateToForm(EmployeeModel? employee) async {
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

  Future<void> _deleteEmployee(EmployeeModel employee) async {
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

    if (confirmed == true) {
      await _databaseService.deleteEmployee(employee.id);
      _loadEmployees();
    }
  }

  Future<void> _toggleStatus(EmployeeModel employee, bool isActive) async {
    final updatedEmployee = employee.copyWith(isActive: isActive);
    await _databaseService.updateEmployee(updatedEmployee);
    _loadEmployees();
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
              Switch(
                value: _showInactive,
                onChanged: (val) {
                  setState(() {
                    _showInactive = val;
                  });
                  _filterEmployees();
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredEmployees.isEmpty
                ? Center(
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
                          style: TextStyle(fontSize: 18.sp, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ResponsiveLayout(
                    mobile: ListView.builder(
                      itemCount: _filteredEmployees.length,
                      padding: const EdgeInsets.all(8),
                      itemBuilder: (context, index) =>
                          _buildEmployeeCard(_filteredEmployees[index]),
                    ),
                    desktop: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 430.w,
                        childAspectRatio: 1.8,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _filteredEmployees.length,
                      itemBuilder: (context, index) =>
                          _buildEmployeeCard(_filteredEmployees[index]),
                    ),
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

  Widget _buildEmployeeCard(EmployeeModel employee) {
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
                CircleAvatar(
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  child: Text(
                    employee.fullName.isNotEmpty
                        ? employee.fullName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
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
                      Text(
                        employee.position,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Colors.grey[600],
                        ),
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
            if (_assignedVehicles.isNotEmpty &&
                _assignedVehicles[employee.id] != null) ...[
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
                        '${_assignedVehicles[employee.id]?.make ?? ''} ${_assignedVehicles[employee.id]?.model ?? ''} (${_assignedVehicles[employee.id]?.plateNumber ?? ''})',
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
                  activeColor: Colors.white,
                  activeTrackColor: Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(EmployeeModel employee) {
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
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    child: Text(
                      employee.fullName.isNotEmpty
                          ? employee.fullName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employee.fullName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          employee.position,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
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
                      _buildDetailRow('Email', employee.email, Icons.email),
                      _buildDetailRow(
                        'Phone',
                        employee.phoneNumber,
                        Icons.phone,
                      ),
                      _buildDetailRow(
                        'Nationality',
                        employee.nationality,
                        Icons.flag,
                      ),
                      _buildDetailRow('Gender', employee.gender, Icons.person),
                      _buildDetailRow('ID Type', employee.idType, Icons.badge),
                      _buildDetailRow(
                        'ID Number',
                        employee.idNumber,
                        Icons.numbers,
                      ),
                      _buildDetailRow(
                        'Join Date',
                        employee.joinDate?.toString().split(' ')[0] ?? 'N/A',
                        Icons.calendar_today,
                      ),
                      _buildDetailRow(
                        'Birth Date',
                        employee.birthDate?.toString().split(' ')[0] ?? 'N/A',
                        Icons.cake,
                      ),
                      if (employee.driverType != null)
                        _buildDetailRow(
                          'Driver Type',
                          employee.driverType!,
                          Icons.directions_car,
                        ),
                      _buildDetailRow(
                        'Status',
                        employee.isActive ? 'Active' : 'Inactive',
                        Icons.info,
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
    if (value.isEmpty) return const SizedBox.shrink();
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
