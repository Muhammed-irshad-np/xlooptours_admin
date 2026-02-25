import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../features/vehicle/domain/entities/vehicle_make_entity.dart';
import '../features/vehicle/presentation/providers/vehicle_provider.dart';

class VehicleMasterScreen extends StatefulWidget {
  const VehicleMasterScreen({super.key});

  @override
  State<VehicleMasterScreen> createState() => _VehicleMasterScreenState();
}

class _VehicleMasterScreenState extends State<VehicleMasterScreen> {
  final ValueNotifier<List<VehicleMakeEntity>> _makes = ValueNotifier([]);
  final ValueNotifier<bool> _isLoading = ValueNotifier(true);

  @override
  void initState() {
    super.initState();
    _loadMakes();
  }

  Future<void> _loadMakes() async {
    _isLoading.value = true;
    try {
      if (mounted) {
        await context.read<VehicleProvider>().fetchAllVehicleMakes();
        if (!mounted) return;
        _makes.value = context.read<VehicleProvider>().vehicleMakes;
        _isLoading.value = false;
      }
    } catch (e) {
      debugPrint('Error loading vehicle makes: $e');
      if (mounted) {
        _isLoading.value = false;
      }
    }
  }

  Future<void> _deleteMake(String id) async {
    try {
      if (mounted) {
        await context.read<VehicleProvider>().deleteVehicleMake(id);
        _loadMakes();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting make: $e')));
      }
    }
  }

  void _showAddEditDialog({VehicleMakeEntity? make}) {
    showDialog(
      context: context,
      builder: (context) => _AddEditMakeDialog(
        make: make,
        onSave: (newMake) async {
          if (make == null) {
            await context.read<VehicleProvider>().addVehicleMake(newMake);
          } else {
            await context.read<VehicleProvider>().updateVehicleMake(newMake);
          }
          _loadMakes();
        },
      ),
    );
  }

