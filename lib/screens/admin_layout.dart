import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';
import 'employees_screen.dart';
import 'vehicles_screen.dart';
import 'customer_list_screen.dart';
import 'trip_creation_screen.dart';
import 'notifications_screen.dart';
import 'dashboard_screen.dart';
import 'feedback_history_screen.dart';
import '../features/driver_evaluation/presentation/pages/pending_evaluations_screen.dart';
import 'employee_form_screen.dart';
import 'employee_expiry_tracker_screen.dart';
import 'employee_expiry_alert_settings_screen.dart';
import 'vehicle_form_screen.dart';
import 'vehicle_expiry_tracker_screen.dart';
import 'vehicle_expiry_alert_settings_screen.dart';
import 'vehicle_makes_screen.dart';
import 'maintenance_type_master_screen.dart';
import 'company_form_screen.dart';
import 'customer_form_screen.dart';
import 'invoice_form_screen.dart';
import 'invoice_list_screen.dart';
import 'expiries_list_screen.dart';
import '../core/utils/share_dialog.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:provider/provider.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/notifications/presentation/providers/notification_provider.dart';
import '../features/xloop_vault/presentation/pages/vault_screen.dart';
import '../features/xloop_vault/presentation/providers/vault_provider.dart';
import 'companies_screen.dart';
import '../features/finance/presentation/pages/finance_dashboard_page.dart';

/// The main admin scaffold with a professional, dark-themed sidebar.
class AdminLayout extends StatefulWidget {
  const AdminLayout({super.key});

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  final ValueNotifier<int> _selectedIndex = ValueNotifier<int>(0);

  final List<Widget> _screens = [
    const DashboardScreen(),
    const TripCreationScreen(),
    const NotificationsScreen(),
    const EmployeesScreen(),
    const VehiclesScreen(),
    const CompaniesScreen(),
    const CustomerListScreen(),
    const HomeScreen(), // Invoices
    const FeedbackHistoryScreen(), // Feedback
    const PendingEvaluationsScreen(), // Evaluations
    const FinanceDashboardPage(),
  ];

  static const Color _sidebarBg = Color(0xFF0B0F1A);
  static const Color _brandBlue = Color(0xFF13B1F2);
  static const Color _activeBg = Color(0xFF1A2235);
  static const Color _inactiveText = Color(0xFF7A8BA0);
  static const Color _dividerColor = Color(0xFF1E2A3A);

