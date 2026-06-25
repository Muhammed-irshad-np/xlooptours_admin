import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_entity.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/get_vehicle_maintenance_alerts_usecase.dart';
import 'package:xloop_invoice/features/vehicle/presentation/providers/vehicle_provider.dart';
import 'package:xloop_invoice/features/auth/presentation/providers/auth_provider.dart';
import 'package:xloop_invoice/core/utils/activity_logger.dart';

class MaintenanceExtensionDialog extends StatefulWidget {
  final VehicleEntity vehicle;
  final VehicleMaintenanceAlert alert;

  const MaintenanceExtensionDialog({
    super.key,
    required this.vehicle,
    required this.alert,
  });

  @override
  State<MaintenanceExtensionDialog> createState() => _MaintenanceExtensionDialogState();
}

class _MaintenanceExtensionDialogState extends State<MaintenanceExtensionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _extensionController = TextEditingController(text: '10000');
  final _reasonController = TextEditingController();
  bool _isLoading = false;
  int? _calculatedThreshold;

  @override
  void initState() {
    super.initState();
    _recalculateThreshold();
    _extensionController.addListener(_recalculateThreshold);
  }

  @override
  void dispose() {
    _extensionController.removeListener(_recalculateThreshold);
    _extensionController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _recalculateThreshold() {
    final baseOdo = widget.alert.nextServiceMileage;
    final extVal = int.tryParse(_extensionController.text) ?? 0;
    setState(() {
      _calculatedThreshold = baseOdo + extVal;
    });
  }

  Future<void> _submitExtension() async {
    if (!_formKey.currentState!.validate()) return;

    final user = context.read<AuthProvider>().user;
    final email = user?.email;
    final username = (user?.displayName != null && user!.displayName!.isNotEmpty)
        ? user.displayName
        : (email != null && email.contains('@')
            ? email.split('@').first
            : (email ?? 'System'));

    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<VehicleProvider>();
      final extensionKm = int.parse(_extensionController.text);
      final reason = _reasonController.text.trim();

      await provider.extendVehicleMaintenance(
        vehicle: widget.vehicle,
        category: widget.alert.category,
        extensionKm: extensionKm,
        reason: reason,
        performedBy: username,
        baseOdometer: widget.alert.nextServiceMileage,
      );

      if (mounted) {
        await ActivityLogger.log(
          context,
          title: 'Alert Extended',
          message: 'Maintenance alert for ${widget.alert.category} on vehicle ${widget.vehicle.make} ${widget.vehicle.model} (${widget.vehicle.plateNumber}) extended by $extensionKm km.',
          relatedId: widget.vehicle.id,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully extended ${widget.alert.category} alert by $extensionKm km.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to extend maintenance: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentOdo = widget.vehicle.currentOdometer ?? 0;

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
                'Extend Maintenance Alert',
                style: GoogleFonts.inter(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF111827),
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                '${widget.vehicle.make} ${widget.vehicle.model} (${widget.vehicle.plateNumber})',
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  color: const Color(0xFF4B5563),
                ),
              ),
              const Divider(height: 32),
              
              // Alert Summary Card
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber.shade800, size: 20.sp),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Part: ${widget.alert.category}\nCurrent Odometer: $currentOdo km\nOriginal Due: ${widget.alert.nextServiceMileage} km',
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          height: 1.5,
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),

              // Extension Input
              TextFormField(
                controller: _extensionController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Extension Mileage (KM)',
                  hintText: 'e.g., 20000',
                  suffixText: 'km',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final numVal = int.tryParse(v);
                  if (numVal == null || numVal <= 0) return 'Enter a positive integer';
                  return null;
                },
              ),
              SizedBox(height: 16.h),

              // Reason Input
              TextFormField(
                controller: _reasonController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Inspection Notes / Reason',
                  hintText: 'e.g., Brake pad has 5mm remaining, safe for extended use.',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Please provide inspection notes';
                  return null;
                },
              ),
              SizedBox(height: 20.h),

              // Projection Result
              if (_calculatedThreshold != null)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Projected Next Due:',
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          color: const Color(0xFF4B5563),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '$_calculatedThreshold km',
                        style: GoogleFonts.inter(
                          fontSize: 15.sp,
                          color: const Color(0xFF111827),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: 24.h),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(color: const Color(0xFF4B5563)),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitExtension,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 20.w,
                            height: 20.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Approve Extension',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
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
}
