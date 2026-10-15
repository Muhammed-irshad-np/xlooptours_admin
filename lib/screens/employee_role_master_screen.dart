import 'package:flutter/material.dart';
import 'package:xloop_invoice/core/utils/app_snack_bar.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';

import '../features/employee/domain/entities/employee_role_entity.dart';
import '../features/employee/presentation/providers/employee_provider.dart';
import '../core/widgets/modern_app_bar.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../core/widgets/confirm_save_dialog.dart';

class EmployeeRoleMasterScreen extends StatefulWidget {
  const EmployeeRoleMasterScreen({super.key});

  @override
  State<EmployeeRoleMasterScreen> createState() =>
      _EmployeeRoleMasterScreenState();
}

class _EmployeeRoleMasterScreenState extends State<EmployeeRoleMasterScreen> {
  final ValueNotifier<bool> _isLoading = ValueNotifier(true);

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    _isLoading.value = true;
    try {
      final provider = context.read<EmployeeProvider>();
      // Employees are needed for the per-role head count.
      await Future.wait([
        provider.fetchEmployeeRoles(),
        if (provider.employees.isEmpty) provider.fetchAllEmployees(),
      ]);
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, 'Error loading roles: $e');
    } finally {
      if (mounted) _isLoading.value = false;
    }
  }

  Future<void> _deleteRole(EmployeeRoleEntity role, int holders) async {
    if (holders > 0) {
      AppSnackBar.showWarning(
        context,
        '${role.name} is assigned to $holders employee(s). '
        'Reassign them before deleting this role.',
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Role'),
        content: Text('Are you sure you want to delete ${role.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await context.read<EmployeeProvider>().deleteEmployeeRole(role.id);
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, 'Error deleting role: $e');
    }
  }

  void _showAddEditDialog({EmployeeRoleEntity? role}) {
    final provider = context.read<EmployeeProvider>();
    showDialog(
      context: context,
      builder: (context) => _AddEditRoleDialog(
        role: role,
        existingNames: provider.roles
            .where((r) => r.id != role?.id)
            .map((r) => r.name.toLowerCase())
            .toSet(),
        holders: role == null
            ? 0
            : provider.employees.where((e) => e.position == role.name).length,
        onSave: (newRole) async {
          try {
            await provider.saveEmployeeRole(newRole);
          } catch (e) {
            if (mounted) {
              AppSnackBar.showError(this.context, 'Error saving role: $e');
            }
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _isLoading.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin =
        context.watch<AuthProvider>().user?.isSuperAdmin ?? false;
    final provider = context.watch<EmployeeProvider>();
    final roles = provider.roles;

    return Scaffold(
      appBar: const ModernAppBar(title: 'Employee Roles'),
      body: ValueListenableBuilder<bool>(
        valueListenable: _isLoading,
        builder: (context, isLoading, _) {
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (roles.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.badge, size: 64.sp, color: Colors.grey),
                  SizedBox(height: 16.h),
                  Text(
                    'No roles found',
                    style: TextStyle(color: Colors.grey, fontSize: 16.sp),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.all(16.w),
            itemCount: roles.length,
            separatorBuilder: (context, index) => SizedBox(height: 12.h),
            itemBuilder: (context, index) {
              final role = roles[index];
              final holders = provider.employees
                  .where((e) => e.position == role.name)
                  .length;
              return Card(
                child: ListTile(
                  title: Text(
                    role.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                  subtitle: Text(
                    'Group: ${role.category}  |  '
                    '$holders employee${holders == 1 ? '' : 's'}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14.sp),
                  ),
                  trailing: role.isBuiltIn
                      ? Tooltip(
                          message: 'Built-in role',
                          child: Icon(Icons.lock, color: Colors.grey[400]),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.orange,
                              ),
                              onPressed: () => _showAddEditDialog(role: role),
                              tooltip: 'Edit',
                            ),
                            if (isSuperAdmin)
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => _deleteRole(role, holders),
                                tooltip: 'Delete',
                              ),
                          ],
                        ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'addBtnEmployeeRole',
        onPressed: () => _showAddEditDialog(),
        label: const Text('Add Role'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _AddEditRoleDialog extends StatefulWidget {
  final EmployeeRoleEntity? role;
  final Set<String> existingNames;
  final int holders;
  final Future<void> Function(EmployeeRoleEntity) onSave;

  const _AddEditRoleDialog({
    this.role,
    required this.existingNames,
    required this.holders,
    required this.onSave,
  });

  @override
  State<_AddEditRoleDialog> createState() => _AddEditRoleDialogState();
}

class _AddEditRoleDialogState extends State<_AddEditRoleDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late String _category;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.role?.name ?? '');
    _category = widget.role?.category ?? EmployeeRoleCategory.other;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final isRename = widget.role != null && widget.role!.name != name;

    final confirmed = await showConfirmSaveDialog(
      context: context,
      title: widget.role == null ? 'Confirm Add Role' : 'Confirm Update Role',
      entityName: name,
      sections: [
        ConfirmDetailSection(
          title: 'Employee Role',
          icon: Icons.badge_outlined,
          entries: [
            ConfirmDetailEntry(label: 'Name', value: name),
            ConfirmDetailEntry(label: 'Group', value: _category),
            if (isRename && widget.holders > 0)
              ConfirmDetailEntry(
                label: 'Employees Updated',
                value: '${widget.holders} (from ${widget.role!.name})',
              ),
          ],
        ),
      ],
    );
    if (confirmed != true || !mounted) return;

    await widget.onSave(
      EmployeeRoleEntity(
        id: widget.role?.id ?? const Uuid().v4(),
        name: name,
        category: _category,
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.role == null ? 'Add Role' : 'Edit Role',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Role Name (e.g. Accountant)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final name = v?.trim() ?? '';
                  if (name.isEmpty) return 'Required';
                  if (widget.existingNames.contains(name.toLowerCase())) {
                    return 'A role with this name already exists';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Employees List Group',
                  border: OutlineInputBorder(),
                ),
                items: EmployeeRoleCategory.values
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              if (widget.role != null && widget.holders > 0) ...[
                const SizedBox(height: 12),
                Text(
                  'Renaming updates the position of the ${widget.holders} '
                  'employee(s) holding this role.',
                  style: TextStyle(fontSize: 13, color: Colors.orange[800]),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(onPressed: _save, child: const Text('Save')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
