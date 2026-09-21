
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../finance/presentation/providers/finance_provider.dart';
import '../../domain/entities/odometer_reading_entity.dart';
import '../../domain/entities/odometer_validation.dart';
import '../../domain/entities/vehicle_entity.dart';
import '../../domain/usecases/record_odometer_reading_usecase.dart';
import '../providers/odometer_provider.dart';

class _T {
  static const brand = Color(0xFF4F46E5);
  static const danger = Color(0xFFDC2626);
  static const dangerBg = Color(0xFFFFF1F2);
  static const dangerBorder = Color(0xFFFFCDD2);
  static const warning = Color(0xFFD97706);
  static const warningBg = Color(0xFFFFFBEB);
  static const warningBorder = Color(0xFFFDE68A);
  static const success = Color(0xFF16A34A);
  static const successBg = Color(0xFFF0FDF4);
  static const successBorder = Color(0xFFBBF7D0);
  static const infoBg = Color(0xFFEEF2FF);
  static const infoBorder = Color(0xFFC7D2FE);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);
  static const border = Color(0xFFE5E7EB);
  static const surfaceMuted = Color(0xFFF9FAFB);
}

/// Groups digits as the user types, so an extra keystroke is visible.
///
/// `450000` reads as an ordinary number; `450,000` next to a remembered
/// `45,000` is obviously wrong at a glance. This is the cheapest defence in the
/// whole feature.
class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }

    // Preserve the caret by counting digits to its left rather than characters,
    // so inserted separators do not push it around.
    final caret = newValue.selection.baseOffset;
    var digitsBeforeCaret = 0;
    for (var i = 0; i < caret && i < newValue.text.length; i++) {
      if (RegExp(r'[0-9]').hasMatch(newValue.text[i])) digitsBeforeCaret++;
    }

    final formatted = groupDigits(digits);

    var offset = formatted.length;
    var seen = 0;
    for (var i = 0; i < formatted.length; i++) {
      if (RegExp(r'[0-9]').hasMatch(formatted[i])) {
        seen++;
        if (seen == digitsBeforeCaret) {
          offset = i + 1;
          break;
        }
      }
    }
    if (digitsBeforeCaret == 0) offset = 0;

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  static String groupDigits(String digits) {
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return buf.toString();
  }
}

String formatKm(num value) =>
    _ThousandsFormatter.groupDigits(value.round().abs().toString());

/// The single odometer entry surface for the whole app.
///
/// Deliberately **not** pre-filled with the previous reading. Editing an
/// existing number in place is the most typo-prone input pattern there is — a
/// dropped or duplicated digit is invisible. The previous reading is shown as
/// read-only context instead, and a live delta tells the entrant what their
/// number implies in km/day while they are still typing, which is the one thing
/// a human can actually sanity-check.
class OdometerEntryDialog extends StatefulWidget {
  final VehicleEntity vehicle;
  final OdometerSource source;

  /// Prefilled when another form already captured a value (e.g. a maintenance
  /// record). Still shown for confirmation rather than saved blind.
  final int? initialValue;

  final String? sourceRefId;

  const OdometerEntryDialog({
    super.key,
    required this.vehicle,
    this.source = OdometerSource.weeklyUpdate,
    this.initialValue,
    this.sourceRefId,
  });

  /// Opens the dialog. Returns the recorded reading, or null if cancelled.
  static Future<OdometerReadingEntity?> show(
    BuildContext context, {
    required VehicleEntity vehicle,
    OdometerSource source = OdometerSource.weeklyUpdate,
    int? initialValue,
    String? sourceRefId,
  }) {
    return showDialog<OdometerReadingEntity>(
      context: context,
      barrierDismissible: false,
      builder: (_) => OdometerEntryDialog(
        vehicle: vehicle,
        source: source,
        initialValue: initialValue,
        sourceRefId: sourceRefId,
      ),
    );
  }

  @override
  State<OdometerEntryDialog> createState() => _OdometerEntryDialogState();
}

