import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_expiry_alert.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/get_vehicle_expiry_alerts_usecase.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/get_vehicle_maintenance_alerts_usecase.dart';
import 'package:xloop_invoice/features/vehicle/domain/usecases/get_vehicle_followup_alerts_usecase.dart';
import 'package:xloop_invoice/features/vehicle/presentation/providers/vehicle_provider.dart';
import 'package:xloop_invoice/injection_container.dart';
import 'package:xloop_invoice/core/widgets/modern_app_bar.dart';
import 'package:provider/provider.dart';
import 'package:xloop_invoice/widgets/add_maintenance_record_dialog.dart';
import 'package:xloop_invoice/features/vehicle/presentation/widgets/maintenance_extension_dialog.dart';
import 'package:intl/intl.dart';

class _DT {
  static const bgPage = Color(0xFFF4F6FB);
  static const brand = Color(0xFF4F46E5);
  static const danger = Color(0xFFDC2626);
  static const dangerBg = Color(0xFFFFF1F2);
  static const dangerBorder = Color(0xFFFFCDD2);
  static const warning = Color(0xFFD97706);
  static const warningBg = Color(0xFFFFFBEB);
  static const warningBorder = Color(0xFFFFE082);
  static const success = Color(0xFF16A34A);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
}

class VehicleExpiryTrackerScreen extends StatefulWidget {
  const VehicleExpiryTrackerScreen({super.key});

  @override
  State<VehicleExpiryTrackerScreen> createState() =>
      _VehicleExpiryTrackerScreenState();
}

