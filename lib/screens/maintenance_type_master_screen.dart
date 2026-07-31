import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';

import '../features/vehicle/domain/entities/maintenance_type_entity.dart';
import '../features/vehicle/presentation/providers/vehicle_provider.dart';
import '../core/widgets/modern_app_bar.dart';
import '../core/widgets/skeleton_loader.dart';

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
      debugPrint('Error loading maintenance types: $e');
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
        ).showSnackBar(SnackBar(content: Text('Error deleting type: $e')));
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
            return const SkeletonListView(itemCount: 5);
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
                    type.isDateTrigger
                        ? 'Trigger: Date  |  Alert: ${type.notificationDays ?? 7} days before due date'
                        : 'Trigger: Odometer  |  SUV: ${type.suvIntervalKm} KM  |  Sedan: ${type.sedanIntervalKm} KM',
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
                                'Are you sure you want to delete ${type.name}?',
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
  late TextEditingController _suvIntervalController;
  late TextEditingController _sedanIntervalController;
  late TextEditingController _notificationDaysController;

  late String _triggerType;

  @override
  void initState() {
    super.initState();
    _triggerType = widget.type?.triggerType ?? 'odometer';
    _nameController = TextEditingController(text: widget.type?.name ?? '');
    _suvIntervalController = TextEditingController(
      text: widget.type?.suvIntervalKm.toString() ?? '5000',
    );
    _sedanIntervalController = TextEditingController(
      text: widget.type?.sedanIntervalKm.toString() ?? '5000',
    );
    _notificationDaysController = TextEditingController(
      text: (widget.type?.notificationDays ?? 7).toString(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _suvIntervalController.dispose();
    _sedanIntervalController.dispose();
    _notificationDaysController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final isDate = _triggerType == 'date';

    final newType = MaintenanceTypeEntity(
      id: widget.type?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      triggerType: _triggerType,
      suvIntervalKm: isDate
          ? 0
          : (int.tryParse(_suvIntervalController.text.trim()) ?? 0),
      sedanIntervalKm: isDate
          ? 0
          : (int.tryParse(_sedanIntervalController.text.trim()) ?? 0),
      notificationDays: isDate
          ? (int.tryParse(_notificationDaysController.text.trim()) ?? 7)
          : null,
    );

    widget.onSave(newType);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDateTrigger = _triggerType == 'date';

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
                widget.type == null
                    ? 'Add Maintenance Type'
                    : 'Edit Maintenance Type',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Maintenance Name (e.g. Engine Oil Change)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              // --- Trigger Type Selection ---
              const Text(
                'Trigger Type',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(
                        child: Text('Odometer (KM)'),
                      ),
                      selected: _triggerType == 'odometer',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _triggerType = 'odometer';
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(
                        child: Text('Date'),
                      ),
                      selected: _triggerType == 'date',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _triggerType = 'date';
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (!isDateTrigger) ...[
                // --- ODOMETER INPUTS ---
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _suvIntervalController,
                        decoration: const InputDecoration(
                          labelText: 'SUV Interval (KM)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) {
                          if (_triggerType == 'odometer') {
                            if (v == null || v.isEmpty) return 'Required';
                            if (int.tryParse(v) == null) return 'Invalid number';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _sedanIntervalController,
                        decoration: const InputDecoration(
                          labelText: 'Sedan Interval (KM)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) {
                          if (_triggerType == 'odometer') {
                            if (v == null || v.isEmpty) return 'Required';
                            if (int.tryParse(v) == null) return 'Invalid number';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // --- DATE TRIGGER INPUTS ---
                TextFormField(
                  controller: _notificationDaysController,
                  decoration: const InputDecoration(
                    labelText: 'Alert Interval (Days Before Due Date)',
                    hintText: 'e.g. 7',
                    suffixText: 'days',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (_triggerType == 'date') {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (int.tryParse(v.trim()) == null) return 'Invalid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Alerts will be triggered automatically N days before the due date set on the maintenance record.',
                          style: TextStyle(fontSize: 13, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
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
