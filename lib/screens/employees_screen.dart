import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/employee/domain/entities/employee_entity.dart';
import '../features/employee/presentation/providers/employee_provider.dart';
import '../features/vehicle/domain/entities/vehicle_entity.dart';
import '../features/vehicle/presentation/providers/vehicle_provider.dart';

import '../widgets/responsive_layout.dart';
import 'employee_details_screen.dart';
import 'employee_form_screen.dart';
import 'employee_master_screen.dart';
import '../core/widgets/modern_app_bar.dart';
import '../core/widgets/modern_tab_bar.dart';
import '../features/notifications/presentation/providers/notification_provider.dart';
import '../core/widgets/action_items_dialog.dart';
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

  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _showInactive = ValueNotifier<bool>(false);
  final ValueNotifier<List<EmployeeEntity>> _filteredEmployees =
      ValueNotifier<List<EmployeeEntity>>([]);

  final List<String> _tabs = [];

  @override
  void initState() {
    super.initState();
    _isAdmin = context.read<AuthProvider>().user?.isAdmin ?? false;
    _tabs.addAll([
      'All',
      'Management',
      'Office',
      'Drivers',
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
    _showInactive.dispose();
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading employees: $e')));
      }
    }
  }

  void _filterEmployees() {
    List<EmployeeEntity> temp = _allEmployees;

    // 1. Filter by Active/Inactive
    if (_showInactive.value) {
      temp = temp.where((e) => !e.isActive).toList();
    } else {
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
          // Filter Toggle
          Row(
            children: [
              Text(
                'Show Inactive',
                style: TextStyle(fontSize: 10.sp, color: Colors.grey[600]),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: _showInactive,
                builder: (context, showInactive, _) {
                  return Transform.scale(
                    scale: 0.7,
                    child: Switch(
                      value: showInactive,
                      onChanged: (val) {
                        _showInactive.value = val;
                        _filterEmployees();
                      },
                    ),
                  );
                },
              ),
            ],
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

                          return ResponsiveLayout(
                            mobile: ListView.builder(
                              itemCount: filteredEmployees.length,
                              padding: const EdgeInsets.all(8),
                              itemBuilder: (context, index) =>
                                  _buildEmployeeCard(
                                    filteredEmployees[index],
                                  ),
                            ),
                            desktop: GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate:
                                  SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 430.w,
                                    childAspectRatio: 1.4,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                  ),
                              itemCount: filteredEmployees.length,
                              itemBuilder: (context, index) =>
                                  _buildEmployeeCard(
                                    filteredEmployees[index],
                                  ),
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

  Widget _buildEmployeeCard(EmployeeEntity employee) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
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
                  width: 56, // Increased from 40
                  height: 56, // Increased from 40
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child:
                        (employee.imageUrl != null &&
                            employee.imageUrl!.isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: employee.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: SizedBox(
                                width: 24, // Increased slightly
                                height: 24, // Increased slightly
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => const Icon(
                              Icons.broken_image,
                              color: Colors.red,
                              size: 28,
                            ), // Increased slightly
                          )
                        : Center(
                            child: Text(
                              employee.fullName.isNotEmpty
                                  ? employee.fullName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 20, // Added larger font size
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
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            employee.position,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
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
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : Colors.orange.withValues(alpha: 0.1),
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
                    Consumer<NotificationProvider>(
                      builder: (context, provider, _) {
                        final alerts = provider.getNotificationsByRelatedId(
                          employee.id,
                        );
                        if (alerts.isEmpty) return const SizedBox.shrink();

                        return IconButton(
                          onPressed:
                              () => ActionItemsDialog.show(
                                context,
                                employee.fullName,
                                employee.id,
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
        ),
      ),
    );
  }
}
