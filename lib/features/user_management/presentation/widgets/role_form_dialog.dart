import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/rbac/permission.dart';
import '../../domain/entities/role_entity.dart';
import '../providers/user_management_provider.dart';

class RoleFormDialog extends StatefulWidget {
  final RoleEntity? roleToEdit;

  const RoleFormDialog({super.key, this.roleToEdit});

  @override
  State<RoleFormDialog> createState() => _RoleFormDialogState();
}

class _RoleFormDialogState extends State<RoleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  final Set<AppPermission> _selectedPermissions = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final role = widget.roleToEdit;
    _nameController = TextEditingController(text: role?.name ?? '');
    if (role != null) {
      _selectedPermissions.addAll(role.permissions);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPermissions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one permission'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final provider = context.read<UserManagementProvider>();
    bool success;

    if (widget.roleToEdit != null) {
      final updatedRole = RoleEntity(
        id: widget.roleToEdit!.id,
        name: _nameController.text.trim(),
        isSystem: widget.roleToEdit!.isSystem,
        permissions: _selectedPermissions.toList(),
        createdAt: widget.roleToEdit!.createdAt,
      );
      success = await provider.editRole(updatedRole);
    } else {
      final roleId = _nameController.text.trim().toLowerCase().replaceAll(' ', '_');
      final newRole = RoleEntity(
        id: roleId,
        name: _nameController.text.trim(),
        isSystem: false,
        permissions: _selectedPermissions.toList(),
        createdAt: DateTime.now(),
      );
      success = await provider.createNewRole(newRole);
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.roleToEdit != null
                ? 'Role updated successfully'
                : 'Role created successfully'),
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
    final isEditing = widget.roleToEdit != null;
    final isSystem = widget.roleToEdit?.isSystem ?? false;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        width: 600.w,
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
                    isEditing ? 'Edit Role' : 'Create Custom Role',
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

              // Role Name
              TextFormField(
                controller: _nameController,
                enabled: !isSystem,
                decoration: InputDecoration(
                  labelText: 'Role Name',
                  prefixIcon: const Icon(Icons.shield_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Role name is required' : null,
              ),
              SizedBox(height: 20.h),

              // Permissions Header
              Text(
                'Assign Permissions',
                style: GoogleFonts.notoSans(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0B0F1A),
                ),
              ),
              SizedBox(height: 8.h),

              // Permissions Grid
              Flexible(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: AppPermission.values.map((permission) {
                      final isSelected = _selectedPermissions.contains(permission);
                      return FilterChip(
                        label: Text(permission.label),
                        selected: isSelected,
                        selectedColor: const Color(0xFF13B1F2).withValues(alpha: 0.2),
                        checkmarkColor: const Color(0xFF13B1F2),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? const Color(0xFF13B1F2)
                              : Colors.grey.shade700,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: isSystem
                            ? null
                            : (bool selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedPermissions.add(permission);
                                  } else {
                                    _selectedPermissions.remove(permission);
                                  }
                                });
                              },
                      );
                    }).toList(),
                  ),
                ),
              ),
              SizedBox(height: 24.h),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  SizedBox(width: 12.w),
                  if (!isSystem)
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
                          : Text(isEditing ? 'Save Changes' : 'Create Role'),
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
