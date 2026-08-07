import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/rbac/rbac_manager.dart';
import '../../../../core/utils/activity_logger.dart';
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
    _selectedRoleId = user?.roleId;
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

  /// Employee link only attaches HR identity (photo, name).
  /// Login email is separate: it is the Firebase Auth username.
  /// We prefill name/email from employee as a convenience when creating —
  /// admin can still change the login email before saving.
  void _onEmployeeSelected(String? employeeId, List<EmployeeEntity> employees) {
    setState(() => _selectedEmployeeId = employeeId);
    if (employeeId == null) return;
    if (widget.userToEdit != null)
      return; // editing: don't overwrite login email

    EmployeeEntity? match;
    for (final e in employees) {
      if (e.id == employeeId) {
        match = e;
        break;
      }
    }
    if (match == null) return;
    _nameController.text = match.fullName;
    // Suggest employee email as login username only if field empty
    if (_emailController.text.trim().isEmpty && match.email.trim().isNotEmpty) {
      _emailController.text = match.email.trim().toLowerCase();
    }
  }

  String? _selectedEmployeeContactEmail(List<EmployeeEntity> employees) {
    if (_selectedEmployeeId == null) return null;
    for (final e in employees) {
      if (e.id == _selectedEmployeeId) {
        final mail = e.email.trim();
        return mail.isEmpty ? null : mail;
      }
    }
    return null;
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

    if (widget.userToEdit == null) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          title: Text(
            'Confirm User Creation',
            style: GoogleFonts.notoSans(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          content: Text(
            'Are you sure you want to create a new user with the provided details?',
            style: GoogleFonts.notoSans(color: const Color(0xFF475569)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF13B1F2),
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    if (!mounted) return;
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

      // Login email is immutable here — never take it from the employee link.
      final updatedUser = ManagedUserEntity(
        uid: widget.userToEdit!.uid,
        email: widget.userToEdit!.email,
        displayName: _nameController.text.trim(),
        roleId: roleId,
        roleName: roleName,
        isActive: _isActive,
        createdAt: widget.userToEdit!.createdAt,
        createdBy: widget.userToEdit!.createdBy,
        employeeId: _selectedEmployeeId,
        employeeName: employeeName,
        photoUrl: photoUrl,
        lastLoginAt: widget.userToEdit!.lastLoginAt,
        lastActiveAt: widget.userToEdit!.lastActiveAt,
        lastLogoutAt: widget.userToEdit!.lastLogoutAt,
        sessionActive: widget.userToEdit!.sessionActive,
        loginCount: widget.userToEdit!.loginCount,
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
        final emailVal = widget.userToEdit != null
            ? widget.userToEdit!.email
            : _emailController.text.trim();
        final uidVal = widget.userToEdit?.uid;
        await ActivityLogger.log(
          context,
          title: widget.userToEdit != null ? 'User Updated' : 'User Created',
          message: widget.userToEdit != null
              ? 'User $emailVal has been updated.'
              : 'User $emailVal has been created.',
          relatedId: uidVal,
        );
        if (mounted) {
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
        }
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
    final employees =
        employeeProvider.employees.where((e) => e.isActive).toList()
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
          (e) => !linkedElsewhere.contains(e.id) || e.id == _selectedEmployeeId,
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
                        'Photo & name come from the employee. Login email is separate.',
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
                        child: Text(label, overflow: TextOverflow.ellipsis),
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
                Builder(
                  builder: (_) {
                    final contact = _selectedEmployeeContactEmail(
                      selectableEmployees,
                    );
                    if (contact == null) return const SizedBox.shrink();
                    return Padding(
                      padding: EdgeInsets.only(top: 6.h),
                      child: Text(
                        'Employee contact email: $contact',
                        style: GoogleFonts.notoSans(
                          fontSize: 11.sp,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: 16.h),

                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Display name',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Name is required'
                      : null,
                ),
                SizedBox(height: 16.h),

                if (!isEditing)
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Login email (username)',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      helperText:
                          'What they type at login. Linking an employee only fills this if empty — it is not the employee contact email.',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Login email is required';
                      }
                      if (!val.contains('@')) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  )
                else
                  _LoginEmailFixSection(
                    uid: widget.userToEdit!.uid,
                    currentEmail: widget.userToEdit!.email,
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
                    prefixIcon: const Icon(Icons.admin_panel_settings_outlined),
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
                      _isActive ? 'User can sign in' : 'Account is deactivated',
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
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.pop(context),
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

/// Shows stored login email and lets admin fix it if it was wrongly
/// overwritten when linking an employee (Auth password login is unchanged).
class _LoginEmailFixSection extends StatefulWidget {
  final String uid;
  final String currentEmail;

  const _LoginEmailFixSection({required this.uid, required this.currentEmail});

  @override
  State<_LoginEmailFixSection> createState() => _LoginEmailFixSectionState();
}

class _LoginEmailFixSectionState extends State<_LoginEmailFixSection> {
  late final TextEditingController _controller;
  bool _expanded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentEmail);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final email = _controller.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid login email'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final ok = await context.read<UserManagementProvider>().changeLoginEmail(
      uid: widget.uid,
      newEmail: email,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    final provider = context.read<UserManagementProvider>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Login email updated in User Management'
              : (provider.errorMessage ?? 'Failed to update'),
        ),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
    if (ok) setState(() => _expanded = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Login email (username)',
            style: GoogleFonts.notoSans(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            widget.currentEmail,
            style: GoogleFonts.notoSans(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'This is their sign-in username. Use @ on the user list (or expand below) to change it in Firebase Auth.',
            style: GoogleFonts.notoSans(
              fontSize: 11.sp,
              color: const Color(0xFF94A3B8),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded ? 'Cancel' : 'Change login email',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          if (_expanded) ...[
            TextFormField(
              controller: _controller,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'New login email',
                hintText: 'They will use this email to sign in',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13B1F2),
                  foregroundColor: Colors.white,
                ),
                child: _saving
                    ? SizedBox(
                        width: 18.w,
                        height: 18.h,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Update login email'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
