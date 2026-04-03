import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';

import '../features/vehicle/domain/entities/maintenance_type_entity.dart';
import '../features/vehicle/presentation/providers/vehicle_provider.dart';
import '../core/widgets/modern_app_bar.dart';

class MaintenanceTypeMasterScreen extends StatefulWidget {
  const MaintenanceTypeMasterScreen({super.key});

  @override
  State<MaintenanceTypeMasterScreen> createState() =>
      _MaintenanceTypeMasterScreenState();
}

class _MaintenanceTypeMasterScreenState
    extends State<MaintenanceTypeMasterScreen> {
  final ValueNotifier<List<MaintenanceTypeEntity>> _types = ValueNotifier([]);
  final ValueNotifier<bool> _isLoading = ValueNotifier(true);

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  Future<void> _loadTypes() async {
    _isLoading.value = true;
    try {
      if (mounted) {
        await context.read<VehicleProvider>().fetchAllMaintenanceTypes();
        if (!mounted) return;
        _types.value = context.read<VehicleProvider>().maintenanceTypes;
        _isLoading.value = false;
      }
    } catch (e) {
      debugPrint('Error loading maintenance types: \$e');
      if (mounted) {
        _isLoading.value = false;
      }
    }
  }

  Future<void> _deleteType(String id) async {
    try {
      if (mounted) {
        await context.read<VehicleProvider>().deleteMaintenanceType(id);
        _loadTypes();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting type: \$e')));
      }
    }
  }

  void _showAddEditDialog({MaintenanceTypeEntity? type}) {
    showDialog(
      context: context,
      builder: (context) => _AddEditMaintenanceTypeDialog(
        type: type,
        onSave: (newType) async {
          if (type == null) {
            await context.read<VehicleProvider>().addMaintenanceType(newType);
          } else {
            await context.read<VehicleProvider>().updateMaintenanceType(
              newType,
            );
          }
          _loadTypes();
        },
      ),
    );
  }

  @override
  void dispose() {
    _types.dispose();
    _isLoading.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ModernAppBar(title: 'Maintenance Types'),
      body: AnimatedBuilder(
        animation: Listenable.merge([_isLoading, _types]),
        builder: (context, _) {
          if (_isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_types.value.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.build, size: 64.sp, color: Colors.grey),
                  SizedBox(height: 16.h),
                  Text(
                    'No maintenance types found',
                    style: TextStyle(color: Colors.grey, fontSize: 16.sp),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.all(16.w),
            itemCount: _types.value.length,
            separatorBuilder: (context, index) => SizedBox(height: 12.h),
            itemBuilder: (context, index) {
              final type = _types.value[index];
              return Card(
                child: ListTile(
                  title: Text(
                    type.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                  subtitle: Text(
                    'Interval: ${type.defaultIntervalKm} KM',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14.sp),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: () => _showAddEditDialog(type: type),
                        tooltip: 'Edit',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Delete Maintenance Type'),
                              content: Text(
                                'Are you sure you want to delete \${type.name}?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) _deleteType(type.id);
                        },
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
        heroTag: 'addBtnMaint',
        onPressed: () => _showAddEditDialog(),
        label: const Text('Add Type'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _AddEditMaintenanceTypeDialog extends StatefulWidget {
  final MaintenanceTypeEntity? type;
  final Function(MaintenanceTypeEntity) onSave;

  const _AddEditMaintenanceTypeDialog({this.type, required this.onSave});

  @override
  State<_AddEditMaintenanceTypeDialog> createState() =>
      _AddEditMaintenanceTypeDialogState();
}

class _AddEditMaintenanceTypeDialogState
    extends State<_AddEditMaintenanceTypeDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _intervalController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.type?.name ?? '');
    _intervalController = TextEditingController(
      text: widget.type?.defaultIntervalKm.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final newType = MaintenanceTypeEntity(
      id: widget.type?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      defaultIntervalKm: int.tryParse(_intervalController.text.trim()) ?? 0,
    );

    widget.onSave(newType);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.type == null
                    ? 'Add Maintenance Type'
                    : 'Edit Maintenance Type',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Maintenance Name (e.g. Engine Oil Change)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _intervalController,
                decoration: const InputDecoration(
                  labelText: 'Default Interval (KM) (e.g. 5000)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (int.tryParse(v) == null) return 'Must be a valid number';
                  return null;
                },
              ),
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
