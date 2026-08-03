import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/managed_user_entity.dart';
import '../../domain/entities/role_entity.dart';
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
    _isActive = user?.isActive ?? true;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final provider = context.read<UserManagementProvider>();
    bool success;

    if (widget.userToEdit != null) {
      String roleName = _selectedRoleId!;
      for (final r in provider.roles) {
        if (r.id == _selectedRoleId) {
          roleName = r.name;
          break;
        }
      }

      final updatedUser = ManagedUserEntity(
        uid: widget.userToEdit!.uid,
        email: _emailController.text.trim(),
        displayName: _nameController.text.trim(),
        roleId: _selectedRoleId!,
        roleName: roleName,
        isActive: _isActive,
        createdAt: widget.userToEdit!.createdAt,
        createdBy: widget.userToEdit!.createdBy,
      );
      success = await provider.editUser(updatedUser);
    } else {
      success = await provider.createNewUser(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        displayName: _nameController.text.trim(),
        roleId: _selectedRoleId!,
      );
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.userToEdit != null
                ? 'User updated successfully'
                : 'User created successfully'),
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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        width: 480.w,
        padding: EdgeInsets.all(24.w),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
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
              SizedBox(height: 16.h),

              // Display Name
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
                    val == null || val.trim().isEmpty ? 'Name is required' : null,
              ),
              SizedBox(height: 16.h),

              // Email
              TextFormField(
                controller: _emailController,
                enabled: !isEditing, // email is immutable once created
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Email is required';
                  if (!val.contains('@')) return 'Enter a valid email address';
                  return null;
                },
              ),
              SizedBox(height: 16.h),

              // Password (only when creating)
              if (!isEditing) ...[
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Password is required';
                    if (val.length < 6) return 'Minimum 6 characters';
                    return null;
                  },
                ),
                SizedBox(height: 16.h),
              ],

              // Role Dropdown
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

              // Status Switch (Edit only)
              if (isEditing) ...[
                SwitchListTile(
                  title: const Text('Active Account'),
                  subtitle: Text(_isActive
                      ? 'User can sign in'
                      : 'Account is deactivated'),
                  value: _isActive,
                  activeThumbColor: const Color(0xFF13B1F2),
                  onChanged: (val) => setState(() => _isActive = val),
                ),
                SizedBox(height: 16.h),
              ],

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
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
    );
  }
}
