import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/rbac/rbac_manager.dart';
import '../../../employee/domain/entities/employee_entity.dart';
import '../../../employee/presentation/providers/employee_provider.dart';
import '../../domain/entities/managed_user_entity.dart';
import '../providers/user_management_provider.dart';

class UserFormDialog extends StatefulWidget {
  final ManagedUserEntity? userToEdit;

  const UserFormDialog({super.key, this.userToEdit});

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _emailController;
  late TextEditingController _nameController;
  late TextEditingController _passwordController;
  String? _selectedRoleId;
  String? _selectedEmployeeId;
  bool _isActive = true;
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final user = widget.userToEdit;
    _emailController = TextEditingController(text: user?.email ?? '');
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _passwordController = TextEditingController();
    _selectedRoleId = user?.roleId ?? 'office_staff';
    _selectedEmployeeId = user?.employeeId;
    _isActive = user?.isActive ?? true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final emp = context.read<EmployeeProvider>();
      if (emp.employees.isEmpty) {
        emp.fetchAllEmployees();
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onEmployeeSelected(String? employeeId, List<EmployeeEntity> employees) {
    setState(() => _selectedEmployeeId = employeeId);
    if (employeeId == null) return;
    EmployeeEntity? match;
    for (final e in employees) {
      if (e.id == employeeId) {
        match = e;
        break;
      }
    }
    if (match == null) return;
    _nameController.text = match.fullName;
    if (match.email.trim().isNotEmpty) {
      _emailController.text = match.email.trim();
    }
  }

  String? _employeeName(List<EmployeeEntity> employees) {
    if (_selectedEmployeeId == null) return null;
    for (final e in employees) {
      if (e.id == _selectedEmployeeId) return e.fullName;
    }
    return widget.userToEdit?.employeeName;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final provider = context.read<UserManagementProvider>();
    final employees = context.read<EmployeeProvider>().employees;
    final employeeName = _employeeName(employees);
    bool success;

    if (widget.userToEdit != null) {
      String roleName = _selectedRoleId!;
      for (final r in provider.roles) {
        if (r.id == _selectedRoleId) {
          roleName = r.name;
          break;
        }
      }

      final roleId = RbacManager.normalizeRoleId(_selectedRoleId);
      String? photoUrl = widget.userToEdit!.photoUrl;
      for (final e in employees) {
        if (e.id == _selectedEmployeeId) {
          photoUrl = e.imageUrl;
          break;
        }
      }
      if (_selectedEmployeeId == null) photoUrl = null;

      final updatedUser = ManagedUserEntity(
        uid: widget.userToEdit!.uid,
        email: _emailController.text.trim(),
        displayName: _nameController.text.trim(),
        roleId: roleId,
        roleName: roleName,
        isActive: _isActive,
        createdAt: widget.userToEdit!.createdAt,
        createdBy: widget.userToEdit!.createdBy,
        employeeId: _selectedEmployeeId,
        employeeName: employeeName,
        photoUrl: photoUrl,
      );
      success = await provider.editUser(updatedUser);
    } else {
      success = await provider.createNewUser(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        displayName: _nameController.text.trim(),
        roleId: RbacManager.normalizeRoleId(_selectedRoleId),
        employeeId: _selectedEmployeeId,
        employeeName: employeeName,
      );
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.userToEdit != null
                  ? 'User updated successfully'
                  : 'User created successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'An error occurred'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.userToEdit != null;
    final roles = context.watch<UserManagementProvider>().roles;
    final employeeProvider = context.watch<EmployeeProvider>();
    final employees = employeeProvider.employees
        .where((e) => e.isActive)
        .toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));

    // Employees already linked to another login (exclude current user when editing)
    final linkedElsewhere = <String>{};
    for (final u in context.watch<UserManagementProvider>().users) {
      if (u.employeeId == null || u.employeeId!.isEmpty) continue;
      if (isEditing && u.uid == widget.userToEdit!.uid) continue;
      linkedElsewhere.add(u.employeeId!);
    }

    final selectableEmployees = employees
        .where(
          (e) =>
              !linkedElsewhere.contains(e.id) || e.id == _selectedEmployeeId,
        )
        .toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        width: 480.w,
        padding: EdgeInsets.all(24.w),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'Edit User' : 'Create New User',
                      style: GoogleFonts.notoSans(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0B0F1A),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                SizedBox(height: 12.h),

                // Link to employee
                Text(
                  'Link to employee (optional)',
                  style: GoogleFonts.notoSans(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                SizedBox(height: 8.h),
                DropdownButtonFormField<String?>(
                  // ignore: deprecated_member_use
                  value: _selectedEmployeeId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Employee',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    helperText:
                        'Connect this login to an employee from HR records',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('— Not linked —'),
                    ),
                    ...selectableEmployees.map((e) {
                      final label = e.email.isNotEmpty
                          ? '${e.fullName} (${e.position}) · ${e.email}'
                          : '${e.fullName} (${e.position})';
                      return DropdownMenuItem<String?>(
                        value: e.id,
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                  onChanged: (val) =>
                      _onEmployeeSelected(val, selectableEmployees),
                ),
                if (employeeProvider.isLoading)
                  Padding(
                    padding: EdgeInsets.only(top: 8.h),
                    child: const LinearProgressIndicator(minHeight: 2),
                  ),
                SizedBox(height: 16.h),

                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  validator: (val) =>
                      val == null || val.trim().isEmpty
                          ? 'Name is required'
                          : null,
                ),
                SizedBox(height: 16.h),

                TextFormField(
                  controller: _emailController,
                  enabled: !isEditing,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!val.contains('@')) return 'Enter a valid email address';
                    return null;
                  },
                ),
                SizedBox(height: 16.h),

                if (!isEditing) ...[
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Password is required';
                      }
                      if (val.length < 6) return 'Minimum 6 characters';
                      return null;
                    },
                  ),
                  SizedBox(height: 16.h),
                ],

                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: _selectedRoleId,
                  decoration: InputDecoration(
                    labelText: 'Role',
                    prefixIcon:
                        const Icon(Icons.admin_panel_settings_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  items: roles.map((role) {
                    return DropdownMenuItem<String>(
                      value: role.id,
                      child: Text(role.name),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedRoleId = val),
                  validator: (val) => val == null ? 'Select a role' : null,
                ),
                SizedBox(height: 16.h),

                if (isEditing) ...[
                  SwitchListTile(
                    title: const Text('Active Account'),
                    subtitle: Text(
                      _isActive
                          ? 'User can sign in'
                          : 'Account is deactivated',
                    ),
                    value: _isActive,
                    activeThumbColor: const Color(0xFF13B1F2),
                    onChanged: (val) => setState(() => _isActive = val),
                  ),
                  SizedBox(height: 8.h),
                ],

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _isSubmitting ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    SizedBox(width: 12.w),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF13B1F2),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 24.w,
                          vertical: 12.h,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      child: _isSubmitting
                          ? SizedBox(
                              width: 20.w,
                              height: 20.h,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(isEditing ? 'Save Changes' : 'Create User'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
