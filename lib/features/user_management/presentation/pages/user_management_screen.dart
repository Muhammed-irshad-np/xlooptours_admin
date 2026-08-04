import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/rbac/permission.dart';
import '../../../../core/rbac/rbac_manager.dart';
import '../../../../core/widgets/modern_app_bar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/managed_user_entity.dart';
import '../../domain/entities/role_entity.dart';
import '../providers/user_management_provider.dart';
import '../widgets/change_login_email_dialog.dart';
import '../widgets/change_password_dialog.dart';
import '../widgets/role_form_dialog.dart';
import '../widgets/user_form_dialog.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  int _selectedTabIndex = 0; // 0 = Users, 1 = Roles & Permissions
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _roleFilter = 'ALL';
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserManagementProvider>().loadInitialData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserManagementProvider>();
    final authUser = context.watch<AuthProvider>().user;
    final canManageUsers = RbacManager.canManageUsers(authUser);
    final canManageRoles = RbacManager.canManageRoles(authUser);

    if (!canManageUsers && !canManageRoles) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: const ModernAppBar(title: 'User & Role Management'),
        body: Center(
          child: Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_person_outlined,
                  size: 48.sp,
                  color: Colors.amber.shade700,
                ),
                SizedBox(height: 12.h),
                Text(
                  'Access Restricted',
                  style: GoogleFonts.merriweather(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'You do not have permission to manage users or security roles.',
                  style: GoogleFonts.notoSans(
                    fontSize: 13.sp,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Stats calculations
    final totalUsers = provider.users.length;
    final activeUsers = provider.users.where((u) => u.isActive).length;
    final onlineNow = provider.users.where((u) => u.isOnlineNow).length;
    final adminCount = provider.users
        .where((u) => u.roleId == 'super_admin' || u.roleId == 'admin')
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: const ModernAppBar(title: 'User & Role Management'),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Description & Action Button Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Access Control & Security Directory',
                        style: GoogleFonts.merriweather(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Manage administrative accounts, role assignments, authentication credentials, and permission rules.',
                        style: GoogleFonts.notoSans(
                          fontSize: 13.sp,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16.w),

                // Primary Action Button
                if ((_selectedTabIndex == 0 && canManageUsers) ||
                    (_selectedTabIndex == 1 && canManageRoles))
                  ElevatedButton.icon(
                    onPressed: () {
                      if (_selectedTabIndex == 0) {
                        showDialog(
                          context: context,
                          builder: (_) => const UserFormDialog(),
                        );
                      } else {
                        showDialog(
                          context: context,
                          builder: (_) => const RoleFormDialog(),
                        );
                      }
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(
                      _selectedTabIndex == 0
                          ? 'Create New User'
                          : 'Create Custom Role',
                      style: GoogleFonts.notoSans(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF13B1F2),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 14.h,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      elevation: 0,
                    ),
                  ),
              ],
            ),
            SizedBox(height: 20.h),

            // KPI Summary Row
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    title: 'Total Users',
                    value: totalUsers.toString(),
                    icon: Icons.people_alt_outlined,
                    color: const Color(0xFF13B1F2),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: _buildKpiCard(
                    title: 'Active Accounts',
                    value: activeUsers.toString(),
                    icon: Icons.check_circle_outline,
                    color: const Color(0xFF10B981),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: _buildKpiCard(
                    title: 'Online Now',
                    value: onlineNow.toString(),
                    icon: Icons.sensors,
                    color: const Color(0xFF10B981),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: _buildKpiCard(
                    title: 'Administrators',
                    value: adminCount.toString(),
                    icon: Icons.admin_panel_settings_outlined,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),

            // Custom Pill Tab Switcher (Completely filled active tab indicator)
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTabItem(
                    index: 0,
                    label: 'User Accounts',
                    icon: Icons.person_search_outlined,
                    count: provider.users.length,
                  ),
                  SizedBox(width: 4.w),
                  _buildTabItem(
                    index: 1,
                    label: 'Roles & Permissions',
                    icon: Icons.security_outlined,
                    count: provider.roles.length,
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),

            // Tab Content
            provider.isLoading
                ? Padding(
                    padding: EdgeInsets.symmetric(vertical: 60.h),
                    child: const Center(child: CircularProgressIndicator()),
                  )
                : _selectedTabIndex == 0
                ? _buildUsersTab(provider)
                : _buildRolesTab(provider),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, color: color, size: 22.sp),
          ),
          SizedBox(width: 14.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.notoSans(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                title,
                style: GoogleFonts.notoSans(
                  fontSize: 11.sp,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required int index,
    required String label,
    required IconData icon,
    required int count,
  }) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF13B1F2) : Colors.transparent,
          borderRadius: BorderRadius.circular(10.r),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF13B1F2).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16.sp,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            SizedBox(width: 8.w),
            Text(
              label,
              style: GoogleFonts.notoSans(
                fontSize: 13.sp,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
            ),
            SizedBox(width: 8.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Text(
                count.toString(),
                style: GoogleFonts.notoSans(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab(UserManagementProvider provider) {
    final filteredUsers = provider.users.where((user) {
      final query = _searchQuery.toLowerCase();
      final matchesQuery =
          user.displayName.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query) ||
          user.roleName.toLowerCase().contains(query);

      final matchesRole = _roleFilter == 'ALL' || user.roleId == _roleFilter;
      final matchesStatus =
          _statusFilter == 'ALL' ||
          (_statusFilter == 'ONLINE' && user.isOnlineNow) ||
          (_statusFilter == 'ACTIVE' && user.isActive) ||
          (_statusFilter == 'INACTIVE' && !user.isActive);

      return matchesQuery && matchesRole && matchesStatus;
    }).toList()
      // Online first, then by most recent login
      ..sort((a, b) {
        final aOnline = a.isOnlineNow ? 0 : 1;
        final bOnline = b.isOnlineNow ? 0 : 1;
        if (aOnline != bOnline) return aOnline.compareTo(bOnline);
        final aLogin = a.lastLoginAt ?? a.lastActiveAt;
        final bLogin = b.lastLoginAt ?? b.lastActiveAt;
        if (aLogin == null && bLogin == null) return 0;
        if (aLogin == null) return 1;
        if (bLogin == null) return -1;
        return bLogin.compareTo(aLogin);
      });

    return Column(
      children: [
        // Search & Filter Toolbar
        Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              // Search Field
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: GoogleFonts.notoSans(
                    fontSize: 13.sp,
                    color: const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF94A3B8),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    hintText: 'Search by name, email, or role...',
                    hintStyle: GoogleFonts.notoSans(
                      fontSize: 13.sp,
                      color: const Color(0xFF94A3B8),
                    ),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 10.h,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),

              // Role Filter Dropdown
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _roleFilter,
                    icon: const Icon(
                      Icons.filter_list,
                      color: Color(0xFF64748B),
                      size: 18,
                    ),
                    style: GoogleFonts.notoSans(
                      fontSize: 12.sp,
                      color: const Color(0xFF334155),
                      fontWeight: FontWeight.w600,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'ALL',
                        child: Text('All Roles'),
                      ),
                      ...provider.roles.map(
                        (r) =>
                            DropdownMenuItem(value: r.id, child: Text(r.name)),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _roleFilter = val);
                    },
                  ),
                ),
              ),
              SizedBox(width: 10.w),

              // Status Filter Dropdown
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _statusFilter,
                    icon: const Icon(
                      Icons.tune,
                      color: Color(0xFF64748B),
                      size: 18,
                    ),
                    style: GoogleFonts.notoSans(
                      fontSize: 12.sp,
                      color: const Color(0xFF334155),
                      fontWeight: FontWeight.w600,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All Status')),
                      DropdownMenuItem(
                        value: 'ONLINE',
                        child: Text('Online Now'),
                      ),
                      DropdownMenuItem(
                        value: 'ACTIVE',
                        child: Text('Active Only'),
                      ),
                      DropdownMenuItem(
                        value: 'INACTIVE',
                        child: Text('Inactive Only'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _statusFilter = val);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),

        // Users List Cards
        filteredUsers.isEmpty
            ? _buildEmptyState('No users found matching your filters')
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredUsers.length,
                separatorBuilder: (_, __) => SizedBox(height: 12.h),
                itemBuilder: (context, index) {
                  final user = filteredUsers[index];
                  return _buildUserCard(context, user, provider);
                },
              ),
      ],
    );
  }

  Widget _buildUserCard(
    BuildContext context,
    ManagedUserEntity user,
    UserManagementProvider provider,
  ) {
    final roleColor = _getRoleBadgeColor(user.roleId);

    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Builder(
            builder: (_) {
              final photo = user.photoUrl?.trim();
              final hasPhoto = photo != null && photo.isNotEmpty;
              final initial = user.displayName.isNotEmpty
                  ? user.displayName[0].toUpperCase()
                  : 'U';
              return CircleAvatar(
                radius: 22.r,
                backgroundColor: roleColor.withValues(alpha: 0.12),
                backgroundImage: hasPhoto ? NetworkImage(photo) : null,
                onBackgroundImageError: hasPhoto ? (_, __) {} : null,
                child: hasPhoto
                    ? null
                    : Text(
                        initial,
                        style: GoogleFonts.notoSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.sp,
                          color: roleColor,
                        ),
                      ),
              );
            },
          ),
          SizedBox(width: 16.w),

          // User Info
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.displayName,
                        style: GoogleFonts.notoSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.sp,
                          color: const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    _buildPresenceChip(user),
                    if (!user.isActive) ...[
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          'DEACTIVATED',
                          style: GoogleFonts.notoSans(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  user.email,
                  style: GoogleFonts.notoSans(
                    fontSize: 12.sp,
                    color: const Color(0xFF64748B),
                  ),
                ),
                if (user.hasEmployeeLink) ...[
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Icon(
                        Icons.badge_outlined,
                        size: 13.sp,
                        color: const Color(0xFF13B1F2),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        user.employeeName ?? 'Linked employee',
                        style: GoogleFonts.notoSans(
                          fontSize: 11.sp,
                          color: const Color(0xFF13B1F2),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Role Badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: roleColor.withValues(alpha: 0.2)),
            ),
            child: Text(
              user.roleName.toUpperCase(),
              style: GoogleFonts.notoSans(
                fontSize: 10.sp,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: roleColor,
              ),
            ),
          ),
          SizedBox(width: 16.w),

          // Activity (last login / last seen) — admin visibility
          if (context.read<AuthProvider>().user?.isAdmin == true)
            SizedBox(
              width: 160.w,
              child: _buildActivityColumn(user),
            ),

          SizedBox(width: 12.w),

          // Account enabled switch
          Row(
            children: [
              Text(
                user.isActive ? 'Enabled' : 'Disabled',
                style: GoogleFonts.notoSans(
                  fontSize: 12.sp,
                  color: user.isActive
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 4.w),
              Switch(
                value: user.isActive,
                activeThumbColor: const Color(0xFF13B1F2),
                onChanged:
                    RbacManager.canManageUsers(
                      context.read<AuthProvider>().user,
                    )
                    ? (val) {
                        provider.toggleStatus(user.uid, val);
                      }
                    : null,
              ),
            ],
          ),
          SizedBox(width: 12.w),

          // Admin / Super Admin Quick Actions
          if (context.read<AuthProvider>().user?.isAdmin == true) ...[
            Tooltip(
              message: 'Change login email',
              child: IconButton(
                icon: Icon(
                  Icons.alternate_email,
                  size: 18.sp,
                  color: const Color(0xFF64748B),
                ),
                onPressed: () {
                  if (user.uid.contains('@')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'This user has no Auth account id. Cannot change login email.',
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  showDialog(
                    context: context,
                    builder: (_) => ChangeLoginEmailDialog(user: user),
                  );
                },
              ),
            ),
            Tooltip(
              message: 'Change password',
              child: IconButton(
                icon: Icon(
                  Icons.lock_reset_outlined,
                  size: 18.sp,
                  color: const Color(0xFF64748B),
                ),
                onPressed: () {
                  if (user.uid.contains('@')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'This user has no Auth account id. Recreate user to set a password.',
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  showDialog(
                    context: context,
                    builder: (_) => ChangePasswordDialog(user: user),
                  );
                },
              ),
            ),
          ],

          // Edit User Button
          if (RbacManager.canManageUsers(context.read<AuthProvider>().user))
            Tooltip(
              message: 'Edit user profile',
              child: IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  size: 18.sp,
                  color: const Color(0xFF64748B),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => UserFormDialog(userToEdit: user),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRolesTab(UserManagementProvider provider) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: provider.roles.length,
      separatorBuilder: (_, __) => SizedBox(height: 14.h),
      itemBuilder: (context, index) {
        final role = provider.roles[index];
        return _buildRoleCard(context, role, provider);
      },
    );
  }

  Widget _buildRoleCard(
    BuildContext context,
    RoleEntity role,
    UserManagementProvider provider,
  ) {
    final roleColor = _getRoleBadgeColor(role.id);

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icon Badge
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  role.isSystem ? Icons.verified_user : Icons.shield_outlined,
                  color: roleColor,
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 14.w),

              // Title
              Text(
                role.name,
                style: GoogleFonts.notoSans(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              SizedBox(width: 10.w),

              // System Badge
              if (role.isSystem)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6.r),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Text(
                    'SYSTEM ROLE',
                    style: GoogleFonts.notoSans(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1D4ED8),
                    ),
                  ),
                ),
              const Spacer(),

              // Edit / view role
              if (RbacManager.canManageRoles(
                    context.read<AuthProvider>().user,
                  ) ||
                  role.isSystem)
                IconButton(
                  tooltip: role.isSystem ? 'View permissions' : 'Edit role',
                  icon: Icon(
                    role.isSystem
                        ? Icons.visibility_outlined
                        : Icons.edit_outlined,
                    color: const Color(0xFF64748B),
                    size: 18.sp,
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => RoleFormDialog(roleToEdit: role),
                    );
                  },
                ),

              // Delete Button
              if (!role.isSystem &&
                  RbacManager.canManageRoles(context.read<AuthProvider>().user))
                IconButton(
                  tooltip: 'Delete role',
                  icon: Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                    size: 18.sp,
                  ),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Delete Role'),
                        content: Text(
                          'Are you sure you want to delete "${role.name}"?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      final ok = await provider.removeRole(role.id);
                      if (context.mounted && !ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              provider.errorMessage ?? 'Failed to delete role',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                ),
            ],
          ),
          SizedBox(height: 14.h),

          // Permissions summary
          Text(
            'Granted Permissions (${role.permissions.length}):',
            style: GoogleFonts.notoSans(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 8.h),

          Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            children: role.permissions.map((p) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6.r),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  p.label,
                  style: GoogleFonts.notoSans(
                    fontSize: 11.sp,
                    color: const Color(0xFF334155),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 48.sp,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 12.h),
            Text(
              message,
              style: GoogleFonts.notoSans(
                fontSize: 14.sp,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresenceChip(ManagedUserEntity user) {
    final Color color;
    final Color bg;
    switch (user.presence) {
      case UserPresence.online:
        color = const Color(0xFF059669);
        bg = const Color(0xFFECFDF5);
        break;
      case UserPresence.away:
        color = const Color(0xFFD97706);
        bg = const Color(0xFFFFFBEB);
        break;
      case UserPresence.offline:
        color = const Color(0xFF64748B);
        bg = const Color(0xFFF1F5F9);
        break;
      case UserPresence.never:
        color = const Color(0xFF94A3B8);
        bg = const Color(0xFFF8FAFC);
        break;
      case UserPresence.deactivated:
        color = const Color(0xFFDC2626);
        bg = const Color(0xFFFEF2F2);
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7.w,
            height: 7.w,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 5.w),
          Text(
            user.presenceLabel,
            style: GoogleFonts.notoSans(
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityColumn(ManagedUserEntity user) {
    final loginText = _formatActivityTime(user.lastLoginAt);
    final seenText = _formatActivityTime(user.lastActiveAt ?? user.lastLoginAt);
    final dateFmt = DateFormat('dd MMM yyyy · HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Last login',
          style: GoogleFonts.notoSans(
            fontSize: 10.sp,
            color: const Color(0xFF94A3B8),
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          loginText,
          style: GoogleFonts.notoSans(
            fontSize: 12.sp,
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.w600,
          ),
        ),
        if (user.lastLoginAt != null)
          Text(
            dateFmt.format(user.lastLoginAt!),
            style: GoogleFonts.notoSans(
              fontSize: 10.sp,
              color: const Color(0xFF94A3B8),
            ),
          ),
        SizedBox(height: 6.h),
        Text(
          'Last seen  ·  ${user.loginCount} logins',
          style: GoogleFonts.notoSans(
            fontSize: 10.sp,
            color: const Color(0xFF94A3B8),
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          seenText,
          style: GoogleFonts.notoSans(
            fontSize: 11.sp,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  String _formatActivityTime(DateTime? time) {
    if (time == null) return '—';
    return timeago.format(time, allowFromNow: true);
  }

  Color _getRoleBadgeColor(String roleId) {
    switch (roleId) {
      case 'super_admin':
        return Colors.purple;
      case 'admin':
        return const Color(0xFF13B1F2);
      case 'coordinator':
        return Colors.amber.shade800;
      case 'driver':
        return Colors.teal;
      case 'office_staff':
        return Colors.indigo;
      default:
        return Colors.blueGrey;
    }
  }
}
