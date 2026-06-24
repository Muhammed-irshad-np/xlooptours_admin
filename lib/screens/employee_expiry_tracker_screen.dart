import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:xloop_invoice/features/employee/domain/entities/employee_expiry_alert.dart';
import 'package:xloop_invoice/features/employee/domain/usecases/get_employee_expiry_alerts_usecase.dart';
import 'package:xloop_invoice/injection_container.dart';
import 'package:xloop_invoice/core/widgets/modern_app_bar.dart';
import 'package:timeago/timeago.dart' as timeago;

class _DT {
  static const bgPage = Color(0xFFF4F6FB);
  static const brand = Color(0xFF4F46E5);
  static const brandDark = Color(0xFF312E81);
  static const danger = Color(0xFFDC2626);
  static const dangerBg = Color(0xFFFFF1F2);
  static const dangerBorder = Color(0xFFFFCDD2);
  static const warning = Color(0xFFD97706);
  static const warningBg = Color(0xFFFFFBEB);
  static const warningBorder = Color(0xFFFFE082);
  static const success = Color(0xFF16A34A);
  static const successBg = Color(0xFFF0FDF4);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);
  static const border = Color(0xFFE5E7EB);
}

class EmployeeExpiryTrackerScreen extends StatefulWidget {
  const EmployeeExpiryTrackerScreen({super.key});

  @override
  State<EmployeeExpiryTrackerScreen> createState() => _EmployeeExpiryTrackerScreenState();
}

class _EmployeeExpiryTrackerScreenState extends State<EmployeeExpiryTrackerScreen> {
  bool _isLoading = true;
  List<EmployeeExpiryAlert> _allAlerts = [];
  List<EmployeeExpiryAlert> _filteredAlerts = [];
  String _selectedType = 'All';
  final List<String> _types = ['All'];

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    try {
      final useCase = sl<GetEmployeeExpiryAlertsUseCase>();
      final alerts = await useCase(includeAll: true);
      _allAlerts = alerts;
      
      // Extract unique document types
      final Set<String> types = {'All'};
      for (var alert in alerts) {
        types.add(alert.documentType);
      }
      _types.clear();
      _types.addAll(types);
      
      _filterAlerts();
    } catch (e) {
      debugPrint('Error loading employee expiry alerts: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterAlerts() {
    if (_selectedType == 'All') {
      _filteredAlerts = List.from(_allAlerts);
    } else {
      _filteredAlerts = _allAlerts.where((a) => a.documentType == _selectedType).toList();
    }
    // Sort by days until expiry (closest first)
    _filteredAlerts.sort((a, b) => a.daysUntilExpiry.compareTo(b.daysUntilExpiry));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DT.bgPage,
      appBar: const ModernAppBar(
        title: 'Employee Document Tracker',
      ),
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
                          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                          physics: const BouncingScrollPhysics(),
                          itemCount: _filteredAlerts.length,
                          separatorBuilder: (_, __) => SizedBox(height: 12.h),
                          itemBuilder: (context, i) => _ExpiryAlertCard(alert: _filteredAlerts[i]),
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
            'Filter by Document',
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
                final count = type == 'All' 
                    ? _allAlerts.length 
                    : _allAlerts.where((a) => a.documentType == type).length;
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
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white.withOpacity(0.2) : _DT.brand.withOpacity(0.1),
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
                        ]
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedType = type;
                          _filterAlerts();
                        });
                      }
                    },
                    backgroundColor: Colors.white,
                    selectedColor: _DT.brand,
                    labelStyle: GoogleFonts.inter(
                      color: isSelected ? Colors.white : _DT.textSecondary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.r),
                      side: BorderSide(color: isSelected ? _DT.brand : _DT.border),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
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
            child: Icon(Icons.check_circle_outline, color: _DT.success, size: 48.sp),
          ),
          SizedBox(height: 16.h),
          Text(
            'No expiring documents found',
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

class _ExpiryAlertCard extends StatefulWidget {
  final EmployeeExpiryAlert alert;
  const _ExpiryAlertCard({required this.alert});

  @override
  State<_ExpiryAlertCard> createState() => _ExpiryAlertCardState();
}

class _ExpiryAlertCardState extends State<_ExpiryAlertCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.alert;
    final isExpired = a.daysUntilExpiry < 0;
    final isCritical = a.daysUntilExpiry >= 0 && a.daysUntilExpiry <= 15;
    
    final color = isExpired ? _DT.danger : (isCritical ? _DT.warning : _DT.brand);
    final bgColor = isExpired ? _DT.dangerBg : (isCritical ? _DT.warningBg : Colors.white);
    final borderColor = isExpired ? _DT.dangerBorder : (isCritical ? _DT.warningBorder : _DT.border);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _hovered ? bgColor : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: _hovered ? color.withOpacity(0.5) : borderColor),
          boxShadow: [
            if (_hovered)
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              )
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
                  Text(
                    a.employeeName,
                    style: GoogleFonts.inter(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: _DT.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
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
                  isExpired ? '${a.daysUntilExpiry.abs()} days ago' : 'Remaining',
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
