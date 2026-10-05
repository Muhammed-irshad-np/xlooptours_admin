import 'package:flutter/material.dart';
import 'package:xloop_invoice/core/utils/app_snack_bar.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/employee/domain/entities/employee_entity.dart';
import '../features/employee/presentation/providers/employee_provider.dart';
import '../features/vehicle/domain/entities/vehicle_entity.dart';
import '../features/vehicle/presentation/providers/vehicle_provider.dart';

import '../widgets/employee_table.dart';
import '../widgets/responsive_layout.dart';
import 'employee_details_screen.dart';
import 'employee_form_screen.dart';
import 'employee_master_screen.dart';
import 'employee_expiry_tracker_screen.dart';
import '../core/widgets/modern_app_bar.dart';
import '../core/widgets/modern_tab_bar.dart';
import '../core/utils/activity_logger.dart';

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
  bool _isAdmin = false;
  bool _isSuperAdmin = false;

  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(true);
  // 'Active', 'Inactive' or 'All'
  final ValueNotifier<String> _statusFilter = ValueNotifier<String>('Active');
  final ValueNotifier<List<EmployeeEntity>> _filteredEmployees =
      ValueNotifier<List<EmployeeEntity>>([]);

  final List<String> _tabs = [];

  @override
  void initState() {
    super.initState();
    _isAdmin = context.read<AuthProvider>().user?.isAdmin ?? false;
    _isSuperAdmin = context.read<AuthProvider>().user?.isSuperAdmin ?? false;
    _tabs.addAll([
      'All',
      'Management',
      'Office',
      'Drivers',
      'External',
    ]);
    if (_isAdmin) {
      _tabs.add('Master');
    }
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      _filterEmployees();
      if (mounted) setState(() {});
    });
    _loadEmployees();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _isLoading.dispose();
    _statusFilter.dispose();
    _filteredEmployees.dispose();

    super.dispose();
  }

  Future<void> _loadEmployees() async {
    _isLoading.value = true;
    try {
      if (mounted) {
        await context.read<EmployeeProvider>().fetchAllEmployees();
      }
      _allEmployees = context.read<EmployeeProvider>().employees;
      _isLoading.value = false;

      _filterEmployees();
    } catch (e) {
      if (mounted) {
        _isLoading.value = false;
        AppSnackBar.showError(context, 'Error loading employees: $e');
      }
    }
  }

  void _filterEmployees() {
    List<EmployeeEntity> temp = _allEmployees;

    // 1. Filter by Active/Inactive
    if (_statusFilter.value == 'Active') {
      temp = temp.where((e) => e.isActive).toList();
    } else if (_statusFilter.value == 'Inactive') {
      temp = temp.where((e) => !e.isActive).toList();
    }

    // 2. Filter by Search
    if (_searchQuery.isNotEmpty) {
      temp = temp
          .where(
            (e) =>
                e.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                e.position.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                e.phoneNumber.contains(_searchQuery) ||
                (e.externalVehicle?.plateNumber ?? '')
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()),
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
        temp = temp.where((e) => e.isDriver).toList();
      } else if (selectedTab == 'External') {
        temp = temp.where((e) => e.isExternal).toList();
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
    if (!_isSuperAdmin) {
      AppSnackBar.showWarning(context, 'Only Super Admins can delete employees.');
      return;
    }
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
      if (mounted) {
        await ActivityLogger.log(
          context,
          title: 'Employee Deleted',
          message: 'Employee ${employee.fullName} has been deleted.',
          relatedId: employee.id,
        );
      }
      _loadEmployees();
    }
  }

  Future<void> _toggleStatus(EmployeeEntity employee, bool isActive) async {
    final updatedEmployee = employee.copyWith(isActive: isActive);
    if (mounted) {
      await context.read<EmployeeProvider>().updateEmployee(updatedEmployee);
      if (mounted) {
        await ActivityLogger.log(
          context,
          title: 'Employee Status Updated',
          message: 'Employee ${employee.fullName} is now ${isActive ? 'ACTIVE' : 'INACTIVE'}.',
          relatedId: employee.id,
        );
      }
      _loadEmployees();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: 'Employees',
        actions: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EmployeeExpiryTrackerScreen(),
                  ),
                );
              },
              icon: Icon(Icons.filter_list_alt, size: 16.sp, color: Colors.blue[700]),
              label: Text(
                'Expiry Filter',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700],
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.blue.withOpacity(0.08),
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
            onPressed: () => _navigateToForm(null),
            tooltip: 'Add Employee',
          ),
        ],
        bottom: ModernTabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: (_isAdmin && _tabs[_tabController.index] == 'Master')
          ? const EmployeeMasterScreen()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
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
                      SizedBox(width: 12.w),
                      _buildStatusFilter(),
                      if (!ResponsiveLayout.isMobile(context)) ...[
                        SizedBox(width: 16.w),
                        ValueListenableBuilder<List<EmployeeEntity>>(
                          valueListenable: _filteredEmployees,
                          builder: (context, filteredEmployees, _) => Text(
                            '${filteredEmployees.length} employees',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ],
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

                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: EmployeeTable(
                              employees: filteredEmployees,
                              filterKey:
                                  '$_searchQuery|${_tabController.index}|${_statusFilter.value}',
                              canDelete: _isSuperAdmin,
                              onOpen: _showDetails,
                              onEdit: _navigateToForm,
                              onDelete: _deleteEmployee,
                              onToggleStatus: _toggleStatus,
                            ),
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

  Widget _buildStatusFilter() {
    return ValueListenableBuilder<String>(
      valueListenable: _statusFilter,
      builder: (context, status, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: status,
              borderRadius: BorderRadius.circular(12),
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
              selectedItemBuilder: (context) => ['Active', 'Inactive', 'All']
                  .map(
                    (s) => Center(child: Text('Status: $s')),
                  )
                  .toList(),
              items: ['Active', 'Inactive', 'All']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (val) {
                if (val == null) return;
                _statusFilter.value = val;
                _filterEmployees();
              },
            ),
          ),
        );
      },
    );
  }

  void _showDetails(EmployeeEntity employee) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmployeeDetailsScreen(
          employee: employee,
        ),
      ),
    );
  }
}
