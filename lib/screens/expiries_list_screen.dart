import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:xloop_invoice/features/notifications/presentation/providers/notification_provider.dart';
import 'package:xloop_invoice/features/notifications/domain/entities/notification_entity.dart';
import 'package:xloop_invoice/core/utils/update_dialog_helper.dart';
import 'package:xloop_invoice/features/vehicle/presentation/providers/vehicle_provider.dart';
import 'package:xloop_invoice/features/vehicle/presentation/widgets/maintenance_extension_dialog.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/get_vehicle_maintenance_alerts_usecase.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_entity.dart';
import 'package:xloop_invoice/features/employee/presentation/providers/employee_provider.dart';
import 'package:xloop_invoice/features/xloop_vault/presentation/providers/vault_provider.dart';
import 'package:intl/intl.dart';
import 'package:xloop_invoice/injection_container.dart';

class _DT {
  static const bgPage = Color(0xFFF4F6FB);

  static const brand = Color(0xFF4F46E5);
  static const danger = Color(0xFFDC2626);
  static const dangerBg = Color(0xFFFFF1F2);
  static const dangerBorder = Color(0xFFFFCDD2);
  static const success = Color(0xFF16A34A);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);

}

class ExpiriesListScreen extends StatefulWidget {
  const ExpiriesListScreen({super.key});

  @override
  State<ExpiriesListScreen> createState() => _ExpiriesListScreenState();
}

class _ExpiriesListScreenState extends State<ExpiriesListScreen> {
  int _selectedTabIndex = 0;
  final List<String> _tabs = ['All', 'Company', 'Vehicles', 'Employees', 'Other'];

