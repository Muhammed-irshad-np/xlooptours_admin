import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/app_snack_bar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/odometer_reading_entity.dart';
import '../../domain/entities/odometer_review_item.dart';
import '../../domain/entities/vehicle_entity.dart';
import '../providers/odometer_provider.dart';
import '../providers/vehicle_provider.dart';
import '../widgets/odometer_entry_dialog.dart';

class _T {
  static const bgPage = Color(0xFFF4F6FB);
  static const brand = Color(0xFF4F46E5);
  static const danger = Color(0xFFDC2626);
  static const dangerBg = Color(0xFFFFF1F2);
  static const warning = Color(0xFFD97706);
  static const warningBg = Color(0xFFFFFBEB);
  static const success = Color(0xFF16A34A);
  static const info = Color(0xFF2563EB);
  static const infoBg = Color(0xFFEFF6FF);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);
  static const border = Color(0xFFE5E7EB);
}

/// Where questionable odometer readings get settled.
///
/// Quarantined readings sit here instead of silently feeding the maintenance
/// maths. A reviewer can accept one, reject it, or replace it with the true
/// value — and because the log is append-only, every one of those actions is
/// recorded rather than overwriting what was there.
class OdometerReviewScreen extends StatefulWidget {
  const OdometerReviewScreen({super.key});

  @override
  State<OdometerReviewScreen> createState() => _OdometerReviewScreenState();
}

class _OdometerReviewScreenState extends State<OdometerReviewScreen> {
  bool _showStale = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final vehicles = context.read<VehicleProvider>().vehicles;
    await context.read<OdometerProvider>().loadReviewQueue(vehicles);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OdometerProvider>();
    final items = provider.reviewQueue
        .where((i) => _showStale || i.reason != OdometerReviewReason.stale)
        .toList();

    return Scaffold(
      backgroundColor: _T.bgPage,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Odometer Review',
          style: GoogleFonts.inter(
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
            color: _T.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: _showStale ? 'Hide stale vehicles' : 'Show stale vehicles',
            onPressed: () => setState(() => _showStale = !_showStale),
            icon: Icon(
              _showStale
                  ? Icons.filter_alt_rounded
                  : Icons.filter_alt_off_rounded,
              size: 20.sp,
              color: _T.textSecondary,
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: Icon(
              Icons.refresh_rounded,
              size: 20.sp,
              color: _T.textSecondary,
            ),
          ),
        ],
      ),
      body: provider.isLoading && items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? _empty()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: EdgeInsets.all(16.w),
                itemCount: items.length,
                separatorBuilder: (_, _) => SizedBox(height: 12.h),
                itemBuilder: (_, i) => _ReviewCard(
                  item: items[i],
                  onAccept: () => _accept(items[i]),
                  onReject: () => _reject(items[i]),
                  onCorrect: () => _correct(items[i]),
                  onCapture: () => _capture(items[i].vehicle),
                ),
              ),
            ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 44.sp, color: _T.success),
          SizedBox(height: 12.h),
          Text(
            'Nothing to review',
            style: GoogleFonts.inter(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: _T.textPrimary,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Every odometer reading is inside its plausible range.',
            style: GoogleFonts.inter(fontSize: 12.sp, color: _T.textMuted),
          ),
        ],
      ),
    );
  }

  ({String? uid, String? name}) get _reviewer {
    final user = context.read<AuthProvider>().user;
    return (uid: user?.id, name: user?.displayName ?? user?.email);
  }

  Future<void> _accept(OdometerReviewItem item) async {
    final reading = item.reading;
    if (reading == null) return;
    final r = _reviewer;
    final updated = await context.read<OdometerProvider>().acceptReading(
      vehicle: item.vehicle,
      reading: reading,
      reviewerUid: r.uid,
      reviewerName: r.name,
      note: 'Confirmed as correct during review.',
    );
    _afterReview(updated, 'Reading accepted');
  }

  Future<void> _reject(OdometerReviewItem item) async {
    final reading = item.reading;
    if (reading == null) return;

    final note = await _askForNote(
      title: 'Reject this reading?',
      body:
          'It stays in the log for audit but stops counting. The vehicle '
          'odometer falls back to the last good reading.',
      confirmLabel: 'Reject',
      danger: true,
    );
    if (note == null || !mounted) return;

    final r = _reviewer;
    final updated = await context.read<OdometerProvider>().rejectReading(
      vehicle: item.vehicle,
      reading: reading,
      reviewerUid: r.uid,
      reviewerName: r.name,
      note: note.isEmpty ? null : note,
    );
    _afterReview(updated, 'Reading rejected');
  }

  Future<void> _correct(OdometerReviewItem item) async {
    final reading = item.reading;
    if (reading == null) return;

    final corrected = await _askForValue(reading);
    if (corrected == null || !mounted) return;

    final r = _reviewer;
    final updated = await context.read<OdometerProvider>().correctReading(
      vehicle: item.vehicle,
      original: reading,
      correctedValue: corrected,
      reviewerUid: r.uid,
      reviewerName: r.name,
      note: 'Corrected from ${formatKm(reading.value)} km during review.',
    );
    _afterReview(updated, 'Reading corrected');
  }

  Future<void> _capture(VehicleEntity vehicle) async {
    final reading = await OdometerEntryDialog.show(
      context,
      vehicle: vehicle,
      source: OdometerSource.weeklyUpdate,
    );
    if (reading != null && mounted) {
      await _load();
      if (mounted) AppSnackBar.showSuccess(context, 'Odometer recorded');
    }
  }

  void _afterReview(VehicleEntity? updated, String message) {
    if (!mounted) return;
    if (updated != null) {
      context.read<VehicleProvider>().applyVehicleLocally(updated);
    }
    AppSnackBar.showSuccess(context, message);
    _load();
  }

  Future<String?> _askForNote({
    required String title,
    required String body,
    required String confirmLabel,
    bool danger = false,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              body,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: _T.textSecondary,
                height: 1.5,
              ),
            ),
            SizedBox(height: 14.h),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              style: GoogleFonts.inter(fontSize: 13.sp),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: danger ? _T.danger : _T.brand,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<int?> _askForValue(OdometerReadingEntity reading) async {
    final controller = TextEditingController();
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Text(
          'Correct this reading',
          style: GoogleFonts.inter(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recorded as ${formatKm(reading.value)} km by '
              '${reading.enteredByName ?? 'an unknown user'}. The original is '
              'kept and linked to your correction.',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: _T.textSecondary,
                height: 1.5,
              ),
            ),
            SizedBox(height: 14.h),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'True reading',
                suffixText: 'km',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              style: GoogleFonts.inter(fontSize: 14.sp),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = int.tryParse(controller.text);
              if (v != null && v > 0) Navigator.pop(ctx, v);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _T.brand,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save correction'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
}