  @override
  void dispose() {
    _makes.dispose();
    _isLoading.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_isLoading, _makes]),
        builder: (context, _) {
          return _isLoading.value
              ? const Center(child: CircularProgressIndicator())
              : _makes.value.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.category_outlined,
                        size: 64.sp,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        'No vehicle makes found',
                        style: TextStyle(color: Colors.grey, fontSize: 16.sp),
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _showAddEditDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Make'),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.all(16.w),
                  itemCount: _makes.value.length,
                  separatorBuilder: (context, index) => SizedBox(height: 12.h),
                  itemBuilder: (context, index) {
                    final make = _makes.value[index];
                    return Card(
                      child: ListTile(
                        leading: Container(
                          width: 50.w,
                          height: 50.w,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: ClipOval(
                            child:
                                make.logoUrl != null && make.logoUrl!.isNotEmpty
                                ? Image.network(
                                    make.logoUrl!,
                                    fit: BoxFit.contain,
                                    errorBuilder: (c, o, s) => Center(
                                      child: Text(
                                        make.name.isNotEmpty
                                            ? make.name[0].toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                          fontSize: 20.sp,
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      make.name.isNotEmpty
                                          ? make.name[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                        fontSize: 20.sp,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        title: Text(
                          make.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16.sp,
                          ),
                        ),
                        subtitle: Text(
                          '${make.models.length} Models • ${make.years.length} Years • ${make.colors.length} Colors',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.visibility,
                                color: Colors.blue,
                              ),
                              onPressed: () => _showMakeDetails(make),
                              tooltip: 'View Details',
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.orange,
                              ),
                              onPressed: () => _showAddEditDialog(make: make),
                              tooltip: 'Edit',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    title: const Text('Delete Make'),
                                    content: Text(
                                      'Are you sure you want to delete ${make.name}?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(c, false),
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
                                if (confirm == true) _deleteMake(make.id);
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
        heroTag: 'addBtn',
        onPressed: () => _showAddEditDialog(),
        label: const Text('Add Make'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  void _showMakeDetails(VehicleMakeEntity make) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500.w,
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  if (make.logoUrl != null && make.logoUrl!.isNotEmpty)
                    Container(
                      width: 60.r,
                      height: 60.r,
                      margin: EdgeInsets.only(right: 16.w),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: NetworkImage(make.logoUrl!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  Text(
                    make.name,
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Divider(height: 32.h),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Models Section
                      Text(
                        'Models',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: make.models.map((m) {
                          return Chip(
                            label: Text('${m.name} (${m.type})'),
                            backgroundColor: Colors.blue.withValues(alpha: 0.1),
                            side: BorderSide.none,
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 24.h),

                      // Years Section
                      Text(
                        'Years',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: make.years.map((y) {
                          return Chip(
                            label: Text(y.toString()),
                            backgroundColor: Colors.green.withValues(
                              alpha: 0.1,
                            ),
                            side: BorderSide.none,
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 24.h),

                      // Colors Section
                      Text(
                        'Colors',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: make.colors.map((c) {
                          return Chip(
                            avatar: CircleAvatar(
                              backgroundColor: _getColorObject(c),
                              radius: 8.r,
                            ),
                            label: Text(c),
                            backgroundColor: Colors.purple.withValues(
                              alpha: 0.1,
                            ),
                            side: BorderSide.none,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getColorObject(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'white':
        return Colors.white;
      case 'black':
        return Colors.black;
      case 'silver':
        return Colors.grey.shade300;
      case 'grey':
        return Colors.grey;
      case 'red':
        return Colors.red;
      case 'blue':
        return Colors.blue;
      case 'brown':
        return Colors.brown;
      case 'golden':
        return const Color(0xFFFFD700);
      default:
        return Colors.grey;
    }
  }
}

class _AddEditMakeDialog extends StatefulWidget {
  final VehicleMakeEntity? make;
  final Function(VehicleMakeEntity) onSave;

  const _AddEditMakeDialog({this.make, required this.onSave});

  @override
  State<_AddEditMakeDialog> createState() => _AddEditMakeDialogState();
}

class _AddEditMakeDialogState extends State<_AddEditMakeDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _logoUrlController;
  late final ValueNotifier<List<VehicleModelDetailEntity>> _models;
  late final ValueNotifier<List<int>> _years;
  late final ValueNotifier<List<String>> _colors;

  final _modelController = TextEditingController();
  final _modelTypeController = TextEditingController(); // Added
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.make?.name ?? '');
    _logoUrlController = TextEditingController(
      text: widget.make?.logoUrl ?? '',
    );
    // Deep copy models
    // Deep copy models
    _models = ValueNotifier(
      widget.make?.models
              .map((m) => VehicleModelDetailEntity(name: m.name, type: m.type))
              .toList() ??
          [],
    );
    _years = ValueNotifier(List.from(widget.make?.years ?? []));
    _colors = ValueNotifier(List.from(widget.make?.colors ?? []));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _logoUrlController.dispose();
    _modelController.dispose();
    _modelTypeController.dispose(); // Added
    _yearController.dispose();
    _colorController.dispose();
    _models.dispose();
    _years.dispose();
    _colors.dispose();
    super.dispose();
  }

  void _addModel() {
    final name = _modelController.text.trim();
    final type = _modelTypeController.text.trim();

    if (name.isNotEmpty) {
      final exists = _models.value.any(
        (m) => m.name.toLowerCase() == name.toLowerCase(),
      );
      if (!exists) {
        final current = List<VehicleModelDetailEntity>.from(_models.value);
        current.add(
          VehicleModelDetailEntity(
            name: name,
            type: type.isNotEmpty ? type : 'Sedan', // Default if empty
          ),
        );
        _models.value = current;
        _modelController.clear();
        _modelTypeController.clear();
      }
    }
  }

  void _addYear() {
    final val = int.tryParse(_yearController.text.trim());
    if (val != null && !_years.value.contains(val)) {
      final current = List<int>.from(_years.value);
      current.add(val);
      current.sort(); // Keep sorted
      _years.value = current;
      _yearController.clear();
    }
  }

  void _addColor() {
    final val = _colorController.text.trim();
    if (val.isNotEmpty && !_colors.value.contains(val)) {
      final current = List<String>.from(_colors.value);
      current.add(val);
      _colors.value = current;
      _colorController.clear();
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final newMake = VehicleMakeEntity(
      id: widget.make?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      logoUrl: _logoUrlController.text.trim().isEmpty
          ? null
          : _logoUrlController.text.trim(),
      models: _models.value,
      years: _years.value,
      colors: _colors.value,
    );

    widget.onSave(newMake);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.make == null ? 'Add Vehicle Make' : 'Edit Vehicle Make',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Make Name (e.g. Toyota)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _logoUrlController,
                decoration: const InputDecoration(
                  labelText: 'Logo URL (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.image),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Models Column
                    Expanded(
                      flex: 2, // Give more space to models
                      child:
                          ValueListenableBuilder<
                            List<VehicleModelDetailEntity>
                          >(
                            valueListenable: _models,
                            builder: (context, models, _) {
                              return _buildModelSection(models);
                            },
                          ),
                    ),
                    const SizedBox(width: 16),
                    // Years Column
                    Expanded(
                      child: ValueListenableBuilder<List<int>>(
                        valueListenable: _years,
                        builder: (context, years, _) {
                          return _buildListSection(
                            title: 'Years',
                            controller: _yearController,
                            items: years.map((e) => e.toString()).toList(),
                            onAdd: _addYear,
                            onRemove: (i) {
                              final current = List<int>.from(_years.value);
                              current.removeAt(i);
                              _years.value = current;
                            },
                            hint: 'Year',
                            isNumber: true,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Colors Column
                    Expanded(
                      child: ValueListenableBuilder<List<String>>(
                        valueListenable: _colors,
                        builder: (context, colors, _) {
                          return _buildListSection(
                            title: 'Colors',
                            controller: _colorController,
                            items: colors,
                            onAdd: _addColor,
                            onRemove: (i) {
                              final current = List<String>.from(_colors.value);
                              current.removeAt(i);
                              _colors.value = current;
                            },
                            hint: 'Color',
                          );
                        },
                      ),
                    ),
                  ],
                ),
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

  Widget _buildListSection({
    required String title,
    required TextEditingController controller,
    required List<String> items,
    required VoidCallback onAdd,
    required Function(int) onRemove,
    required String hint,
    bool isNumber = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: isNumber
                      ? TextInputType.number
                      : TextInputType.text,
                  decoration: InputDecoration(
                    hintText: hint,
                    isDense: true,
                    contentPadding: const EdgeInsets.all(8),
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => onAdd(),
                ),
              ),
              IconButton(
                onPressed: onAdd,
                icon: const Icon(Icons.add_circle, color: Colors.blue),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      Expanded(child: Text(items[index])),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.grey,
                        ),
                        onPressed: () => onRemove(index),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelSection(List<VehicleModelDetailEntity> modelsList) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Models', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Column(
            children: [
              TextField(
                controller: _modelController,
                decoration: const InputDecoration(
                  hintText: 'Model Name',
                  isDense: true,
                  contentPadding: EdgeInsets.all(8),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _modelTypeController,
                      decoration: const InputDecoration(
                        hintText: 'Type (e.g. SUV)',
                        isDense: true,
                        contentPadding: EdgeInsets.all(8),
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _addModel(),
                    ),
                  ),
                  IconButton(
                    onPressed: _addModel,
                    icon: const Icon(Icons.add_circle, color: Colors.blue),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: modelsList.length,
              itemBuilder: (context, index) {
                final model = modelsList[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: Text(
                      model.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      model.type,
                      style: TextStyle(fontSize: 10.sp, color: Colors.grey),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        final current = List<VehicleModelDetailEntity>.from(
                          _models.value,
                        );
                        current.removeAt(index);
                        _models.value = current;
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
