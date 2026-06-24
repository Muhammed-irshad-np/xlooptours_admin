import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:xloop_invoice/injection_container.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xloop_invoice/services/dev_database_sync_service.dart';
import 'package:xloop_invoice/features/employee/presentation/providers/employee_provider.dart';
import 'package:xloop_invoice/features/vehicle/presentation/providers/vehicle_provider.dart';
import 'package:xloop_invoice/features/customer/presentation/providers/customer_provider.dart';
import 'package:xloop_invoice/features/feedback/presentation/providers/feedback_provider.dart';
import 'package:xloop_invoice/features/notifications/presentation/providers/notification_provider.dart';
import 'package:xloop_invoice/features/auth/presentation/providers/auth_provider.dart';

class DevSyncDialog extends StatefulWidget {
  const DevSyncDialog({super.key});

  @override
  State<DevSyncDialog> createState() => _DevSyncDialogState();
}

class _DevSyncDialogState extends State<DevSyncDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  final ScrollController _scrollController = ScrollController();
  final List<String> _logs = [];

  bool _isSyncing = false;
  bool _isCompleted = false;
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _scrollController.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  void _startSync() {
    setState(() {
      _isSyncing = true;
      _isCompleted = false;
      _logs.clear();
      _logs.add("Initializing sync...");
    });
    _rotationController.repeat();

    final syncService = sl<DevDatabaseSyncService>();
    _subscription = syncService.syncAll().listen(
      (log) {
        if (mounted) {
          setState(() {
            _logs.add(log);
          });
          _scrollToBottom();
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _logs.add("\n[ERROR] Sync failed: $error");
            _isSyncing = false;
            _rotationController.stop();
          });
          _scrollToBottom();
        }
      },
      onDone: () async {
        if (mounted) {
          setState(() {
            _isSyncing = false;
            _isCompleted = true;
            _rotationController.stop();
          });
          _scrollToBottom();

          // Refresh all providers with the new synced data
          await _refreshData();
        }
      },
    );
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    setState(() {
      _logs.add("\nRefreshing dashboard data providers...");
    });
    _scrollToBottom();

    try {
      final vehicleProvider = context.read<VehicleProvider>();
      final authProvider = context.read<AuthProvider>();
      final isAdmin = authProvider.user?.isAdmin ?? false;

      // Refresh providers
      context.read<EmployeeProvider>().fetchAllEmployees();
      if (isAdmin) {
        context.read<CustomerProvider>().fetchAllCustomers();
      }
      context.read<FeedbackProvider>().fetchLatestFeedbacks();

      await Future.wait([
        vehicleProvider.fetchAllVehicles(),
        vehicleProvider.fetchAllMaintenanceTypes(),
      ]);

      if (mounted) {
        await context.read<NotificationProvider>().refreshAlerts(
          vehicles: vehicleProvider.vehicles,
          maintenanceTypes: vehicleProvider.maintenanceTypes,
        );
      }

      // Save last sync time
      final prefs = sl<SharedPreferences>();
      final now = DateTime.now();
      final formattedDate =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
      await prefs.setString('last_db_sync_time', formattedDate);

      if (mounted) {
        setState(() {
          _logs.add("Dashboard data refreshed successfully!");
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _logs.add(
            "Warning: Failed to refresh dashboard UI automatically: $e",
          );
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      elevation: 24,
      backgroundColor: Colors.white,
      child: Container(
        width: 600.w,
        padding: EdgeInsets.all(28.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Header
            Row(
              children: [
                AnimatedBuilder(
                  animation: _rotationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _rotationController.value * 2 * 3.14159,
                      child: child,
                    );
                  },
                  child: Icon(
                    Icons.sync_rounded,
                    size: 28.sp,
                    color: _isCompleted
                        ? Colors.green
                        : const Color(0xFF4F46E5),
                  ),
                ),
                SizedBox(width: 14.w),
                Text(
                  'Sync DEV Database from PROD',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 20.sp,
                    color: const Color(0xFF111827),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),

            // Warning and Logs Area
            if (!_isSyncing && _logs.isEmpty) ...[
              // Warning box
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: const Color(0xFFDC2626),
                      size: 22.sp,
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        'WARNING: This will clear all data in your local development database and replace it with the latest production data. This action is irreversible.',
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          color: const Color(0xFF991B1B),
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                'Collections to be copied: Settings, allowed_users, companies, counters, customers, employees, invoices, maintenance_types, notifications, settings, travelers, vat_filings, vehicle_makes, vehicles, xloop_company.',
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  color: const Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
            ] else ...[
              // Monospace Terminal Console
              Container(
                height: 300.h,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: const Color(0xFF334155)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(16.w),
                child: ClipRRect(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      Color logColor = const Color(
                        0xFF38BDF8,
                      ); // Blueish cyan default

                      if (log.startsWith("  Error") ||
                          log.contains("[ERROR]")) {
                        logColor = const Color(0xFFF87171); // Red
                      } else if (log.contains("Successfully") ||
                          log.contains("completed successfully") ||
                          log.contains("refreshed successfully")) {
                        logColor = const Color(0xFF4ADE80); // Green
                      } else if (log.startsWith("Processing") ||
                          log.startsWith("===")) {
                        logColor = const Color(0xFFFDBA74); // Orange
                      }

                      return Padding(
                        padding: EdgeInsets.only(bottom: 6.h),
                        child: Text(
                          log,
                          style: GoogleFonts.sourceCodePro(
                            color: logColor,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            SizedBox(height: 24.h),

            // Progress/Indicator
            if (_isSyncing) ...[
              const LinearProgressIndicator(
                color: Color(0xFF4F46E5),
                backgroundColor: Color(0xFFE5E7EB),
              ),
              SizedBox(height: 16.h),
            ],

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!_isSyncing && !_isCompleted) ...[
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 24.w,
                        vertical: 12.h,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      elevation: 2,
                    ),
                    onPressed: _startSync,
                    child: Text(
                      'Start Sync',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
                ] else ...[
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isCompleted
                          ? Colors.green
                          : const Color(0xFF6B7280),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 24.w,
                        vertical: 12.h,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      elevation: 2,
                    ),
                    onPressed: _isSyncing
                        ? null
                        : () => Navigator.pop(context, _isCompleted),
                    child: Text(
                      _isCompleted ? 'Done' : 'Close',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