  static final List<_NavItem> _navItems = [
    // ── Dashboard ──────────────────────────────────────────────
    _NavItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      subItems: [
        _SubNavItem(
          label: 'All Expiries',
          icon: Icons.warning_amber_outlined,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExpiriesListScreen()),
            );
          },
        ),
        _SubNavItem(
          label: 'Vehicle Expiries',
          icon: Icons.car_crash_outlined,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const VehicleExpiryTrackerScreen(),
              ),
            );
          },
        ),
        _SubNavItem(
          label: 'Employee Expiries',
          icon: Icons.person_off_outlined,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const EmployeeExpiryTrackerScreen(),
              ),
            );
          },
        ),
        _SubNavItem(
          label: 'Analytics',
          icon: Icons.analytics_outlined,
          adminOnly: true,
          onAction: (context) {
            context.push('/analytics');
          },
        ),
        _SubNavItem(
          label: 'Activity Logs',
          icon: Icons.history_outlined,
          adminOnly: true,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
          },
        ),
      ],
    ),
    // ── New Trip ───────────────────────────────────────────────
    _NavItem(
      label: 'New Trip',
      icon: Icons.add_location_alt_outlined,
      activeIcon: Icons.add_location_alt_rounded,
      subItems: [
        _SubNavItem(
          label: 'Start Booking',
          icon: Icons.play_circle_outline,
          onAction: (context) {
            // Already on TripCreationScreen — no additional action needed
          },
        ),
        _SubNavItem(
          label: 'Select Customer',
          icon: Icons.person_search_outlined,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CustomerListScreen(
                  isSelectionMode: true,
                  onCustomerSelected: (_) => Navigator.pop(context),
                ),
              ),
            );
          },
        ),
        _SubNavItem(
          label: 'Select Company',
          icon: Icons.business_center_outlined,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CompaniesScreen(
                  isSelectionMode: true,
                  onCompanySelected: (_) => Navigator.pop(context),
                ),
              ),
            );
          },
        ),
        _SubNavItem(
          label: 'New Customer',
          icon: Icons.person_add_alt_1_outlined,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomerFormScreen()),
            );
          },
        ),
        _SubNavItem(
          label: 'Create Invoice',
          icon: Icons.receipt_outlined,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InvoiceFormScreen()),
            );
          },
        ),
      ],
    ),
    // ── Activity Logs ─────────────────────────────────────────
    _NavItem(
      label: 'Activity Logs',
      icon: Icons.history_outlined,
      activeIcon: Icons.history_rounded,
      hasBadge: true,
      subItems: [
        _SubNavItem(
          label: 'All Expiries',
          icon: Icons.warning_amber_outlined,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExpiriesListScreen()),
            );
          },
        ),
        _SubNavItem(
          label: 'Vehicle Expiries',
          icon: Icons.car_crash_outlined,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const VehicleExpiryTrackerScreen(),
              ),
            );
          },
        ),
        _SubNavItem(
          label: 'Employee Expiries',
          icon: Icons.person_off_outlined,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const EmployeeExpiryTrackerScreen(),
              ),
            );
          },
        ),
        _SubNavItem(
          label: 'Feedback Log',
          icon: Icons.rate_review_outlined,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FeedbackHistoryScreen()),
            );
          },
        ),
        _SubNavItem(
          label: 'Evaluations',
          icon: Icons.assignment_outlined,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PendingEvaluationsScreen(),
              ),
            );
          },
        ),
      ],
    ),
    // ── Employees ─────────────────────────────────────────────
    _NavItem(
      label: 'Employees',
      icon: Icons.badge_outlined,
      activeIcon: Icons.badge_rounded,
      subItems: [
        _SubNavItem(
          label: 'Add Employee',
          icon: Icons.person_add_outlined,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EmployeeFormScreen()),
            );
          },
        ),
        _SubNavItem(
          label: 'Expiry Tracker',
          icon: Icons.av_timer_outlined,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const EmployeeExpiryTrackerScreen(),
              ),
            );
          },
        ),
        _SubNavItem(
          label: 'Alert Settings',
          icon: Icons.notifications_active_outlined,
          adminOnly: true,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const EmployeeExpiryAlertSettingsScreen(),
              ),
            );
          },
        ),
        _SubNavItem(
          label: 'Evaluate Driver',
          icon: Icons.star_outline_outlined,
          adminOnly: true,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PendingEvaluationsScreen(),
              ),
            );
          },
        ),
        _SubNavItem(
          label: 'Feedback History',
          icon: Icons.rate_review_outlined,
          adminOnly: true,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FeedbackHistoryScreen()),
            );
          },
        ),
      ],
    ),
    // ── Vehicles ──────────────────────────────────────────────
    _NavItem(
      label: 'Vehicles',
      icon: Icons.directions_car_outlined,
      activeIcon: Icons.directions_car_rounded,
      subItems: [
        _SubNavItem(
          label: 'Add Vehicle',
          icon: Icons.add_circle_outline,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VehicleFormScreen()),
            );
          },
        ),
        _SubNavItem(
          label: 'Expiry Tracker',
          icon: Icons.av_timer_outlined,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const VehicleExpiryTrackerScreen(),
              ),
            );
          },
        ),
        _SubNavItem(
          label: 'Alert Settings',
          icon: Icons.notifications_active_outlined,
          adminOnly: true,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const VehicleExpiryAlertSettingsScreen(),
              ),
            );
          },
        ),
        _SubNavItem(
          label: 'Vehicle Makes',
          icon: Icons.directions_car_filled_outlined,
          adminOnly: true,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VehicleMakesScreen()),
            );
          },
        ),
        _SubNavItem(
          label: 'Maintenance Types',
          icon: Icons.build_outlined,
          adminOnly: true,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MaintenanceTypeMasterScreen(),
              ),
            );
          },
        ),
      ],
    ),
    // ── Companies ─────────────────────────────────────────────
    _NavItem(
      label: 'Companies',
      icon: Icons.business_outlined,
      activeIcon: Icons.business_rounded,
      subItems: [
        _SubNavItem(
          label: 'Add Company',
          icon: Icons.domain_add_outlined,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CompanyFormScreen()),
            );
          },
        ),
        _SubNavItem(
          label: 'Select Company',
          icon: Icons.search_outlined,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CompaniesScreen(
                  isSelectionMode: true,
                  onCompanySelected: (_) => Navigator.pop(context),
                ),
              ),
            );
          },
        ),
        _SubNavItem(
          label: 'Create Invoice',
          icon: Icons.receipt_outlined,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InvoiceFormScreen()),
            );
          },
        ),
        _SubNavItem(
          label: 'Add Customer',
          icon: Icons.person_add_alt_1_outlined,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomerFormScreen()),
            );
          },
        ),
        _SubNavItem(
          label: 'Analytics',
          icon: Icons.analytics_outlined,
          onAction: (context) {
            context.push('/analytics');
          },
        ),
      ],
    ),
    // ── Customers ─────────────────────────────────────────────
    _NavItem(
      label: 'Customers',
      icon: Icons.people_outline_rounded,
      activeIcon: Icons.people_rounded,
      subItems: [
        _SubNavItem(
          label: 'Add Customer',
          icon: Icons.person_add_alt_1_outlined,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomerFormScreen()),
            );
          },
        ),
        _SubNavItem(
          label: 'Create Invoice',
          icon: Icons.receipt_outlined,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InvoiceFormScreen()),
            );
          },
        ),
        _SubNavItem(
          label: 'Feedback History',
          icon: Icons.rate_review_outlined,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FeedbackHistoryScreen()),
            );
          },
        ),
        _SubNavItem(
          label: 'New Trip',
          icon: Icons.add_location_alt_outlined,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TripCreationScreen()),
            );
          },
        ),
        _SubNavItem(
          label: 'Analytics',
          icon: Icons.analytics_outlined,
          onAction: (context) {
            context.push('/analytics');
          },
        ),
      ],
    ),
    // ── Invoices ──────────────────────────────────────────────
    _NavItem(
      label: 'Invoices',
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
      subItems: [
        _SubNavItem(
          label: 'Create Invoice',
          icon: Icons.post_add_outlined,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InvoiceFormScreen()),
            );
          },
        ),
        _SubNavItem(
          label: 'Saved Invoices',
          icon: Icons.folder_open_outlined,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InvoiceListScreen()),
            );
          },
        ),
        _SubNavItem(
          label: 'Analytics',
          icon: Icons.analytics_outlined,
          onAction: (context) {
            context.push('/analytics');
          },
        ),
        _SubNavItem(
          label: 'Add Customer',
          icon: Icons.person_add_alt_1_outlined,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomerFormScreen()),
            );
          },
        ),
        _SubNavItem(
          label: 'Add Company',
          icon: Icons.domain_add_outlined,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CompanyFormScreen()),
            );
          },
        ),
      ],
    ),
    // ── Feedback ──────────────────────────────────────────────
    _NavItem(
      label: 'Feedback',
      icon: Icons.rate_review_outlined,
      activeIcon: Icons.rate_review_rounded,
      subItems: [
        _SubNavItem(
          label: 'Share Feedback Link',
          icon: Icons.share_outlined,
          onAction: (context) {
            showDialog(
              context: context,
              builder: (_) => const ShareDialog(
                title: 'Share Feedback Form',
                url: '/feedback',
              ),
            );
          },
        ),
        _SubNavItem(
          label: 'View All Feedback',
          icon: Icons.list_alt_outlined,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FeedbackHistoryScreen()),
            );
          },
        ),
        _SubNavItem(
          label: 'Driver Evaluations',
          icon: Icons.star_outline_outlined,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PendingEvaluationsScreen(),
              ),
            );
          },
        ),
        _SubNavItem(
          label: 'Add Customer',
          icon: Icons.person_add_alt_1_outlined,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomerFormScreen()),
            );
          },
        ),
        _SubNavItem(
          label: 'Add Employee',
          icon: Icons.person_add_outlined,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EmployeeFormScreen()),
            );
          },
        ),
      ],
    ),
    // ── Evaluations ───────────────────────────────────────────
    _NavItem(
      label: 'Evaluations',
      icon: Icons.assignment_outlined,
      activeIcon: Icons.assignment_rounded,
      subItems: [
        _SubNavItem(
          label: 'Share Eval Link',
          icon: Icons.share_outlined,
          onAction: (context) {
            showDialog(
              context: context,
              builder: (_) => const ShareDialog(
                title: 'Share Evaluation Form',
                url: '/evaluate',
              ),
            );
          },
        ),
        _SubNavItem(
          label: 'View All Evaluations',
          icon: Icons.list_alt_outlined,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PendingEvaluationsScreen(),
              ),
            );
          },
        ),
        _SubNavItem(
          label: 'Feedback History',
          icon: Icons.rate_review_outlined,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FeedbackHistoryScreen()),
            );
          },
        ),
        _SubNavItem(
          label: 'Add Employee',
          icon: Icons.person_add_outlined,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EmployeeFormScreen()),
            );
          },
        ),
        _SubNavItem(
          label: 'Add Vehicle',
          icon: Icons.add_circle_outline,
          onAction: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VehicleFormScreen()),
            );
          },
        ),
      ],
    ),
    // ── Finance ────────────────────────────────────────────────
    _NavItem(
      label: 'Finance',
      icon: Icons.account_balance_outlined,
      activeIcon: Icons.account_balance_rounded,
      subItems: [
        _SubNavItem(
          label: 'Overview',
          icon: Icons.analytics_outlined,
          onAction: (context) {
            // Screen handles overview
          },
        ),
        _SubNavItem(
          label: 'Share Driver Link',
          icon: Icons.share_outlined,
          onAction: (context) {
            showDialog(
              context: context,
              builder: (_) => const ShareDialog(
                title: 'Share Driver Expense Form',
                url: '/driver-expense',
              ),
            );
          },
        ),
        _SubNavItem(
          label: 'Share Closing Link',
          icon: Icons.share_outlined,
          onAction: (context) {
            showDialog(
              context: context,
              builder: (_) => const ShareDialog(
                title: 'Share Daily Closing Form',
                url: '/coordinator-closing',
              ),
            );
          },
        ),
      ],
    ),
  ];

  bool _isAdmin(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return user?.isAdmin ?? false;
  }

  @override
  void dispose() {
    _selectedIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _isAdmin(context);

    final List<Widget> allowedScreens = [];
    final List<_NavItem> allowedNavItems = [];

    for (int i = 0; i < _navItems.length; i++) {
      // 0: Dashboard, 3: Employees, 4: Vehicles
      if (isAdmin || [0, 3, 4].contains(i)) {
        allowedScreens.add(_screens[i]);
        allowedNavItems.add(_navItems[i]);
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // Sidebar
          ValueListenableBuilder<int>(
            valueListenable: _selectedIndex,
            builder: (context, selectedIndex, _) {
              return _Sidebar(
                selectedIndex: selectedIndex,
                items: allowedNavItems,
                sidebarBg: _sidebarBg,
                brandBlue: _brandBlue,
                activeBg: _activeBg,
                inactiveText: _inactiveText,
                dividerColor: _dividerColor,
                isAdmin: isAdmin,
                onItemSelected: (index) {
                  _selectedIndex.value = index;
                },
                onLogout: () async {
                  await context.read<AuthProvider>().logout();
                },
              );
            },
          ),
          // Main content
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: _selectedIndex,
              builder: (context, selectedIndex, _) {
                // Failsafe in case index is out of bounds due to role changes
                final index = selectedIndex < allowedScreens.length
                    ? selectedIndex
                    : 0;
                return allowedScreens[index];
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SubNavItem {
  final String label;
  final IconData icon;
  final void Function(BuildContext) onAction;
  final bool adminOnly;

  const _SubNavItem({
    required this.label,
    required this.icon,
    required this.onAction,
    this.adminOnly = false,
  });
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool hasBadge;
  final List<_SubNavItem>? subItems;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.hasBadge = false,
    this.subItems,
  });
}

class _Sidebar extends StatelessWidget {
  final int selectedIndex;
  final List<_NavItem> items;
  final Color sidebarBg;
  final Color brandBlue;
  final Color activeBg;
  final Color inactiveText;
  final Color dividerColor;
  final bool isAdmin;
  final ValueChanged<int> onItemSelected;
  final VoidCallback onLogout;

  const _Sidebar({
    required this.selectedIndex,
    required this.items,
    required this.sidebarBg,
    required this.brandBlue,
    required this.activeBg,
    required this.inactiveText,
    required this.dividerColor,
    required this.isAdmin,
    required this.onItemSelected,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220.w,
      color: sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo Header
          _buildLogoSection(context),
          // Divider
          Container(
            height: 1,
            color: dividerColor,
            margin: EdgeInsets.symmetric(horizontal: 16.w),
          ),
          SizedBox(height: 12.h),
          // Nav label
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 4.h),
            child: Text(
              'MAIN MENU',
              style: GoogleFonts.notoSans(
                fontSize: 9.sp,
                color: inactiveText.withOpacity(0.6),
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
              ),
            ),
          ),
          SizedBox(height: 4.h),
          // Nav items
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = selectedIndex == index;

                // Special badge handling for notifications
                if (item.hasBadge) {
                  return Consumer<NotificationProvider>(
                    builder: (context, provider, _) {
                      return _NavTile(
                        item: item,
                        isSelected: isSelected,
                        brandBlue: brandBlue,
                        activeBg: activeBg,
                        inactiveText: inactiveText,
                        badgeCount: provider.unreadCount,
                        isAdmin: isAdmin,
                        onTap: () => onItemSelected(index),
                      );
                    },
                  );
                }

                return _NavTile(
                  item: item,
                  isSelected: isSelected,
                  brandBlue: brandBlue,
                  activeBg: activeBg,
                  inactiveText: inactiveText,
                  isAdmin: isAdmin,
                  onTap: () => onItemSelected(index),
                );
              },
            ),
          ),
          // Bottom divider
          Container(
            height: 1,
            color: dividerColor,
            margin: EdgeInsets.symmetric(horizontal: 16.w),
          ),
          // Logout
          _buildLogoutButton(),
        ],
      ),
    );
  }

  void _handleLogoClick(BuildContext context) {
    if (isAdmin && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const VaultScreen()),
      );
    }
  }

  Widget _buildLogoSection(BuildContext context) {
    return InkWell(
      onTap: () => _handleLogoClick(context),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 22.h),
        child: Row(
          children: [
            // Logo inside a rounded container
            Container(
              width: 36.w,
              height: 36.h,
              decoration: BoxDecoration(
                color: brandBlue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10.r),
                child: Image.asset(
                  'assets/logo/logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (c, o, s) => Icon(
                    Icons.directions_car_rounded,
                    color: brandBlue,
                    size: 20.sp,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Xloop Tours',
                    style: GoogleFonts.merriweather(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Admin Panel',
                    style: GoogleFonts.notoSans(
                      fontSize: 9.sp,
                      color: brandBlue,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 16.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onLogout,
          borderRadius: BorderRadius.circular(10.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: dividerColor),
            ),
            child: Row(
              children: [
                Icon(Icons.logout_rounded, color: inactiveText, size: 18.sp),
                SizedBox(width: 12.w),
                Text(
                  'Sign Out',
                  style: GoogleFonts.notoSans(
                    fontSize: 12.sp,
                    color: inactiveText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatefulWidget {
  final _NavItem item;
  final bool isSelected;
  final Color brandBlue;
  final Color activeBg;
  final Color inactiveText;
  final int badgeCount;
  final bool isAdmin;
  final VoidCallback onTap;

  const _NavTile({
    required this.item,
    required this.isSelected,
    required this.brandBlue,
    required this.activeBg,
    required this.inactiveText,
    this.badgeCount = 0,
    this.isAdmin = false,
    required this.onTap,
  });

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    final Color iconColor = isSelected
        ? widget.brandBlue
        : (_hovered ? Colors.white : widget.inactiveText);
    final Color textColor = isSelected
        ? Colors.white
        : (_hovered ? Colors.white : widget.inactiveText);
    final Color bgColor = isSelected
        ? widget.activeBg
        : (_hovered ? widget.activeBg.withOpacity(0.5) : Colors.transparent);

    final filteredSubItems = widget.item.subItems
        ?.where((sub) => widget.isAdmin || !sub.adminOnly)
        .toList();
    final hasSubItems = filteredSubItems != null && filteredSubItems.isNotEmpty;

    return Column(
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeInOut,
              margin: EdgeInsets.only(bottom: 4.h),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10.r),
                // Active left-side indicator
                border: isSelected
                    ? Border(
                        left: BorderSide(color: widget.brandBlue, width: 3),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  // Icon with optional badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        isSelected ? widget.item.activeIcon : widget.item.icon,
                        color: iconColor,
                        size: 20.sp,
                      ),
                      if (widget.badgeCount > 0)
                        Positioned(
                          right: -6,
                          top: -4,
                          child: Container(
                            padding: EdgeInsets.all(3.r),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE53935),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${widget.badgeCount}',
                              style: GoogleFonts.notoSans(
                                fontSize: 7.sp,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      widget.item.label,
                      style: GoogleFonts.notoSans(
                        fontSize: 13.sp,
                        color: textColor,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Sub-items list
        if (hasSubItems)
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: isSelected
                ? Container(
                    margin: EdgeInsets.only(left: 36.w, bottom: 8.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: filteredSubItems.map((sub) {
                        return _SubNavTile(
                          item: sub,
                          brandBlue: widget.brandBlue,
                          inactiveText: widget.inactiveText,
                        );
                      }).toList(),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
      ],
    );
  }
}

class _SubNavTile extends StatefulWidget {
  final _SubNavItem item;
  final Color brandBlue;
  final Color inactiveText;

  const _SubNavTile({
    required this.item,
    required this.brandBlue,
    required this.inactiveText,
  });

  @override
  State<_SubNavTile> createState() => _SubNavTileState();
}

class _SubNavTileState extends State<_SubNavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => widget.item.onAction(context),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 6.h),
          child: Row(
            children: [
              Icon(
                widget.item.icon,
                color: _hovered
                    ? widget.brandBlue
                    : widget.inactiveText.withOpacity(0.8),
                size: 16.sp,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  widget.item.label,
                  style: GoogleFonts.notoSans(
                    fontSize: 11.sp,
                    color: _hovered
                        ? Colors.white
                        : widget.inactiveText.withOpacity(0.8),
                    fontWeight: _hovered ? FontWeight.w500 : FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
