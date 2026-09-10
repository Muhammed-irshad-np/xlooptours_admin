import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:xloop_invoice/core/utils/app_snack_bar.dart';
import 'package:xloop_invoice/features/auth/presentation/providers/auth_provider.dart';
import 'package:xloop_invoice/features/finance/presentation/providers/finance_provider.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_entity.dart';
import 'package:xloop_invoice/features/vehicle/presentation/providers/vehicle_provider.dart';

import '../../domain/entities/work_order_entity.dart';
import '../../domain/entities/work_order_status.dart';
import '../providers/work_order_provider.dart';

/// The fleet manager's (and driver's) entry point: two fields and a photo.
///
/// Deliberately minimal — the person noticing a fault should not have to
/// know what it will cost, which workshop will do it or which wallet pays.
/// A coordinator picks it up from the board and costs it.
class ReportIssueDialog extends StatefulWidget {
  /// Pre-selected vehicle — set when opened from a vehicle's own screen.
  final VehicleEntity? vehicle;

  const ReportIssueDialog({super.key, this.vehicle});

  static Future<WorkOrderEntity?> show(
    BuildContext context, {
    VehicleEntity? vehicle,
  }) {
    return showDialog<WorkOrderEntity>(
      context: context,
      builder: (_) => ReportIssueDialog(vehicle: vehicle),
    );
  }

  @override
  State<ReportIssueDialog> createState() => _ReportIssueDialogState();
}

class _ReportIssueDialogState extends State<ReportIssueDialog> {
  final _formKey = GlobalKey<FormState>();
  final _complaint = TextEditingController();

  VehicleEntity? _vehicle;
  WorkOrderPriority _priority = WorkOrderPriority.normal;
  final List<XFile> _photos = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _vehicle = widget.vehicle;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<VehicleProvider>();
      if (provider.vehicles.isEmpty) provider.fetchAllVehicles();
    });
  }

  @override
  void dispose() {
    _complaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = context.watch<VehicleProvider>().vehicles;
    final width = MediaQuery.of(context).size.width;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        width: width > 700 ? 520.w : width * 0.92,
        padding: EdgeInsets.all(22.w),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Report a vehicle problem',
                style: GoogleFonts.inter(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'A coordinator will cost it and raise the work order.',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  color: const Color(0xFF6B7280),
                ),
              ),
              SizedBox(height: 18.h),
              DropdownButtonFormField<String>(
                initialValue: _vehicle?.id,
                isExpanded: true,
                decoration: _decoration('Vehicle *'),
                items: vehicles
                    .map(
                      (v) => DropdownMenuItem(
                        value: v.id,
                        child: Text(
                          '${v.plateNumber} · ${v.make} ${v.model}',
                          style: GoogleFonts.inter(fontSize: 13.sp),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                validator: (v) => v == null ? 'Pick a vehicle' : null,
                onChanged: (id) => setState(() {
                  _vehicle = vehicles.where((v) => v.id == id).firstOrNull;
                }),
              ),
              SizedBox(height: 14.h),
              TextFormField(
                controller: _complaint,
                autofocus: widget.vehicle != null,
                minLines: 3,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: _decoration(
                  'What is wrong? *',
                  hint: 'e.g. AC not cooling, noise when braking',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Describe the problem'
                    : null,
              ),
              SizedBox(height: 14.h),
              Text(
                'How urgent?',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF374151),
                ),
              ),
              SizedBox(height: 8.h),
              Wrap(
                spacing: 8.w,
                children: WorkOrderPriority.values
                    .map(
                      (p) => ChoiceChip(
                        label: Text(
                          p.displayName,
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: _priority == p
                                ? Colors.white
                                : const Color(0xFF6B7280),
                          ),
                        ),
                        selected: _priority == p,
                        showCheckmark: false,
                        selectedColor: p == WorkOrderPriority.vehicleDown
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF2563EB),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        onSelected: (_) => setState(() => _priority = p),
                      ),
                    )
                    .toList(),
              ),
              SizedBox(height: 14.h),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickPhoto,
                    icon: Icon(Icons.add_a_photo_outlined, size: 15.sp),
                    label: Text(
                      'Add photo',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  if (_photos.isNotEmpty)
                    Text(
                      '${_photos.length} photo${_photos.length == 1 ? '' : 's'}',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 22.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  SizedBox(width: 8.w),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: EdgeInsets.symmetric(
                        horizontal: 22.w,
                        vertical: 13.h,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    child: _isSaving
                        ? SizedBox(
                            width: 16.w,
                            height: 16.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Submit Report',
                            style: GoogleFonts.inter(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.inter(fontSize: 13.sp),
      hintStyle: GoogleFonts.inter(
        fontSize: 12.sp,
        color: const Color(0xFF9CA3AF),
      ),
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
    );
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => _photos.add(file));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final vehicle = _vehicle;
    final user = context.read<AuthProvider>().user;
    if (vehicle == null || user == null) return;

    setState(() => _isSaving = true);

    final provider = context.read<WorkOrderProvider>();
    final policy = context.read<FinanceProvider>().policy;

    // The report is created first so photos have a work order to hang off,
    // then attachments are uploaded and patched on. A failed upload leaves a
    // usable report rather than losing the whole thing.
    final created = await provider.createWorkOrder(
      vehicle: vehicle,
      complaint: _complaint.text.trim(),
      actor: user,
      policy: policy,
      source: WorkOrderSource.reported,
      priority: _priority,
    );

    if (created == null) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppSnackBar.showError(
        context,
        provider.error ?? 'Could not submit the report.',
      );
      return;
    }

    if (_photos.isNotEmpty) {
      final urls = <String>[];
      for (final photo in _photos) {
        final url = await provider.uploadAttachment(
          file: photo,
          workOrderId: created.id,
          kind: 'complaint',
        );
        if (url != null) urls.add(url);
      }
      if (urls.isNotEmpty) {
        await provider.saveDetails(
          workOrder: created.copyWith(reportedAttachmentUrls: urls),
          actor: user,
          note: '${urls.length} photo(s) attached',
        );
      }
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    AppSnackBar.showSuccess(
      context,
      '${created.workOrderNumber} reported for ${vehicle.plateNumber}.',
    );
    Navigator.pop(context, created);
  }
}
