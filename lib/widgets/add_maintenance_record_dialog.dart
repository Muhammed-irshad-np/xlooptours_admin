import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
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
  List<XFile> pickedFiles = [];

  bool isFollowUpRequired = false;
  final TextEditingController followUpReasonController = TextEditingController();
  DateTime? followUpDate;
  final TextEditingController followUpDateController = TextEditingController();
  final TextEditingController followUpKmController = TextEditingController();
  String followUpType = 'one_time'; // 'one_time' or 'recurring'
  final TextEditingController followUpIntervalKmController = TextEditingController();
  final TextEditingController followUpTimesController = TextEditingController();

  void dispose() {
    customTypeController.dispose();
    dateController.dispose();
    serviceKmController.dispose();
    costController.dispose();
    notesController.dispose();
    followUpReasonController.dispose();
    followUpDateController.dispose();
    followUpKmController.dispose();
    followUpIntervalKmController.dispose();
    followUpTimesController.dispose();
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

  Future<void> _selectFollowUpDate(
    BuildContext context,
    _MaintenanceEntry entry,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: entry.followUpDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        entry.followUpDate = picked;
        entry.followUpDateController.text = DateFormat('MMM dd, yyyy').format(picked);
      });
    }
  }

  Future<void> _pickFiles(_MaintenanceEntry entry) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'jpeg', 'pdf'],
        withData: kIsWeb,
      );
      if (result != null) {
        for (final platformFile in result.files) {
          XFile xFile;
          if (kIsWeb && platformFile.bytes != null) {
            xFile = XFile.fromData(
              platformFile.bytes!,
              name: platformFile.name,
            );
          } else if (platformFile.path != null) {
            xFile = XFile(platformFile.path!);
          } else {
            continue;
          }
          setState(() {
            entry.pickedFiles.add(xFile);
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking files: $e');
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

      final List<({String typeId, MaintenanceRecord record})> recordsToAdd = [];

      for (int entryIndex = 0; entryIndex < _entries.length; entryIndex++) {
        final entry = _entries[entryIndex];
        final typeName = _resolveTypeName(entry, provider);

        // Upload picked files sequentially
        final List<String> uploadedUrls = [];
        for (int fileIndex = 0; fileIndex < entry.pickedFiles.length; fileIndex++) {
          final file = entry.pickedFiles[fileIndex];
          // Construct unique docType to prevent collision/overwrite in Firebase Storage
          final docType = 'maintenance_${DateTime.now().millisecondsSinceEpoch}_${entryIndex}_$fileIndex';
          final url = await provider.uploadVehicleDocument(file, widget.vehicle.id, docType);
          uploadedUrls.add(url);
        }

        final primaryUrl = uploadedUrls.isNotEmpty ? uploadedUrls.first : null;

        final int currentOdo = int.tryParse(entry.serviceKmController.text) ?? 0;
        final bool isRecurring = entry.isFollowUpRequired && entry.followUpType == 'recurring';
        final int? intervalKm = isRecurring ? int.tryParse(entry.followUpIntervalKmController.text) : null;
        final int? timesCount = isRecurring ? int.tryParse(entry.followUpTimesController.text) : null;

        recordsToAdd.add((
          typeId: entry.maintenanceTypeId!,
          record: MaintenanceRecord(
            date: entry.date,
            mileage: currentOdo,
            cost: double.tryParse(entry.costController.text),
            serviceProvider: '',
            notes: entry.notesController.text,
            serviceType: typeName,
            attachmentUrl: primaryUrl,
            attachmentUrls: uploadedUrls.isNotEmpty ? uploadedUrls : null,
            isFollowUpRequired: entry.isFollowUpRequired,
            followUpReason: entry.isFollowUpRequired ? entry.followUpReasonController.text.trim() : null,
            nextServiceDate: (entry.isFollowUpRequired && !isRecurring) ? entry.followUpDate : null,
            nextServiceMileage: entry.isFollowUpRequired
                ? (isRecurring
                    ? currentOdo + (intervalKm ?? 0)
                    : int.tryParse(entry.followUpKmController.text))
                : null,
            isFollowUpCompleted: entry.isFollowUpRequired ? false : null,
            followUpIntervalKm: intervalKm,
            followUpTimesCount: timesCount,
            followUpCompletions: entry.isFollowUpRequired ? const [] : null,
          ),
        ));
      }

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
    final normId = typeId.toLowerCase().replaceAll(' ', '_');
    if (normId == 'engine_oil' ||
        normId == 'engine_oil_&_filter' ||
        normId.contains('engine_oil')) {
      return m.copyWith(engineOil: record);
    }
    switch (typeId) {
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

                        // ── Checkbox for Follow-up / Revisit ──
                        SizedBox(height: 12.h),
                        Row(
                          children: [
                            Checkbox(
                              value: entry.isFollowUpRequired,
                              onChanged: (val) {
                                setState(() {
                                  entry.isFollowUpRequired = val ?? false;
                                });
                              },
                            ),
                            Text(
                              'Requires Follow-up / Revisit (Recommended by mechanic/workshop)',
                              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),

                        if (entry.isFollowUpRequired) ...[
                          SizedBox(height: 12.h),
                          Row(
                            children: [
                              SizedBox(width: 8.w),
                              Expanded(
                                child: TextFormField(
                                  controller: entry.followUpReasonController,
                                  decoration: InputDecoration(
                                    labelText: 'Follow-up Reason',
                                    hintText: 'e.g. Recheck brake pads, leak inspection',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                  ),
                                  validator: (v) {
                                    if (entry.isFollowUpRequired && (v == null || v.trim().isEmpty)) {
                                      return 'Reason is required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          Row(
                            children: [
                              SizedBox(width: 8.w),
                              Text(
                                'Schedule Type: ',
                                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                              ),
                              SizedBox(width: 12.w),
                              ChoiceChip(
                                label: const Text('One-Time'),
                                selected: entry.followUpType == 'one_time',
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      entry.followUpType = 'one_time';
                                    });
                                  }
                                },
                              ),
                              SizedBox(width: 8.w),
                              ChoiceChip(
                                label: const Text('Interval / Recurring'),
                                selected: entry.followUpType == 'recurring',
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      entry.followUpType = 'recurring';
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          if (entry.followUpType == 'one_time')
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: TextFormField(
                                    controller: entry.followUpDateController,
                                    readOnly: true,
                                    onTap: () => _selectFollowUpDate(context, entry),
                                    decoration: InputDecoration(
                                      labelText: 'Follow-up Date (Optional)',
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
                                    controller: entry.followUpKmController,
                                    decoration: InputDecoration(
                                      labelText: 'Follow-up Odometer (Optional)',
                                      suffixText: 'km',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8.r),
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (v) {
                                      if (entry.isFollowUpRequired &&
                                          entry.followUpType == 'one_time' &&
                                          (v != null && v.isNotEmpty) &&
                                          int.tryParse(v) == null) {
                                        return 'Invalid number';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            )
                          else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: TextFormField(
                                    controller: entry.followUpIntervalKmController,
                                    decoration: InputDecoration(
                                      labelText: 'Interval Mileage',
                                      suffixText: 'km',
                                      hintText: 'e.g. 5000',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8.r),
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (v) {
                                      if (entry.isFollowUpRequired && entry.followUpType == 'recurring') {
                                        if (v == null || v.isEmpty) return 'Interval mileage is required';
                                        if (int.tryParse(v) == null || int.parse(v) <= 0) return 'Must be > 0';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                SizedBox(width: 16.w),
                                Expanded(
                                  child: TextFormField(
                                    controller: entry.followUpTimesController,
                                    decoration: InputDecoration(
                                      labelText: 'Repeat Times',
                                      hintText: 'e.g. 5',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8.r),
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (v) {
                                      if (entry.isFollowUpRequired && entry.followUpType == 'recurring') {
                                        if (v == null || v.isEmpty) return 'Repeat count is required';
                                        if (int.tryParse(v) == null || int.parse(v) <= 0) return 'Must be > 0';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                        ],

                        // ── File attachments ──
                        SizedBox(height: 12.h),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 8.w),
                            OutlinedButton.icon(
                              onPressed: () => _pickFiles(entry),
                              icon: Icon(Icons.attach_file, size: 18.sp),
                              label: Text(
                                'Attach Receipt/Document',
                                style: TextStyle(fontSize: 13.sp),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.blue.shade300),
                                foregroundColor: Colors.blue.shade700,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 10.h,
                                ),
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: entry.pickedFiles.isEmpty
                                  ? Padding(
                                      padding: EdgeInsets.symmetric(vertical: 8.h),
                                      child: Text(
                                        'No documents attached',
                                        style: TextStyle(
                                          fontSize: 13.sp,
                                          color: Colors.grey[500],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    )
                                  : Wrap(
                                      spacing: 8.w,
                                      runSpacing: 8.h,
                                      children: entry.pickedFiles.asMap().entries.map((fileEntry) {
                                        final fileIdx = fileEntry.key;
                                        final file = fileEntry.value;
                                        return InputChip(
                                          label: Text(
                                            file.name,
                                            style: TextStyle(fontSize: 12.sp),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          onDeleted: () {
                                            setState(() {
                                              entry.pickedFiles.removeAt(fileIdx);
                                            });
                                          },
                                          deleteIconColor: Colors.red[700],
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20.r),
                                            side: BorderSide(color: Colors.grey.shade300),
                                          ),
                                          backgroundColor: Colors.blue.withValues(alpha: 0.05),
                                        );
                                      }).toList(),
                                    ),
                            ),
                          ],
                        ),
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
