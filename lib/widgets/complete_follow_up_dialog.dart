import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import '../features/vehicle/domain/entities/vehicle_entity.dart';
import '../features/vehicle/domain/entities/vehicle_documents.dart';
import '../features/vehicle/presentation/providers/vehicle_provider.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/notifications/presentation/providers/notification_provider.dart';
import '../features/employee/presentation/providers/employee_provider.dart';
import '../features/xloop_vault/presentation/providers/vault_provider.dart';
import 'package:xloop_invoice/core/utils/activity_logger.dart';

class CompleteFollowUpDialog extends StatefulWidget {
  final VehicleEntity vehicle;
  final MaintenanceRecord record;

  const CompleteFollowUpDialog({
    super.key,
    required this.vehicle,
    required this.record,
  });

  @override
  State<CompleteFollowUpDialog> createState() => _CompleteFollowUpDialogState();
}

class _CompleteFollowUpDialogState extends State<CompleteFollowUpDialog> {
  final _formKey = GlobalKey<FormState>();
  DateTime _selectedDate = DateTime.now();
  late final TextEditingController _dateController;
  late final TextEditingController _odometerController;
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final List<XFile> _pickedFiles = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(
      text: DateFormat('MMM dd, yyyy').format(_selectedDate),
    );
    // Pre-fill with the expected odometer reading or current vehicle odometer
    final expectedMileage = widget.record.nextServiceMileage ?? widget.vehicle.currentOdometer ?? 0;
    _odometerController = TextEditingController(
      text: expectedMileage.toString(),
    );
  }

  @override
  void dispose() {
    _dateController.dispose();
    _odometerController.dispose();
    _costController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('MMM dd, yyyy').format(picked);
      });
    }
  }

  Future<void> _pickFiles() async {
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
            _pickedFiles.add(xFile);
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking files: $e');
    }
  }

  VehicleMaintenance _updateMatchingTypedRecord(
    VehicleMaintenance m,
    MaintenanceRecord oldRecord,
    MaintenanceRecord newRecord,
  ) {
    return m.copyWith(
      engineOil: m.engineOil == oldRecord ? newRecord : m.engineOil,
      gearOil: m.gearOil == oldRecord ? newRecord : m.gearOil,
      housingOil: m.housingOil == oldRecord ? newRecord : m.housingOil,
      tyreChange: m.tyreChange == oldRecord ? newRecord : m.tyreChange,
      batteryChange: m.batteryChange == oldRecord ? newRecord : m.batteryChange,
      brakePads: m.brakePads == oldRecord ? newRecord : m.brakePads,
      airFilter: m.airFilter == oldRecord ? newRecord : m.airFilter,
      acService: m.acService == oldRecord ? newRecord : m.acService,
      wheelAlignment: m.wheelAlignment == oldRecord ? newRecord : m.wheelAlignment,
      sparkPlugs: m.sparkPlugs == oldRecord ? newRecord : m.sparkPlugs,
      coolantFlush: m.coolantFlush == oldRecord ? newRecord : m.coolantFlush,
      wiperBlades: m.wiperBlades == oldRecord ? newRecord : m.wiperBlades,
      timingBelt: m.timingBelt == oldRecord ? newRecord : m.timingBelt,
      transmissionFluid: m.transmissionFluid == oldRecord ? newRecord : m.transmissionFluid,
      brakeFluid: m.brakeFluid == oldRecord ? newRecord : m.brakeFluid,
      fuelFilter: m.fuelFilter == oldRecord ? newRecord : m.fuelFilter,
    );
  }

  Future<void> _saveCompletion() async {
    if (!_formKey.currentState!.validate()) return;

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final notifProvider = context.read<NotificationProvider>();
    final provider = context.read<VehicleProvider>();
    final authProvider = context.read<AuthProvider>();

    final user = authProvider.user;
    final email = user?.email;
    final username = (user?.displayName != null && user!.displayName!.isNotEmpty)
        ? user.displayName
        : (email != null && email.contains('@')
            ? email.split('@').first
            : (email ?? 'System'));

    setState(() {
      _isSaving = true;
    });

    try {

      // Upload files
      final List<String> uploadedUrls = [];
      for (int i = 0; i < _pickedFiles.length; i++) {
        final file = _pickedFiles[i];
        final docType = 'followup_completion_${DateTime.now().millisecondsSinceEpoch}_$i';
        final url = await provider.uploadVehicleDocument(file, widget.vehicle.id, docType);
        uploadedUrls.add(url);
      }

      final completion = FollowUpCompletion(
        date: _selectedDate,
        mileage: int.parse(_odometerController.text),
        cost: double.tryParse(_costController.text) ?? 0.0,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        attachmentUrl: uploadedUrls.isNotEmpty ? uploadedUrls.first : null,
        attachmentUrls: uploadedUrls.isNotEmpty ? uploadedUrls : null,
        performedBy: username,
      );

      final existingCompletions = List<FollowUpCompletion>.from(widget.record.followUpCompletions ?? []);
      existingCompletions.add(completion);

      final int? totalCount = widget.record.followUpTimesCount;
      final bool isFullyCompleted = totalCount == null || existingCompletions.length >= totalCount;

      int? nextMileage;
      if (!isFullyCompleted && widget.record.followUpIntervalKm != null) {
        nextMileage = completion.mileage + widget.record.followUpIntervalKm!;
      }

      final updatedRecord = widget.record.copyWith(
        followUpCompletions: existingCompletions,
        isFollowUpCompleted: isFullyCompleted,
        nextServiceMileage: nextMileage,
      );

      final List<MaintenanceRecord> updatedHistory = (widget.vehicle.maintenanceHistory ?? []).map((r) {
        if (r == widget.record) {
          return updatedRecord;
        }
        return r;
      }).toList();

      final existingMaintenance = widget.vehicle.maintenance ?? const VehicleMaintenance();
      final updatedMaintenance = _updateMatchingTypedRecord(existingMaintenance, widget.record, updatedRecord);

      int currentOdometer = widget.vehicle.currentOdometer ?? 0;
      final newOdometer = int.parse(_odometerController.text);
      if (newOdometer > currentOdometer) {
        currentOdometer = newOdometer;
      }

      final updatedVehicle = widget.vehicle.copyWith(
        maintenanceHistory: updatedHistory,
        maintenance: updatedMaintenance,
        currentOdometer: currentOdometer,
        lastOdometerUpdateDate: newOdometer > (widget.vehicle.currentOdometer ?? 0)
            ? DateTime.now()
            : widget.vehicle.lastOdometerUpdateDate,
      );

      await provider.updateVehicle(updatedVehicle);

      if (mounted) {
        await ActivityLogger.log(
          context,
          title: 'Follow-up Completed',
          message: 'Follow-up maintenance (${widget.record.serviceType}) completed for vehicle ${widget.vehicle.make} ${widget.vehicle.model} (${widget.vehicle.plateNumber}). Cost: SAR ${completion.cost.toStringAsFixed(2)}, Odometer: ${completion.mileage} km.',
          relatedId: widget.vehicle.id,
        );
      }

      // Mark the corresponding virtual notification as read and refresh alerts
      final notifId = 'followup_${widget.vehicle.id}_${widget.record.date.millisecondsSinceEpoch}';
      await notifProvider.markAsRead(notifId);
      
      if (mounted) {
        final employeeProvider = context.read<EmployeeProvider>();
        final vaultProvider = context.read<VaultProvider>();
        await notifProvider.refreshAlerts(
          vehicles: provider.vehicles,
          maintenanceTypes: provider.maintenanceTypes,
          employees: employeeProvider.employees,
          employeeSettings: employeeProvider.settings,
          vehicleSettings: provider.settings,
          vaultData: vaultProvider.vaultData,
        );
      }

      if (mounted) {
        navigator.pop(true);
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Follow-up completion logged successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save completion: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final completionsCount = widget.record.followUpCompletions?.length ?? 0;
    final totalCount = widget.record.followUpTimesCount ?? 1;
    final visitIndexStr = '${completionsCount + 1} of $totalCount';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        width: 500.w,
        padding: EdgeInsets.all(24.w),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Complete Follow-up (${widget.record.serviceType})',
                style: GoogleFonts.inter(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.blue[800]),
              ),
              SizedBox(height: 4.h),
              Text(
                (widget.record.followUpTimesCount != null && widget.record.followUpIntervalKm != null) 
                    ? 'Logging Visit $visitIndexStr • ${widget.record.followUpReason ?? 'General Follow-up'}'
                    : widget.record.followUpReason ?? 'General Follow-up',
                style: GoogleFonts.inter(fontSize: 13.sp, color: Colors.grey[600]),
              ),
              SizedBox(height: 20.h),
              TextFormField(
                controller: _dateController,
                readOnly: true,
                onTap: () => _selectDate(context),
                decoration: InputDecoration(
                  labelText: 'Completion Date',
                  suffixIcon: const Icon(Icons.calendar_today),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _odometerController,
                decoration: InputDecoration(
                  labelText: 'Odometer Reading',
                  suffixText: 'km',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (int.tryParse(v) == null) return 'Invalid odometer';
                  return null;
                },
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _costController,
                decoration: InputDecoration(
                  labelText: 'Cost (Optional)',
                  prefixText: 'SAR ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'Notes/Details',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                maxLines: 2,
              ),
              SizedBox(height: 16.h),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickFiles,
                    icon: Icon(Icons.attach_file, size: 18.sp),
                    label: Text(
                      'Attach Receipts',
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
                    child: _pickedFiles.isEmpty
                        ? Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.h),
                            child: Text(
                              'No receipts attached',
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
                            children: _pickedFiles.asMap().entries.map((fileEntry) {
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
                                    _pickedFiles.removeAt(fileIdx);
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
              SizedBox(height: 24.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  SizedBox(width: 16.w),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveCompletion,
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
                        : const Text('Save Completion'),
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
