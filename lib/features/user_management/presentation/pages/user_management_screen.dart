import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/rbac/permission.dart';
import '../../../../core/rbac/rbac_manager.dart';
import '../../../../core/widgets/modern_app_bar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/managed_user_entity.dart';
import '../../domain/entities/role_entity.dart';
import '../providers/user_management_provider.dart';
import '../widgets/role_form_dialog.dart';
import '../widgets/user_form_dialog.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserManagementProvider>().loadInitialData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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
          child: Text(
            'You do not have permission to manage users or roles.',
            style: GoogleFonts.notoSans(fontSize: 14.sp, color: Colors.grey),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: const ModernAppBar(
        title: 'User & Role Management',
      ),
      body: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar: Tab Switcher + Action Button
            Row(
              children: [
                // Custom Tab Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: const Color(0xFF13B1F2),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: const Color(0xFF64748B),
                    labelStyle: GoogleFonts.notoSans(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    tabs: const [
                      Tab(text: '  Users  '),
                      Tab(text: '  Roles & Permissions  '),
                    ],
                  ),
                ),
                const Spacer(),

                // Action Button
                if ((_tabController.index == 0 && canManageUsers) ||
                    (_tabController.index == 1 && canManageRoles))
                  ElevatedButton.icon(
                    onPressed: () {
                      if (_tabController.index == 0) {
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
                      _tabController.index == 0 ? 'Add User' : 'Add Role',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF13B1F2),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 14.h,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      elevation: 0,
                    ),
                  ),
              ],
            ),
            SizedBox(height: 20.h),

            // Tab Content
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildUsersTab(provider),
                        _buildRolesTab(provider),
                      ],
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
      return user.displayName.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query) ||
          user.roleName.toLowerCase().contains(query);
    }).toList();

    return Column(
      children: [
        // Search Bar
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: const InputDecoration(
              icon: Icon(Icons.search, color: Color(0xFF94A3B8)),
              hintText: 'Search users by name, email, or role...',
              border: InputBorder.none,
            ),
          ),
        ),
        SizedBox(height: 16.h),

        // Users List
        Expanded(
          child: filteredUsers.isEmpty
              ? _buildEmptyState('No users found')
              : ListView.separated(
                  itemCount: filteredUsers.length,
                  separatorBuilder: (_, __) => SizedBox(height: 10.h),
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    return _buildUserCard(context, user, provider);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildUserCard(
      BuildContext context, ManagedUserEntity user, UserManagementProvider provider) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade200),
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
          // User Avatar
          CircleAvatar(
            radius: 20.r,
            backgroundColor: const Color(0xFF13B1F2).withValues(alpha: 0.1),
            child: Text(
              user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U',
              style: GoogleFonts.notoSans(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF13B1F2),
              ),
            ),
          ),
          SizedBox(width: 14.w),

          // Name & Email
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: GoogleFonts.notoSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  user.email,
                  style: GoogleFonts.notoSans(
                    fontSize: 12.sp,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          // Role Badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: _getRoleBadgeColor(user.roleId).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              user.roleName.toUpperCase(),
              style: GoogleFonts.notoSans(
                fontSize: 10.sp,
                fontWeight: FontWeight.bold,
                color: _getRoleBadgeColor(user.roleId),
              ),
            ),
          ),
          SizedBox(width: 20.w),

          // Status Switch
          Row(
            children: [
              Text(
                user.isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: user.isActive ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Switch(
                value: user.isActive,
                activeThumbColor: const Color(0xFF13B1F2),
                onChanged: RbacManager.canManageUsers(
                  context.read<AuthProvider>().user,
                )
                    ? (val) {
                        provider.toggleStatus(user.uid, val);
                      }
                    : null,
              ),
            ],
          ),
          SizedBox(width: 10.w),

          // Edit Button
          if (RbacManager.canManageUsers(context.read<AuthProvider>().user))
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Color(0xFF64748B)),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => UserFormDialog(userToEdit: user),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRolesTab(UserManagementProvider provider) {
    return ListView.separated(
      itemCount: provider.roles.length,
      separatorBuilder: (_, __) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        final role = provider.roles[index];
        return _buildRoleCard(context, role, provider);
      },
    );
  }

  Widget _buildRoleCard(
      BuildContext context, RoleEntity role, UserManagementProvider provider) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icon
              Icon(
                role.isSystem ? Icons.verified_user : Icons.shield_outlined,
                color: role.isSystem ? const Color(0xFF13B1F2) : Colors.grey.shade700,
              ),
              SizedBox(width: 10.w),

              // Title
              Text(
                role.name,
                style: GoogleFonts.notoSans(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              SizedBox(width: 8.w),

              // System Badge
              if (role.isSystem)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4.r),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    'SYSTEM ROLE',
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              const Spacer(),

              // Edit / view role
              if (RbacManager.canManageRoles(context.read<AuthProvider>().user) ||
                  role.isSystem)
                IconButton(
                  icon: Icon(
                    role.isSystem ? Icons.visibility_outlined : Icons.edit_outlined,
                    color: const Color(0xFF64748B),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => RoleFormDialog(roleToEdit: role),
                    );
                  },
                ),

              // Delete Button (only non-system roles + manage_roles)
              if (!role.isSystem &&
                  RbacManager.canManageRoles(context.read<AuthProvider>().user))
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
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
          SizedBox(height: 10.h),

          // Permissions summary
          Text(
            'Permissions (${role.permissions.length}):',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 6.h),

          Wrap(
            spacing: 6.w,
            runSpacing: 4.h,
            children: role.permissions.map((p) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  p.label,
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: const Color(0xFF334155),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 48.r, color: Colors.grey.shade400),
          SizedBox(height: 8.h),
          Text(
            message,
            style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
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
        return Colors.grey.shade700;
    }
  }
}
