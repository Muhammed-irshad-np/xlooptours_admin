import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../features/vehicle/domain/entities/vehicle_entity.dart';
import '../features/vehicle/domain/entities/vehicle_documents.dart';
import '../features/vehicle/presentation/providers/vehicle_provider.dart';

/// Special sentinel IDs for built-in extras that are not part of the
/// Firestore-managed maintenance-type master list.
const String _kCarWashId = '__car_wash__';
const String _kOtherId = '__other__';

class _MaintenanceEntry {
  String? maintenanceTypeId;

  /// When [maintenanceTypeId] == [_kOtherId], the user must fill in a custom
  /// name via this controller.
  final TextEditingController customTypeController = TextEditingController();

  DateTime date = DateTime.now();
  final TextEditingController dateController = TextEditingController(
    text: DateFormat('MMM dd, yyyy').format(DateTime.now()),
  );
  final TextEditingController serviceKmController = TextEditingController();
  final TextEditingController costController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  void dispose() {
    customTypeController.dispose();
    dateController.dispose();
    serviceKmController.dispose();
    costController.dispose();
    notesController.dispose();
  }
}

class AddMaintenanceRecordDialog extends StatefulWidget {
  final VehicleEntity vehicle;
  final String? initialMaintenanceTypeId;

  const AddMaintenanceRecordDialog({
    super.key,
    required this.vehicle,
    this.initialMaintenanceTypeId,
  });

  @override
  State<AddMaintenanceRecordDialog> createState() =>
      _AddMaintenanceRecordDialogState();
}