class _OdometerEntryDialogState extends State<OdometerEntryDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  DateTime _readingAt = DateTime.now();
  OdometerValidationResult? _validation;
  XFile? _photo;
  bool _confirmed = false;
  bool _saving = false;
  double _fuelSpendInWindow = 0;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null && widget.initialValue! > 0) {
      _controller.text = formatKm(widget.initialValue!);
    }
    _controller.addListener(_revalidate);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _controller.removeListener(_revalidate);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final provider = context.read<OdometerProvider>();
    await provider.loadReadings(widget.vehicle.id);
    await provider.loadFleetBaseline();
    _computeFuelSpend();
    if (mounted) _revalidate();
  }

  /// Sums fuel spend recorded for this vehicle since the last reading.
  ///
  /// This is what turns "the odometer barely moved" from an unverifiable claim
  /// into a contradiction the app can point at.
  void _computeFuelSpend() {
    final last = context.read<OdometerProvider>().lastAcceptedFor(
      widget.vehicle,
    );
    if (last == null) return;

    FinanceProvider? finance;
    try {
      finance = context.read<FinanceProvider>();
    } catch (_) {
      return; // Finance not in scope here; the check simply does not run.
    }

    var total = 0.0;
    for (final e in finance.expenses) {
      if (e.vehicleId != widget.vehicle.id) continue;
      if (!e.expenseType.toLowerCase().contains('fuel')) continue;
      if (e.date.isBefore(last.readingAt)) continue;
      if (e.date.isAfter(_readingAt)) continue;
      total += e.amount;
    }
    _fuelSpendInWindow = total;
  }

  int? get _enteredValue {
    final digits = _controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return int.tryParse(digits);
  }

  void _revalidate() {
    final value = _enteredValue;
    if (value == null) {
      setState(() => _validation = null);
      return;
    }
    final result = context.read<OdometerProvider>().validate(
      vehicle: widget.vehicle,
      value: value,
      readingAt: _readingAt,
      fuelSpendInWindow: _fuelSpendInWindow,
      source: widget.source,
    );
    setState(() {
      _validation = result;
      // Requirements changed under the user; do not keep a stale confirmation.
      if (!result.requiresConfirmation) _confirmed = false;
    });
  }

  void _applySuggestion(OdometerSuggestion suggestion) {
    _controller.text = formatKm(suggestion.value);
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1600,
      );
      if (picked != null) setState(() => _photo = picked);
    } catch (e) {
      if (mounted) {
        setState(() => _saveError = 'Could not open the camera: $e');
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _readingAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      helpText: 'When was the cluster read?',
    );
    if (picked != null) {
      setState(() => _readingAt = picked);
      _computeFuelSpend();
      _revalidate();
    }
  }

  bool get _canSave {
    if (_saving) return false;
    final value = _enteredValue;
    if (value == null) return false;
    final v = _validation;
    if (v == null) return false;
    if (!v.canSave) return false;
    if (v.requiresConfirmation && !_confirmed) return false;
    if (v.requiresPhoto && _photo == null) return false;
    return true;
  }

  Future<void> _save() async {
    final value = _enteredValue;
    final validation = _validation;
    if (value == null || validation == null) return;

    setState(() {
      _saving = true;
      _saveError = null;
    });

    final provider = context.read<OdometerProvider>();
    final auth = context.read<AuthProvider>();
    final user = auth.user;

    try {
      String? photoUrl;
      if (_photo != null) {
        photoUrl = await provider.uploadPhoto(
          _photo!,
          widget.vehicle.id,
          DateTime.now().millisecondsSinceEpoch.toString(),
        );
      }

      final result = await provider.record(
        vehicle: widget.vehicle,
        value: value,
        source: widget.source,
        readingAt: _readingAt,
        sourceRefId: widget.sourceRefId,
        enteredByUid: user?.id,
        enteredByName: user?.displayName ?? user?.email,
        photoUrl: photoUrl,
        userConfirmed: _confirmed,
        fuelSpendInWindow: _fuelSpendInWindow,
      );

      if (mounted) Navigator.of(context).pop(result.reading);
    } on OdometerReadingRejected catch (e) {
      setState(() {
        _saving = false;
        _validation = e.validation;
        _saveError = e.validation.message;
      });
    } catch (e) {
      setState(() {
        _saving = false;
        _saveError = 'Could not save the reading: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OdometerProvider>();
    final last = provider.lastAcceptedFor(widget.vehicle);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480.w),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              SizedBox(height: 20.h),
              _lastReadingContext(last),
              SizedBox(height: 18.h),
              _field(),
              SizedBox(height: 12.h),
              _feedback(),
              _suggestions(),
              _evidence(),
              if (_saveError != null) ...[
                SizedBox(height: 12.h),
                Text(
                  _saveError!,
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: _T.danger,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              SizedBox(height: 22.h),
              _actions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: _T.brand.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(Icons.speed_rounded, color: _T.brand, size: 22.sp),
        ),
        SizedBox(width: 14.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Record Odometer',
                style: GoogleFonts.inter(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: _T.textPrimary,
                ),
              ),
              Text(
                '${widget.vehicle.make} ${widget.vehicle.model} · '
                '${widget.vehicle.plateNumber}',
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  color: _T.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _lastReadingContext(OdometerReadingEntity? last) {
    final daysAgo = last == null
        ? null
        : DateTime.now().difference(last.readingAt).inDays;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: _T.surfaceMuted,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: _T.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  last == null ? 'No previous reading' : 'Last reading',
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: _T.textMuted,
                    letterSpacing: 0.4,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  last == null
                      ? 'This will become the baseline'
                      : '${formatKm(last.value)} km'
                            '${daysAgo == null ? '' : '  ·  ${daysAgo == 0 ? 'today' : '$daysAgo day${daysAgo == 1 ? '' : 's'} ago'}'}',
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: _T.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (last != null)
                  Text(
                    'via ${last.source.label}'
                    '${last.enteredByName == null ? '' : ' · ${last.enteredByName}'}',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      color: _T.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _pickDate,
            icon: Icon(Icons.event_rounded, size: 15.sp),
            label: Text(
              _isToday(_readingAt)
                  ? 'Today'
                  : '${_readingAt.day.toString().padLeft(2, '0')}/'
                        '${_readingAt.month.toString().padLeft(2, '0')}',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(foregroundColor: _T.brand),
          ),
        ],
      ),
    );
  }

  Widget _field() {
    final severity = _validation?.severity;
    final accent = _accentFor(severity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reading on the cluster now',
          style: GoogleFonts.inter(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: _T.textPrimary,
          ),
        ),
        SizedBox(height: 8.h),
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            _ThousandsFormatter(),
          ],
          style: GoogleFonts.inter(
            fontSize: 22.sp,
            fontWeight: FontWeight.w700,
            color: _T.textPrimary,
            letterSpacing: 1.2,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: GoogleFonts.inter(
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
              color: _T.textMuted.withValues(alpha: 0.5),
            ),
            suffixText: 'km',
            suffixStyle: GoogleFonts.inter(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: _T.textSecondary,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: _T.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: accent ?? _T.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: accent ?? _T.brand, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 16.h,
            ),
          ),
        ),
      ],
    );
  }

  /// The live delta. Rebuilt on every keystroke, and the reason a human can
  /// catch their own slip: nobody can validate "47,240 km", but everybody knows
  /// whether their vehicle did 155 km/day or 1,550.
  Widget _feedback() {
    final v = _validation;
    if (v == null) {
      return Text(
        'Type the full reading. You will see the distance covered as you go.',
        style: GoogleFonts.inter(fontSize: 12.sp, color: _T.textMuted),
      );
    }

    final (bg, borderColor, fg, icon) = switch (v.severity) {
      OdometerSeverity.ok => (
        _T.successBg,
        _T.successBorder,
        _T.success,
        Icons.check_circle_rounded,
      ),
      OdometerSeverity.info => (
        _T.infoBg,
        _T.infoBorder,
        _T.brand,
        Icons.info_rounded,
      ),
      OdometerSeverity.warn => (
        _T.warningBg,
        _T.warningBorder,
        _T.warning,
        Icons.warning_amber_rounded,
      ),
      OdometerSeverity.block => (
        _T.dangerBg,
        _T.dangerBorder,
        _T.danger,
        Icons.block_rounded,
      ),
    };

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18.sp, color: fg),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v.title,
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  v.message,
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    height: 1.45,
                    color: _T.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// One-tap corrections for a suspected digit slip.
  Widget _suggestions() {
    final suggestions = _validation?.suggestions ?? const [];
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Did you mean',
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: _T.textMuted,
              letterSpacing: 0.4,
            ),
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: suggestions
                .map(
                  (s) => InkWell(
                    onTap: () => _applySuggestion(s),
                    borderRadius: BorderRadius.circular(10.r),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 9.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(color: _T.brand, width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${formatKm(s.value)} km',
                            style: GoogleFonts.inter(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: _T.brand,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          Text(
                            '${s.dailyRate.round()} km/day',
                            style: GoogleFonts.inter(
                              fontSize: 10.sp,
                              color: _T.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  /// Photo and confirmation, shown only when the reading is out of band.
  ///
  /// Demanding a photo on every entry teaches people to photograph anything and
  /// slows the weekly round until it gets skipped. Demanding one exactly when
  /// the number is disputable keeps the evidence where it is worth having.
  Widget _evidence() {
    final v = _validation;
    if (v == null || (!v.requiresPhoto && !v.requiresConfirmation)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(top: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (v.requiresPhoto) ...[
            Text(
              'Photo of the cluster',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: _T.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                if (!kIsWeb) ...[
                  OutlinedButton.icon(
                    onPressed: () => _pickPhoto(ImageSource.camera),
                    icon: Icon(Icons.photo_camera_rounded, size: 16.sp),
                    label: Text(
                      'Camera',
                      style: GoogleFonts.inter(fontSize: 12.sp),
                    ),
                  ),
                  SizedBox(width: 8.w),
                ],
                OutlinedButton.icon(
                  onPressed: () => _pickPhoto(ImageSource.gallery),
                  icon: Icon(Icons.image_rounded, size: 16.sp),
                  label: Text(
                    'Upload',
                    style: GoogleFonts.inter(fontSize: 12.sp),
                  ),
                ),
                SizedBox(width: 10.w),
                if (_photo != null)
                  Icon(
                    Icons.check_circle_rounded,
                    color: _T.success,
                    size: 18.sp,
                  ),
              ],
            ),
            if (_photo != null)
              Padding(
                padding: EdgeInsets.only(top: 6.h),
                child: Text(
                  _photo!.name,
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    color: _T.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            SizedBox(height: 12.h),
          ],
          if (v.requiresConfirmation)
            InkWell(
              onTap: () => setState(() => _confirmed = !_confirmed),
              borderRadius: BorderRadius.circular(10.r),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 22.w,
                      height: 22.w,
                      child: Checkbox(
                        value: _confirmed,
                        onChanged: (val) =>
                            setState(() => _confirmed = val ?? false),
                        activeColor: _T.brand,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        'I read this value directly off the cluster and it is '
                        'correct.',
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          height: 1.4,
                          color: _T.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SizedBox(height: 6.h),
          Text(
            'This reading will be saved and held for review before it affects '
            'maintenance alerts.',
            style: GoogleFonts.inter(fontSize: 11.sp, color: _T.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(
              color: _T.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(width: 12.w),
        ElevatedButton(
          onPressed: _canSave ? _save : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _T.brand,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _T.border,
            disabledForegroundColor: _T.textMuted,
            elevation: 0,
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
          child: _saving
              ? SizedBox(
                  width: 16.w,
                  height: 16.w,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Text(
                  _validation?.severity == OdometerSeverity.warn
                      ? 'Save for review'
                      : 'Save reading',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.sp,
                  ),
                ),
        ),
      ],
    );
  }

  Color? _accentFor(OdometerSeverity? severity) => switch (severity) {
    OdometerSeverity.ok => _T.success,
    OdometerSeverity.warn => _T.warning,
    OdometerSeverity.block => _T.danger,
    _ => null,
  };

  static bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}
