import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../features/notifications/domain/entities/notification_entity.dart';
import '../../features/notifications/presentation/providers/notification_provider.dart';
import '../utils/update_dialog_helper.dart';
import '../../features/vehicle/presentation/providers/vehicle_provider.dart';
import '../../features/vehicle/presentation/widgets/maintenance_extension_dialog.dart';
import '../../features/vehicle/domain/usecases/get_vehicle_maintenance_alerts_usecase.dart';
import '../../features/vehicle/domain/entities/vehicle_entity.dart';
import '../../injection_container.dart';

class ActionItemsDialog extends StatelessWidget {
  final String title;
  final String relatedId;

  const ActionItemsDialog({
    super.key,
    required this.title,
    required this.relatedId,
  });

  static void show(BuildContext context, String title, String relatedId) {
    showDialog(
      context: context,
      builder: (context) =>
          ActionItemsDialog(title: title, relatedId: relatedId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, _) {
        final items = provider.getNotificationsByRelatedId(relatedId);

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 750.w, maxHeight: 600.h),
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(10.w),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              color: const Color(0xFFDC2626),
                              size: 22.sp,
                            ),
                          ),
                          SizedBox(width: 14.w),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Action Items',
                                style: GoogleFonts.inter(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                title,
                                style: GoogleFonts.inter(
                                  fontSize: 13.sp,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  SizedBox(height: 24.h),
                  if (items.isEmpty)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40.h),
                        child: Column(
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 48.sp,
                              color: Colors.green,
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              'All clear!',
                              style: GoogleFonts.inter(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                            Text(
                              'No pending actions for this entity.',
                              style: GoogleFonts.inter(
                                fontSize: 14.sp,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder: (_, __) => SizedBox(height: 12.h),
                        itemBuilder: (context, index) {
                          return _ExpiryCard(
                            alert: items[index],
                            onUpdate: () {
                              UpdateDialogHelper.showUpdateDialog(
                                context,
                                items[index],
                              );
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ExpiryCard extends StatefulWidget {
  final NotificationEntity alert;
  final VoidCallback onUpdate;
  const _ExpiryCard({required this.alert, required this.onUpdate});

  @override
  State<_ExpiryCard> createState() => _ExpiryCardState();
}

class _ExpiryCardState extends State<_ExpiryCard> {
  bool _hovered = false;

  void _extendAlert() {
    final relatedId = widget.alert.relatedId;
    if (relatedId == null) return;

    final vehicleProvider = context.read<VehicleProvider>();
    final vehicle = vehicleProvider.vehicles.cast<VehicleEntity?>().firstWhere(
      (v) => v?.id == relatedId,
      orElse: () => null,
    );
    if (vehicle == null) return;

    final prefix = 'maintenance_${relatedId}_';
    final categoryEncoded = widget.alert.id.substring(prefix.length);
    final category = categoryEncoded.replaceAll('_', ' ');

    final maintenanceUseCase = sl<GetVehicleMaintenanceAlertsUseCase>();
    final alerts = maintenanceUseCase(
      vehicles: vehicleProvider.vehicles,
      maintenanceTypes: vehicleProvider.maintenanceTypes,
      includeAll: true,
    );
    final alert = alerts.firstWhere(
      (a) =>
          a.vehicle.id == vehicle.id &&
          a.category.toLowerCase() == category.toLowerCase(),
      orElse: () => VehicleMaintenanceAlert(
        vehicle: vehicle,
        category: category,
        currentMileage: vehicle.currentOdometer ?? 0,
        lastServiceMileage: 0,
        nextServiceMileage: vehicle.currentOdometer ?? 0,
        kmOverdue: 0,
      ),
    );

    showDialog<bool>(
      context: context,
      builder: (context) => MaintenanceExtensionDialog(
        vehicle: vehicle,
        alert: alert,
      ),
    ).then((success) {
      if (success == true) {
        if (mounted) {
          final notifProvider = context.read<NotificationProvider>();
          notifProvider.markAsRead(widget.alert.id);
          notifProvider.refreshAlerts(
            vehicles: vehicleProvider.vehicles,
            maintenanceTypes: vehicleProvider.maintenanceTypes,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const danger = Color(0xFFDC2626);
    const brand = Color(0xFF4F46E5);
    const dangerBg = Color(0xFFFFF1F2);
    const dangerBorder = Color(0xFFFFCDD2);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: _hovered ? dangerBg : Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: _hovered ? danger.withOpacity(0.35) : dangerBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: danger.withOpacity(_hovered ? 0.08 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: danger.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  color: danger,
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.alert.title,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.sp,
                        color: danger,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      widget.alert.message,
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: danger.withOpacity(0.75),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              if (widget.alert.id.startsWith('maintenance_')) ...[
                OutlinedButton(
                  onPressed: _extendAlert,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: brand,
                    side: const BorderSide(color: brand),
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: Text(
                    'Extend Alert',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                _ActionButton(
                  label: 'Mark Completed',
                  color: danger,
                  onPressed: widget.onUpdate,
                ),
              ] else ...[
                _ActionButton(
                  label: 'Update',
                  color: danger,
                  onPressed: widget.onUpdate,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(8.r),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