class _AddMaintenanceRecordDialogState
    extends State<AddMaintenanceRecordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final List<_MaintenanceEntry> _entries;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _entries = [
      _MaintenanceEntry()..maintenanceTypeId = widget.initialMaintenanceTypeId,
    ];
  }

  @override
  void dispose() {
    for (var entry in _entries) {
      entry.dispose();
    }
    super.dispose();
  }

  void _addEntry() {
    setState(() {
      _entries.add(_MaintenanceEntry());
    });
  }

  void _removeEntry(int index) {
    setState(() {
      _entries[index].dispose();
      _entries.removeAt(index);
    });
  }

  Future<void> _selectDate(
    BuildContext context,
    _MaintenanceEntry entry,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: entry.date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != entry.date) {
      setState(() {
        entry.date = picked;
        entry.dateController.text = DateFormat('MMM dd, yyyy').format(picked);
      });
    }
  }

  /// Resolves the human-readable service-type name for a given entry.
  String _resolveTypeName(_MaintenanceEntry entry, VehicleProvider provider) {
    if (entry.maintenanceTypeId == _kCarWashId) return 'Car Wash';
    if (entry.maintenanceTypeId == _kOtherId) {
      return entry.customTypeController.text.trim();
    }
    // Lookup from master list
    final type = provider.maintenanceTypes.firstWhere(
      (t) => t.id == entry.maintenanceTypeId,
      orElse: () => throw StateError('Type not found'),
    );
    return type.name;
  }

  Future<void> _saveRecords() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate type selection
    for (final entry in _entries) {
      if (entry.maintenanceTypeId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a maintenance type for all entries.'),
          ),
        );
        return;
      }
      if (entry.maintenanceTypeId == _kOtherId &&
          entry.customTypeController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a name for the custom maintenance type.'),
          ),
        );
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final provider = context.read<VehicleProvider>();

      final recordsToAdd = _entries.map((entry) {
        final typeName = _resolveTypeName(entry, provider);

        return (
          typeId: entry.maintenanceTypeId!,
          record: MaintenanceRecord(
            date: entry.date,
            mileage: int.tryParse(entry.serviceKmController.text) ?? 0,
            cost: double.tryParse(entry.costController.text),
            serviceProvider: '',
            notes: entry.notesController.text,
            serviceType: typeName,
          ),
        );
      }).toList();

      // Append to flat history list
      final List<MaintenanceRecord> updatedHistory = List.from(
        widget.vehicle.maintenanceHistory ?? [],
      );
      for (final e in recordsToAdd) {
        updatedHistory.add(e.record);
      }

      // Also update the typed VehicleMaintenance fields so the alert checker
      // (GetVehicleMaintenanceAlertsUseCase) can find the latest service record.
      final existing = widget.vehicle.maintenance ?? const VehicleMaintenance();
      VehicleMaintenance updatedMaintenance = existing;
      for (final e in recordsToAdd) {
        updatedMaintenance = _applyTypedRecord(
          updatedMaintenance,
          e.typeId,
          e.record,
        );
      }

      final updatedVehicle = widget.vehicle.copyWith(
        maintenanceHistory: updatedHistory,
        maintenance: updatedMaintenance,
      );

      await provider.updateVehicle(updatedVehicle);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maintenance record(s) added successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save records: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// Maps a [typeId] to the correct named field on [VehicleMaintenance].
  VehicleMaintenance _applyTypedRecord(
    VehicleMaintenance m,
    String typeId,
    MaintenanceRecord record,
  ) {
    switch (typeId) {
      case 'engine_oil':
        return m.copyWith(engineOil: record);
      case 'gear_oil':
        return m.copyWith(gearOil: record);
      case 'housing_oil':
        return m.copyWith(housingOil: record);
      case 'tyre_change':
        return m.copyWith(tyreChange: record);
      case 'battery_change':
        return m.copyWith(batteryChange: record);
      case 'brake_pads':
        return m.copyWith(brakePads: record);
      case 'air_filter':
        return m.copyWith(airFilter: record);
      case 'ac_service':
        return m.copyWith(acService: record);
      case 'wheel_alignment':
        return m.copyWith(wheelAlignment: record);
      case 'spark_plugs':
        return m.copyWith(sparkPlugs: record);
      case 'coolant_flush':
        return m.copyWith(coolantFlush: record);
      case 'wiper_blades':
        return m.copyWith(wiperBlades: record);
      case 'timing_belt':
        return m.copyWith(timingBelt: record);
      case 'transmission_fluid':
        return m.copyWith(transmissionFluid: record);
      case 'brake_fluid':
        return m.copyWith(brakeFluid: record);
      case 'fuel_filter':
        return m.copyWith(fuelFilter: record);
      default:
        // Car Wash, Other, or any future ad-hoc types — only stored in flat
        // history, no typed field to update.
        return m;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VehicleProvider>();
    final types = provider.maintenanceTypes;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        width: 800.w, // Match screen size constraint or constraints
        padding: EdgeInsets.all(24.w),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Maintenance Record',
                style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8.h),
              Text(
                '${widget.vehicle.make} ${widget.vehicle.model} - ${widget.vehicle.plateNumber}',
                style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
              ),
              SizedBox(height: 24.h),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _entries.length,
                  separatorBuilder: (context, index) => Divider(height: 32.h),
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    final isOther = entry.maintenanceTypeId == _kOtherId;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ---------- Maintenance Type dropdown ----------
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                              initialValue: entry.maintenanceTypeId,
                                decoration: InputDecoration(
                                  labelText: 'Maintenance Type',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                ),
                                isExpanded: true,
                                items: [
                                  // ── Master types from Firestore ──
                                  ...types.map((t) {
                                    return DropdownMenuItem(
                                      value: t.id,
                                      child: Text(t.name),
                                    );
                                  }),
                                  // ── Visual separator ──
                                  if (types.isNotEmpty)
                                    DropdownMenuItem<String>(
                                      enabled: false,
                                      value: null,
                                      child: Divider(
                                        height: 1,
                                        color: Colors.grey[300],
                                      ),
                                    ),
                                  // ── Car Wash (built-in) ──
                                  DropdownMenuItem(
                                    value: _kCarWashId,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.local_car_wash_outlined,
                                          size: 18.sp,
                                          color: Colors.blue,
                                        ),
                                        SizedBox(width: 8.w),
                                        const Text('Car Wash'),
                                      ],
                                    ),
                                  ),
                                  // ── Other (custom) ──
                                  DropdownMenuItem(
                                    value: _kOtherId,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.edit_note_outlined,
                                          size: 18.sp,
                                          color: Colors.deepPurple,
                                        ),
                                        SizedBox(width: 8.w),
                                        const Text('Other (Custom)'),
                                      ],
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    entry.maintenanceTypeId = value;
                                    // Clear custom text when switching away
                                    if (value != _kOtherId) {
                                      entry.customTypeController.clear();
                                    }
                                  });
                                },
                                validator: (v) => v == null ? 'Required' : null,
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: TextFormField(
                                controller: entry.dateController,
                                readOnly: true,
                                onTap: () => _selectDate(context, entry),
                                decoration: InputDecoration(
                                  labelText: 'Date',
                                  suffixIcon: const Icon(Icons.calendar_today),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: TextFormField(
                                controller: entry.serviceKmController,
                                decoration: InputDecoration(
                                  labelText: 'Current Odometer',
                                  suffixText: 'km',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Required';
                                  if (int.tryParse(v) == null) return 'Invalid';
                                  return null;
                                },
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: TextFormField(
                                controller: entry.costController,
                                decoration: InputDecoration(
                                  labelText: 'Cost (Optional)',
                                  prefixText: '\$ ',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                ),
                                keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: TextFormField(
                                controller: entry.notesController,
                                decoration: InputDecoration(
                                  labelText: 'Notes',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                ),
                              ),
                            ),
                            if (_entries.length > 1)
                              Padding(
                                padding: EdgeInsets.only(left: 8.w, top: 4.h),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _removeEntry(index),
                                ),
                              ),
                          ],
                        ),

                        // ── "Other" custom type text field ──
                        if (isOther) ...[
                          SizedBox(height: 12.h),
                          Row(
                            children: [
                              SizedBox(width: 8.w),
                              Icon(
                                Icons.subdirectory_arrow_right_rounded,
                                size: 20.sp,
                                color: Colors.deepPurple[300],
                              ),
                              SizedBox(width: 8.w),
                              SizedBox(
                                width: 320.w,
                                child: TextFormField(
                                  controller: entry.customTypeController,
                                  autofocus: true,
                                  decoration: InputDecoration(
                                    labelText: 'Enter maintenance type name',
                                    hintText: 'e.g. Windshield Replacement',
                                    prefixIcon: Icon(
                                      Icons.label_outline,
                                      size: 18.sp,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                    filled: true,
                                    fillColor:
                                        Colors.deepPurple.withValues(alpha: 0.03),
                                  ),
                                  textCapitalization:
                                      TextCapitalization.words,
                                  validator: (v) {
                                    if (entry.maintenanceTypeId == _kOtherId &&
                                        (v == null || v.trim().isEmpty)) {
                                      return 'Please enter a type name';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
              SizedBox(height: 16.h),
              TextButton.icon(
                onPressed: _addEntry,
                icon: const Icon(Icons.add),
                label: const Text('Add Another Entry'),
              ),
              SizedBox(height: 24.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  SizedBox(width: 16.w),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveRecords,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24.w,
                        vertical: 12.h,
                      ),
                    ),
                    child: _isSaving
                        ? SizedBox(
                            width: 20.w,
                            height: 20.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Save Records'),
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