class _VehicleExpiryTrackerScreenState
    extends State<VehicleExpiryTrackerScreen> {
  bool _isLoading = true;
  List<VehicleExpiryAlert> _allAlerts = [];
  List<VehicleMaintenanceAlert> _allMaintenanceAlerts = [];
  List<VehicleFollowUpAlert> _allFollowUpAlerts = [];

  List<dynamic> _filteredAlerts = [];
  String _selectedType = 'All';
  final List<String> _types = ['All', 'Maintenance'];
  String _selectedSubMaintenanceType = 'All Maintenance';
  final List<String> _subMaintenanceTypes = ['All Maintenance'];

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    try {
      final expiryUseCase = sl<GetVehicleExpiryAlertsUseCase>();
      final maintenanceUseCase = sl<GetVehicleMaintenanceAlertsUseCase>();

      final vehicleProvider = context.read<VehicleProvider>();

      final alerts = await expiryUseCase(includeAll: true);
      _allAlerts = alerts;

      _allMaintenanceAlerts = maintenanceUseCase(
        vehicles: vehicleProvider.vehicles,
        maintenanceTypes: vehicleProvider.maintenanceTypes,
        includeAll: true,
      );
      
      final followUpUseCase = sl<GetVehicleFollowUpAlertsUseCase>();
      _allFollowUpAlerts = followUpUseCase(
        vehicles: vehicleProvider.vehicles,
      );

      // Extract unique document types
      final Set<String> types = {'All', 'Maintenance', 'Extended', 'Revisit'};
      for (var alert in alerts) {
        types.add(alert.documentType);
      }
      _types.clear();
      _types.addAll(types);

      // Extract unique maintenance types
      final Set<String> maintCategories = {'All Maintenance'};
      for (var alert in _allMaintenanceAlerts) {
        maintCategories.add(alert.category);
      }
      _subMaintenanceTypes.clear();
      _subMaintenanceTypes.addAll(maintCategories);

      _filterAlerts();
    } catch (e) {
      debugPrint('Error loading vehicle alerts: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterAlerts() {
    _filteredAlerts.clear();

    if (_selectedType == 'All') {
      _filteredAlerts.addAll(_allAlerts);
      _filteredAlerts.addAll(_allMaintenanceAlerts);
      _filteredAlerts.addAll(_allFollowUpAlerts);
    } else if (_selectedType == 'Maintenance') {
      if (_selectedSubMaintenanceType == 'All Maintenance') {
        _filteredAlerts.addAll(_allMaintenanceAlerts);
      } else {
        _filteredAlerts.addAll(
          _allMaintenanceAlerts.where((a) => a.category == _selectedSubMaintenanceType),
        );
      }
    } else if (_selectedType == 'Extended') {
      _filteredAlerts.addAll(_allMaintenanceAlerts.where((a) => a.isExtended));
    } else if (_selectedType == 'Revisit') {
      _filteredAlerts.addAll(_allFollowUpAlerts);
    } else {
      _filteredAlerts.addAll(
        _allAlerts.where((a) => a.documentType == _selectedType),
      );
    }

    // Sort logic
    _filteredAlerts.sort((a, b) {
      int scoreA = _getScore(a);
      int scoreB = _getScore(b);
      return scoreA.compareTo(scoreB);
    });
  }

  int _getScore(dynamic alert) {
    if (alert is VehicleExpiryAlert) {
      return alert
          .daysUntilExpiry; // Lower is more urgent (or negative for expired)
    } else if (alert is VehicleMaintenanceAlert) {
      return -alert
          .kmOverdue; // Positive kmOverdue becomes negative (more urgent)
    } else if (alert is VehicleFollowUpAlert) {
      // Prioritize past due dates, then closer dates
      if (alert.nextServiceDate != null) {
        return alert.nextServiceDate!.difference(DateTime.now()).inDays;
      }
      return 0; // Default to urgent if no date
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DT.bgPage,
      appBar: const ModernAppBar(title: 'Vehicle Tracker'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFilterRow(),
                Expanded(
                  child: _filteredAlerts.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: EdgeInsets.symmetric(
                            horizontal: 24.w,
                            vertical: 16.h,
                          ),
                          physics: const BouncingScrollPhysics(),
                          itemCount: _filteredAlerts.length,
                          separatorBuilder: (_, __) => SizedBox(height: 12.h),
                          itemBuilder: (context, i) {
                            final alert = _filteredAlerts[i];
                            if (alert is VehicleExpiryAlert) {
                              return _VehicleExpiryCard(alert: alert);
                            } else if (alert is VehicleFollowUpAlert) {
                              return _VehicleFollowUpCard(alert: alert, onRefresh: _loadAlerts);
                            } else {
                              return _VehicleMaintenanceCard(
                                alert: alert as VehicleMaintenanceAlert,
                                onRefresh: _loadAlerts,
                              );
                            }
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterRow() {
    return Container(
      padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 8.h),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _DT.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter by Document / Category',
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: _DT.textPrimary,
            ),
          ),
          SizedBox(height: 12.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _types.map((type) {
                final isSelected = _selectedType == type;
                int count = 0;
                if (type == 'All') {
                  count = _allAlerts.length + _allMaintenanceAlerts.length + _allFollowUpAlerts.length;
                } else if (type == 'Maintenance') {
                  count = _allMaintenanceAlerts.length;
                } else if (type == 'Extended') {
                  count = _allMaintenanceAlerts.where((a) => a.isExtended).length;
                } else if (type == 'Revisit') {
                  count = _allFollowUpAlerts.length;
                } else {
                  count = _allAlerts
                      .where((a) => a.documentType == type)
                      .length;
                }

                return Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(type),
                        if (count > 0) ...[
                          SizedBox(width: 6.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withOpacity(0.2)
                                  : _DT.brand.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Text(
                              count.toString(),
                              style: GoogleFonts.inter(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : _DT.brand,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedType = type;
                          _selectedSubMaintenanceType = 'All Maintenance';
                          _filterAlerts();
                        });
                      }
                    },
                    backgroundColor: Colors.white,
                    selectedColor: _DT.brand,
                    labelStyle: GoogleFonts.inter(
                      color: isSelected ? Colors.white : _DT.textSecondary,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.r),
                      side: BorderSide(
                        color: isSelected ? _DT.brand : _DT.border,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (_selectedType == 'Maintenance' && _subMaintenanceTypes.length > 1) ...[
            SizedBox(height: 16.h),
            const Divider(height: 1),
            SizedBox(height: 12.h),
            Text(
              'Maintenance Type Filter',
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: _DT.textPrimary,
              ),
            ),
            SizedBox(height: 10.h),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _subMaintenanceTypes.map((subType) {
                  final isSelected = _selectedSubMaintenanceType == subType;
                  int count = 0;
                  if (subType == 'All Maintenance') {
                    count = _allMaintenanceAlerts.length;
                  } else {
                    count = _allMaintenanceAlerts
                        .where((a) => a.category == subType)
                        .length;
                  }

                  return Padding(
                    padding: EdgeInsets.only(right: 8.w),
                    child: ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(subType),
                          if (count > 0) ...[
                            SizedBox(width: 6.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withOpacity(0.2)
                                    : _DT.brand.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Text(
                                count.toString(),
                                style: GoogleFonts.inter(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : _DT.brand,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedSubMaintenanceType = subType;
                            _filterAlerts();
                          });
                        }
                      },
                      backgroundColor: Colors.white,
                      selectedColor: _DT.brand,
                      labelStyle: GoogleFonts.inter(
                        color: isSelected ? Colors.white : _DT.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        fontSize: 12.sp,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.r),
                        side: BorderSide(
                          color: isSelected ? _DT.brand : _DT.border,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: _DT.success.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline,
              color: _DT.success,
              size: 48.sp,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'All vehicle documents and maintenance up to date',
            style: GoogleFonts.inter(
              fontSize: 16.sp,
              color: _DT.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleExpiryCard extends StatefulWidget {
  final VehicleExpiryAlert alert;
  const _VehicleExpiryCard({required this.alert});

  @override
  State<_VehicleExpiryCard> createState() => _VehicleExpiryCardState();
}

class _VehicleExpiryCardState extends State<_VehicleExpiryCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.alert;
    final isExpired = a.daysUntilExpiry < 0;
    final isCritical = a.daysUntilExpiry >= 0 && a.daysUntilExpiry <= 15;

    final color = isExpired
        ? _DT.danger
        : (isCritical ? _DT.warning : _DT.brand);
    final bgColor = isExpired
        ? _DT.dangerBg
        : (isCritical ? _DT.warningBg : Colors.white);
    final borderColor = isExpired
        ? _DT.dangerBorder
        : (isCritical ? _DT.warningBorder : _DT.border);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _hovered ? bgColor : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: _hovered ? color.withOpacity(0.5) : borderColor,
          ),
          boxShadow: [
            if (_hovered)
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isExpired ? Icons.error_outline : Icons.warning_amber_rounded,
                color: color,
                size: 24.sp,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        a.plateNumber,
                        style: GoogleFonts.inter(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          color: _DT.textPrimary,
                        ),
                      ),
                      if (a.driverName != null) ...[
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: _DT.brand.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person, size: 10.sp, color: _DT.brand),
                              SizedBox(width: 4.w),
                              Text(
                                a.driverName!,
                                style: GoogleFonts.inter(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w600,
                                  color: _DT.brand,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: _DT.border,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          a.documentType,
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: _DT.textSecondary,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Expires: ${a.expiryDate.toLocal().toString().split(' ')[0]}',
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          color: _DT.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 16.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isExpired ? 'Expired' : '${a.daysUntilExpiry} days',
                  style: GoogleFonts.inter(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  isExpired
                      ? '${a.daysUntilExpiry.abs()} days ago'
                      : 'Remaining',
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    color: color.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleMaintenanceCard extends StatefulWidget {
  final VehicleMaintenanceAlert alert;
  final VoidCallback? onRefresh;
  const _VehicleMaintenanceCard({required this.alert, this.onRefresh});

  @override
  State<_VehicleMaintenanceCard> createState() =>
      _VehicleMaintenanceCardState();
}

class _VehicleMaintenanceCardState extends State<_VehicleMaintenanceCard> {
  bool _hovered = false;
  bool _isExpanded = false;

  void _extendAlert(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (context) => MaintenanceExtensionDialog(
        vehicle: widget.alert.vehicle,
        alert: widget.alert,
      ),
    ).then((success) {
      if (success == true && widget.onRefresh != null) {
        widget.onRefresh!();
      }
    });
  }

  void _markAsReplaced(BuildContext context) {
    final provider = context.read<VehicleProvider>();
    final matches = provider.maintenanceTypes.where(
      (t) => t.name.toLowerCase() == widget.alert.category.toLowerCase()
    );
    final typeId = matches.isNotEmpty ? matches.first.id : null;

    showDialog<bool>(
      context: context,
      builder: (context) => AddMaintenanceRecordDialog(
        vehicle: widget.alert.vehicle,
        initialMaintenanceTypeId: typeId,
      ),
    ).then((success) {
      if (success == true && widget.onRefresh != null) {
        widget.onRefresh!();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.alert;
    final isOverdue = a.kmOverdue > 0;
    final isCritical =
        a.kmOverdue <= 0 && a.kmOverdue >= -1000; // Within 1000km

    final color = isOverdue
        ? _DT.danger
        : (isCritical ? _DT.warning : _DT.brand);
    final bgColor = isOverdue
        ? _DT.dangerBg
        : (isCritical ? _DT.warningBg : Colors.white);
    final borderColor = isOverdue
        ? _DT.dangerBorder
        : (isCritical ? _DT.warningBorder : _DT.border);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _hovered ? bgColor : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: _hovered ? color.withOpacity(0.5) : borderColor,
          ),
          boxShadow: [
            if (_hovered)
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.build_circle_outlined,
                    color: color,
                    size: 24.sp,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            a.vehicle.plateNumber,
                            style: GoogleFonts.inter(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                              color: _DT.textPrimary,
                            ),
                          ),
                          if (a.isExtended) ...[
                            SizedBox(width: 8.w),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isExpanded = !_isExpanded;
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color: _DT.brand.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4.r),
                                  border: Border.all(color: _DT.brand.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.history_rounded, size: 10.sp, color: _DT.brand),
                                    SizedBox(width: 4.w),
                                    Text(
                                      'EXTENDED (${a.extensionHistory.length})',
                                      style: GoogleFonts.inter(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w700,
                                        color: _DT.brand,
                                      ),
                                    ),
                                    SizedBox(width: 2.w),
                                    Icon(
                                      _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                      size: 12.sp,
                                      color: _DT.brand,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: _DT.border,
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              a.category,
                              style: GoogleFonts.inter(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: _DT.textSecondary,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'Due at: ${a.nextServiceMileage} km',
                            style: GoogleFonts.inter(
                              fontSize: 13.sp,
                              color: _DT.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isOverdue ? 'Overdue' : 'Upcoming',
                      style: GoogleFonts.inter(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    Text(
                      isOverdue
                          ? '${a.kmOverdue} km past'
                          : '${a.nextServiceMileage - a.currentMileage} km left',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        color: color.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _extendAlert(context),
                  icon: Icon(Icons.snooze, size: 14.sp),
                  label: Text(
                    'Extend Alert',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _DT.brand,
                    side: const BorderSide(color: _DT.brand),
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                ElevatedButton.icon(
                  onPressed: () => _markAsReplaced(context),
                  icon: Icon(Icons.build, size: 14.sp),
                  label: Text(
                    'Mark Replaced',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _DT.brand,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                ),
              ],
            ),
            if (_isExpanded && a.extensionHistory.isNotEmpty)
              _buildTimeline(a),
          ],
        ),
      ),
    );
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
}

class _VehicleFollowUpCard extends StatefulWidget {
  final VehicleFollowUpAlert alert;
  final VoidCallback? onRefresh;
  const _VehicleFollowUpCard({required this.alert, this.onRefresh});

  @override
  State<_VehicleFollowUpCard> createState() => _VehicleFollowUpCardState();
}

class _VehicleFollowUpCardState extends State<_VehicleFollowUpCard> {
  bool _hovered = false;

  void _markAsReplaced(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (context) => AddMaintenanceRecordDialog(
        vehicle: widget.alert.vehicle,
      ),
    ).then((success) {
      if (success == true && widget.onRefresh != null) {
        widget.onRefresh!();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.alert;
    
    // Determine urgency based on date if available
    bool isOverdue = false;
    bool isCritical = false;
    if (a.nextServiceDate != null) {
      final days = a.nextServiceDate!.difference(DateTime.now()).inDays;
      isOverdue = days < 0;
      isCritical = days >= 0 && days <= 15;
    } else {
      isCritical = true; // Urgent if only mileage or no date is set
    }

    final color = isOverdue
        ? _DT.danger
        : (isCritical ? _DT.warning : _DT.brand);
    final bgColor = isOverdue
        ? _DT.dangerBg
        : (isCritical ? _DT.warningBg : Colors.white);
    final borderColor = isOverdue
        ? _DT.dangerBorder
        : (isCritical ? _DT.warningBorder : _DT.border);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _hovered ? bgColor : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: _hovered ? color.withOpacity(0.5) : borderColor,
          ),
          boxShadow: [
            if (_hovered)
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.handyman_rounded,
                    color: color,
                    size: 24.sp,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            a.vehicle.plateNumber,
                            style: GoogleFonts.inter(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                              color: _DT.textPrimary,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: _DT.brand.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.sync_rounded, size: 10.sp, color: _DT.brand),
                                SizedBox(width: 4.w),
                                Text(
                                  'REVISIT',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w700,
                                    color: _DT.brand,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: _DT.border,
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              a.reason,
                              style: GoogleFonts.inter(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: _DT.textSecondary,
                              ),
                            ),
                          ),
                          if (a.nextServiceDate != null) ...[
                            SizedBox(width: 8.w),
                            Text(
                              'Due by: ${a.nextServiceDate!.toLocal().toString().split(' ')[0]}',
                              style: GoogleFonts.inter(
                                fontSize: 13.sp,
                                color: _DT.textSecondary,
                              ),
                            ),
                          ],
                          if (a.nextServiceMileage != null) ...[
                            SizedBox(width: 8.w),
                            Text(
                              'Due at: ${a.nextServiceMileage} km',
                              style: GoogleFonts.inter(
                                fontSize: 13.sp,
                                color: _DT.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isOverdue ? 'Overdue' : 'Follow Up',
                      style: GoogleFonts.inter(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _markAsReplaced(context),
                  icon: Icon(Icons.build, size: 14.sp),
                  label: Text(
                    'Complete Revisit',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _DT.brand,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