class _ReviewCard extends StatelessWidget {
  final OdometerReviewItem item;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onCorrect;
  final VoidCallback onCapture;

  const _ReviewCard({
    required this.item,
    required this.onAccept,
    required this.onReject,
    required this.onCorrect,
    required this.onCapture,
  });

  @override
  Widget build(BuildContext context) {
    final v = item.vehicle;
    final reading = item.reading;
    final isStale = item.reason == OdometerReviewReason.stale;

    final (accent, accentBg) = switch (item.reason) {
      OdometerReviewReason.quarantined => (_T.warning, _T.warningBg),
      OdometerReviewReason.crossSourceConflict => (_T.danger, _T.dangerBg),
      OdometerReviewReason.stale => (_T.info, _T.infoBg),
    };

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: _T.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: accentBg,
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  item.reason.label,
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
              const Spacer(),
              if (reading?.photoUrl != null)
                Icon(
                  Icons.photo_camera_rounded,
                  size: 15.sp,
                  color: _T.textMuted,
                ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            '${v.make} ${v.model}  ·  ${v.plateNumber}',
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: _T.textPrimary,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            item.explanation,
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              height: 1.5,
              color: _T.textSecondary,
            ),
          ),
          if (reading != null && !isStale) ...[
            SizedBox(height: 10.h),
            Text(
              'Entered by ${reading.enteredByName ?? 'unknown'} '
              'via ${reading.source.label}'
              '${reading.userConfirmed ? ' · confirmed at entry' : ''}',
              style: GoogleFonts.inter(fontSize: 11.sp, color: _T.textMuted),
            ),
          ],
          SizedBox(height: 14.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: isStale
                ? [
                    ElevatedButton.icon(
                      onPressed: onCapture,
                      icon: Icon(Icons.speed_rounded, size: 15.sp),
                      label: Text(
                        'Record reading',
                        style: GoogleFonts.inter(fontSize: 12.sp),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _T.brand,
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                    ),
                  ]
                : [
                    ElevatedButton.icon(
                      onPressed: onAccept,
                      icon: Icon(Icons.check_rounded, size: 15.sp),
                      label: Text(
                        'Accept',
                        style: GoogleFonts.inter(fontSize: 12.sp),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _T.success,
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: onCorrect,
                      icon: Icon(Icons.edit_rounded, size: 15.sp),
                      label: Text(
                        'Correct',
                        style: GoogleFonts.inter(fontSize: 12.sp),
                      ),
                      style: OutlinedButton.styleFrom(foregroundColor: _T.brand),
                    ),
                    OutlinedButton.icon(
                      onPressed: onReject,
                      icon: Icon(Icons.close_rounded, size: 15.sp),
                      label: Text(
                        'Reject',
                        style: GoogleFonts.inter(fontSize: 12.sp),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _T.danger,
                      ),
                    ),
                  ],
          ),
        ],
      ),
    );
  }
}