  List<NotificationEntity> _getFilteredExpiries(List<NotificationEntity> allExpiries) {
    if (_selectedTabIndex == 0) return allExpiries;
    if (_selectedTabIndex == 1) {
      // Company (Vault)
      return allExpiries.where((n) => n.id.startsWith('vault_')).toList();
    }
    if (_selectedTabIndex == 2) {
      return allExpiries
          .where((n) =>
              n.id.startsWith('maintenance_') ||
              n.id.startsWith('v_expiry_') ||
              n.id.startsWith('followup_'))
          .toList();
    }
    if (_selectedTabIndex == 3) {
      return allExpiries.where((n) => n.id.startsWith('expiry_')).toList();
    }
    return allExpiries
        .where((n) =>
            !n.id.startsWith('maintenance_') &&
            !n.id.startsWith('v_expiry_') &&
            !n.id.startsWith('expiry_') &&
            !n.id.startsWith('vault_') &&
            !n.id.startsWith('followup_'))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DT.bgPage,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.white,
        title: Text(
          'All Action Items',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 20.sp,
            color: _DT.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1.h),
          child: Container(height: 1.h, color: _DT.border),
        ),
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          final expiries = provider.expiryAlerts
              .where((n) => n.type == NotificationType.expiry)
              .toList();
          final filtered = _getFilteredExpiries(expiries);

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (expiries.isNotEmpty) ...[
                  Semantics(
                    label: 'Action item tabs',
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: List.generate(_tabs.length, (index) {
                          final isSelected = _selectedTabIndex == index;
                          int tabCount = 0;
                          if (index == 0) tabCount = expiries.length;
                          if (index == 1) {
                            tabCount =
                                expiries.where((n) => n.id.startsWith('vault_')).length;
                          }
                          if (index == 2) {
                            tabCount = expiries
                                .where((n) =>
                                    n.id.startsWith('maintenance_') ||
                                    n.id.startsWith('v_expiry_') ||
                                    n.id.startsWith('followup_'))
                                .length;
                          }
                          if (index == 3) {
                            tabCount = expiries
                                .where((n) => n.id.startsWith('expiry_'))
                                .length;
                          }
                          if (index == 4) {
                            tabCount = expiries
                                .where((n) =>
                                    !n.id.startsWith('maintenance_') &&
                                    !n.id.startsWith('v_expiry_') &&
                                    !n.id.startsWith('expiry_') &&
                                    !n.id.startsWith('vault_') &&
                                    !n.id.startsWith('followup_'))
                                .length;
                          }

                          return Padding(
                            padding: EdgeInsets.only(right: 8.w),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              child: ChoiceChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(_tabs[index]),
                                    if (tabCount > 0) ...[
                                      SizedBox(width: 6.w),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 6.w, vertical: 2.h),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.white.withOpacity(0.2)
                                              : _DT.brand.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(20.r),
                                        ),
                                        child: Text(
                                          tabCount.toString(),
                                          style: GoogleFonts.inter(
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.w700,
                                            color: isSelected
                                                ? Colors.white
                                                : _DT.brand,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() => _selectedTabIndex = index);
                                  }
                                },
                                labelStyle: GoogleFonts.inter(
                                  color: isSelected
                                      ? Colors.white
                                      : _DT.textSecondary,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  fontSize: 13.sp,
                                ),
                                backgroundColor: Colors.white,
                                selectedColor: _DT.brand,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20.r),
                                  side: BorderSide(
                                    color: isSelected
                                        ? _DT.brand
                                        : _DT.border.withOpacity(0.8),
                                  ),
                                ),
                                elevation: isSelected ? 2 : 0,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  SizedBox(height: 24.h),
                ],
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.all(16.w),
                                decoration: BoxDecoration(
                                  color: _DT.success.withOpacity(0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.check_circle_outline_rounded,
                                    size: 48.sp, color: _DT.success),
                              ),
                              SizedBox(height: 16.h),
                              Text(
                                expiries.isEmpty
                                    ? 'All clear — no urgent action items'
                                    : 'No action items in this category',
                                style: GoogleFonts.inter(
                                  fontSize: 16.sp,
                                  color: _DT.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => SizedBox(height: 12.h),
                          itemBuilder: (context, i) => _ExpiryCard(
                            alert: filtered[i],
                            onUpdate: () => UpdateDialogHelper.showUpdateDialog(
                              context,
                              filtered[i],
                            ),
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
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
  bool _isExpanded = false;

  VehicleMaintenanceAlert? _getMaintenanceAlert() {
    if (!widget.alert.id.startsWith('maintenance_')) return null;
    final relatedId = widget.alert.relatedId;
    if (relatedId == null) return null;

    final vehicleProvider = context.read<VehicleProvider>();
    final vehicle = vehicleProvider.vehicles.cast<VehicleEntity?>().firstWhere(
      (v) => v?.id == relatedId,
      orElse: () => null,
    );
    if (vehicle == null) return null;

    final prefix = 'maintenance_${relatedId}_';
    final categoryEncoded = widget.alert.id.substring(prefix.length);
    final category = categoryEncoded.replaceAll('_', ' ');

    final maintenanceUseCase = sl<GetVehicleMaintenanceAlertsUseCase>();
    final alerts = maintenanceUseCase(
      vehicles: [vehicle],
      maintenanceTypes: vehicleProvider.maintenanceTypes,
      includeAll: true,
    );
    try {
      return alerts.firstWhere((a) => a.category.toLowerCase() == category.toLowerCase());
    } catch (_) {
      return null;
    }
  }

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
        originalDueMileage: vehicle.currentOdometer ?? 0,
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
          final employeeProvider = context.read<EmployeeProvider>();
          final vaultProvider = context.read<VaultProvider>();
          notifProvider.markAsRead(widget.alert.id);
          notifProvider.refreshAlerts(
            vehicles: vehicleProvider.vehicles,
            maintenanceTypes: vehicleProvider.maintenanceTypes,
            employees: employeeProvider.employees,
            employeeSettings: employeeProvider.settings,
            vehicleSettings: vehicleProvider.settings,
            vaultData: vaultProvider.vaultData,
          );
        }
      }
    });
  }

  Widget _buildTimelineStep({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 24.w,
                height: 24.w,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14.sp, color: color),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2.w,
                    margin: EdgeInsets.symmetric(vertical: 4.h),
                    decoration: BoxDecoration(
                      color: _DT.border,
                      borderRadius: BorderRadius.circular(1.r),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: _DT.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: _DT.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _cleanReason(String? notes) {
    if (notes == null) return "No reason provided";
    const reasonMarker = "Reason: ";
    if (notes.startsWith("Alert extended by") && notes.contains(reasonMarker)) {
      return notes.substring(notes.indexOf(reasonMarker) + reasonMarker.length);
    }
    return notes;
  }

  Widget _buildTimeline(VehicleMaintenanceAlert mAlert) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16.h),
        Divider(color: _DT.border, height: 1),
        SizedBox(height: 16.h),
        Text(
          'Extension History',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600, 
            fontSize: 13.sp, 
            color: _DT.textPrimary
          ),
        ),
        SizedBox(height: 16.h),
        // Step 0: Original Due
        _buildTimelineStep(
          title: 'Originally Due',
          subtitle: '${mAlert.originalDueMileage} km',
          icon: Icons.flag_outlined,
          color: _DT.textSecondary,
          isLast: mAlert.extensionHistory.isEmpty,
        ),
        // Extensions
        ...mAlert.extensionHistory.asMap().entries.map((entry) {
          final index = entry.key;
          final ext = entry.value;
          final isLast = index == mAlert.extensionHistory.length - 1;
          
          return _buildTimelineStep(
            title: 'Extended by ${ext.extendedMileage ?? 0} km to ${ext.nextServiceMileage ?? 0} km',
            subtitle: '${DateFormat('MMM dd, yyyy').format(ext.date)} • By ${ext.performedBy ?? "Unknown"}\nReason: ${_cleanReason(ext.notes)}',
            icon: Icons.history,
            color: _DT.brand,
            isLast: isLast,
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mAlert = _getMaintenanceAlert();
    final hasExtensions = mAlert != null && mAlert.extensionHistory.isNotEmpty;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: _hovered ? _DT.dangerBg : Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: _hovered ? _DT.danger.withOpacity(0.35) : _DT.dangerBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: _DT.danger.withOpacity(_hovered ? 0.08 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 14.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: _DT.danger.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.error_outline_rounded,
                      color: _DT.danger,
                      size: 22.sp,
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.alert.title,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.sp,
                            color: _DT.danger,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          widget.alert.message,
                          style: GoogleFonts.inter(
                            fontSize: 13.sp,
                            color: _DT.danger.withOpacity(0.75),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (hasExtensions) ...[
                          SizedBox(height: 8.h),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isExpanded = !_isExpanded;
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                color: _DT.brand.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6.r),
                                border: Border.all(color: _DT.brand.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.history, size: 12.sp, color: _DT.brand),
                                  SizedBox(width: 4.w),
                                  Text(
                                    'Extended ${mAlert.extensionHistory.length} time${mAlert.extensionHistory.length > 1 ? 's' : ''}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w600,
                                      color: _DT.brand,
                                    ),
                                  ),
                                  SizedBox(width: 2.w),
                                  Icon(
                                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                    size: 14.sp,
                                    color: _DT.brand,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                  SizedBox(width: 12.w),
                  if (widget.alert.id.startsWith('maintenance_')) ...[
                    OutlinedButton(
                      onPressed: _extendAlert,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _DT.brand,
                        side: const BorderSide(color: _DT.brand),
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
                      color: _DT.danger,
                      onPressed: widget.onUpdate,
                    ),
                  ] else ...[
                    _ActionButton(
                      label: 'Update',
                      color: _DT.danger,
                      onPressed: widget.onUpdate,
                    ),
                  ],
                ],
              ),
              if (_isExpanded && hasExtensions) _buildTimeline(mAlert!),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.r),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 13.sp,
        ),
      ),
    );
  }
}
