import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'home_screen.dart';
import 'employees_screen.dart';
import 'vehicles_screen.dart';
import 'customer_list_screen.dart';
import 'trip_creation_screen.dart';

import 'companies_screen.dart';
import '../services/auth_service.dart';

class AdminLayout extends StatefulWidget {
  const AdminLayout({super.key});

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    // const AnalyticsScreen(), // Dashboard REMOVED as per request
    const TripCreationScreen(),
    const EmployeesScreen(),
    const VehiclesScreen(),
    const CompaniesScreen(),
    const CustomerListScreen(),
    const HomeScreen(), // Invoices (Previously key features)
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: NavigationRail(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: (int index) {
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
                      labelType: NavigationRailLabelType.all,
                      leading: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.h),
                        child: Image.asset(
                          'assets/logo/logo.png',
                          height: 40.h,
                          errorBuilder: (c, o, s) =>
                              Icon(Icons.circle, size: 40.sp),
                        ),
                      ),
                      destinations: <NavigationRailDestination>[
                        // Dashboard hidden
                        NavigationRailDestination(
                          icon: Icon(
                            Icons.add_location_alt_outlined,
                            size: 24.sp,
                          ),
                          selectedIcon: Icon(
                            Icons.add_location_alt,
                            size: 24.sp,
                          ),
                          label: Text(
                            'New Trip',
                            style: TextStyle(fontSize: 12.sp),
                          ),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.badge_outlined, size: 24.sp),
                          selectedIcon: Icon(Icons.badge, size: 24.sp),
                          label: Text(
                            'Employees',
                            style: TextStyle(fontSize: 12.sp),
                          ),
                        ),
                        NavigationRailDestination(
                          icon: Icon(
                            Icons.directions_bus_outlined,
                            size: 24.sp,
                          ),
                          selectedIcon: Icon(Icons.directions_bus, size: 24.sp),
                          label: Text(
                            'Vehicles',
                            style: TextStyle(fontSize: 12.sp),
                          ),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.business_outlined, size: 24.sp),
                          selectedIcon: Icon(Icons.business, size: 24.sp),
                          label: Text(
                            'Companies',
                            style: TextStyle(fontSize: 12.sp),
                          ),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.people_outline, size: 24.sp),
                          selectedIcon: Icon(Icons.people, size: 24.sp),
                          label: Text(
                            'Customers',
                            style: TextStyle(fontSize: 12.sp),
                          ),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.receipt_long_outlined, size: 24.sp),
                          selectedIcon: Icon(Icons.receipt_long, size: 24.sp),
                          label: Text(
                            'Invoices',
                            style: TextStyle(fontSize: 12.sp),
                          ),
                        ),
                      ],
                      trailing: Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 24.h),
                            child: IconButton(
                              onPressed: () async {
                                await AuthService.instance.signOut();
                              },
                              icon: Icon(Icons.logout, size: 24.sp),
                              tooltip: 'Sign Out',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          VerticalDivider(thickness: 1, width: 1.w),
          Expanded(child: _screens[_selectedIndex]),
        ],
      ),
    );
  }
}
