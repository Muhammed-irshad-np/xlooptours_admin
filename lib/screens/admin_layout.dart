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

import 'package:provider/provider.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import 'companies_screen.dart';
import '../features/notifications/presentation/providers/notification_provider.dart';

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
  ];

  static const Color _sidebarBg = Color(0xFF0B0F1A);
  static const Color _brandBlue = Color(0xFF13B1F2);
  static const Color _activeBg = Color(0xFF1A2235);
  static const Color _inactiveText = Color(0xFF7A8BA0);
  static const Color _dividerColor = Color(0xFF1E2A3A);

  static const List<_NavItem> _navItems = [
    _NavItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
    ),
    _NavItem(
      label: 'New Trip',
      icon: Icons.add_location_alt_outlined,
      activeIcon: Icons.add_location_alt_rounded,
    ),
    _NavItem(
      label: 'Activity',
      icon: Icons.notifications_outlined,
      activeIcon: Icons.notifications_rounded,
      hasBadge: true,
    ),
    _NavItem(
      label: 'Employees',
      icon: Icons.badge_outlined,
      activeIcon: Icons.badge_rounded,
    ),
    _NavItem(
      label: 'Vehicles',
      icon: Icons.directions_car_outlined,
      activeIcon: Icons.directions_car_rounded,
    ),
    _NavItem(
      label: 'Companies',
      icon: Icons.business_outlined,
      activeIcon: Icons.business_rounded,
    ),
    _NavItem(
      label: 'Customers',
      icon: Icons.people_outline_rounded,
      activeIcon: Icons.people_rounded,
    ),
    _NavItem(
      label: 'Invoices',
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
    ),
  ];

  @override
  void dispose() {
    _selectedIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                items: _navItems,
                sidebarBg: _sidebarBg,
                brandBlue: _brandBlue,
                activeBg: _activeBg,
                inactiveText: _inactiveText,
                dividerColor: _dividerColor,
                onItemSelected: (index) => _selectedIndex.value = index,
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
                return _screens[selectedIndex];
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool hasBadge;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.hasBadge = false,
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
          _buildLogoSection(),
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

  Widget _buildLogoSection() {
    return Padding(
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
                  'XLoop Tours',
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
  final VoidCallback onTap;

  const _NavTile({
    required this.item,
    required this.isSelected,
    required this.brandBlue,
    required this.activeBg,
    required this.inactiveText,
    this.badgeCount = 0,
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

    return MouseRegion(
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
                ? Border(left: BorderSide(color: widget.brandBlue, width: 3))
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
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935),
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
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
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
