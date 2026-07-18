import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/petty_cash_provider.dart';
import '../providers/fund_account_provider.dart';
import '../../domain/entities/petty_cash_session_entity.dart';
import '../../domain/entities/fund_account_entity.dart';
import 'finance_dashboard_page.dart';

/// Public-facing mobile web form for coordinators to submit daily petty cash closing reports.
class CoordinatorClosingFormPage extends StatefulWidget {
  const CoordinatorClosingFormPage({super.key});

  @override
  State<CoordinatorClosingFormPage> createState() => _CoordinatorClosingFormPageState();
}

class _CoordinatorClosingFormPageState extends State<CoordinatorClosingFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  final _coordNameCtrl = TextEditingController();
  final _cashCtrl = TextEditingController();
  final _digitalCtrl = TextEditingController();
  final _otherCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _selectedAccountId;
  String? _closingSheetUrl;
  bool _uploadingSheet = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FundAccountProvider>().fetchAllAccounts().then((_) {
        final accounts = context.read<FundAccountProvider>().activeAccounts;
        final petty = accounts.where((a) => a.type == FundAccountType.pettyCash).toList();
        if (petty.isNotEmpty) {
          setState(() => _selectedAccountId = petty.first.id);
          context.read<PettyCashProvider>().loadSessions(petty.first.id);
        }
      });
    });
  }

  @override
  void dispose() {
    _coordNameCtrl.dispose();
    _cashCtrl.dispose();
    _digitalCtrl.dispose();
    _otherCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accProv = context.watch<FundAccountProvider>();
    final pettyProv = context.watch<PettyCashProvider>();
    final pettyAccounts = accProv.activeAccounts
        .where((a) => a.type == FundAccountType.pettyCash)
        .toList();

    final activeSession = pettyProv.currentSession;
    final formatter = NumberFormat('#,##0.00', 'en_US');

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          'Daily Petty Cash Closing',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 18.sp,
            color: FinDT.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_rounded,
            color: FinDT.textPrimary,
            size: 22.sp,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(28.w),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: FinDT.border),
            boxShadow: [
              BoxShadow(
                color: FinDT.shadow,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Petty Cash Closing Declaration',
                    style: GoogleFonts.inter(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: FinDT.textPrimary,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Coordinators: Declare end-of-day cash and STC Pay balances below.',
                    style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textSecondary),
                  ),
                  SizedBox(height: 24.h),

                      // Select Account
                      _buildLabel('Select Petty Cash Account *'),
                      DropdownButtonFormField<String>(
                        value: _selectedAccountId,
                        decoration: _inputDecoration('Choose account'),
                        items: pettyAccounts.map((a) {
                          return DropdownMenuItem(
                            value: a.id,
                            child: Text('${a.name} (${a.code})'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedAccountId = val);
                            pettyProv.loadSessions(val);
                          }
                        },
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      SizedBox(height: 16.h),

                      // Coordinator Name
                      _buildLabel('Coordinator Name *'),
                      TextFormField(
                        controller: _coordNameCtrl,
                        decoration: _inputDecoration('Enter your full name'),
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      SizedBox(height: 20.h),

                      // Active Session Check
                      if (activeSession == null) ...[
                        Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: FinDT.danger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(color: FinDT.danger.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: FinDT.danger, size: 20.sp),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Text(
                                  'There is no active session open for this petty cash account. Please contact admin to open a daily session.',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                    color: FinDT.danger,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 20.h),
                      ] else ...[
                        // Session info
                        Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: FinDT.brand.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(color: FinDT.brand.withValues(alpha: 0.15)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Active Session Info',
                                style: GoogleFonts.inter(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                  color: FinDT.brand,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              _buildSessionRow('Opening Balance:', '${formatter.format(activeSession.openingBalance)} SAR'),
                              _buildSessionRow('Expenses Today:', '${formatter.format(activeSession.totalExpenses)} SAR'),
                              _buildSessionRow('Expected Closing:', '${formatter.format(activeSession.expectedClosingBalance)} SAR', bold: true),
                            ],
                          ),
                        ),
                        SizedBox(height: 20.h),

                        // Declared Balances
                        _buildLabel('Physical Cash in Hand *'),
                        TextFormField(
                          controller: _cashCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                          ],
                          decoration: _inputDecoration('0.00'),
                          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                        SizedBox(height: 16.h),

                        _buildLabel('STC Pay Balance'),
                        TextFormField(
                          controller: _digitalCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                          ],
                          decoration: _inputDecoration('0.00'),
                        ),
                        SizedBox(height: 16.h),

                        _buildLabel('Other Digital Balance'),
                        TextFormField(
                          controller: _otherCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                          ],
                          decoration: _inputDecoration('0.00'),
                        ),
                        SizedBox(height: 20.h),

                        // Upload Sheet
                        _buildLabel('Daily Sheet PDF / Image *'),
                        _buildSheetPicker(pettyProv, activeSession.id),
                        SizedBox(height: 16.h),

                        // Notes
                        _buildLabel('Coordinator Notes'),
                        TextFormField(
                          controller: _notesCtrl,
                          maxLines: 2,
                          decoration: _inputDecoration('Any closing notes...'),
                        ),
                        SizedBox(height: 28.h),

                        // Submit Button
                        _buildSubmitButton(pettyProv, activeSession),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: FinDT.textPrimary),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return _inputStyle(hint);
  }

  InputDecoration _inputStyle(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textMuted),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: const BorderSide(color: Color(0xFF13B1F2), width: 1.5),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      isDense: true,
    );
  }

  Widget _buildSessionRow(String label, String val, {bool bold = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textSecondary)),
          Text(
            val,
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: bold ? FinDT.brand : FinDT.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetPicker(PettyCashProvider provider, String sessionId) {
    if (_uploadingSheet) {
      return Container(
        height: 120.h,
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Center(child: CircularProgressIndicator(color: Color(0xFF13B1F2))),
      );
    }

    if (_closingSheetUrl != null) {
      return Container(
        height: 120.h,
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Stack(
          children: [
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, color: FinDT.success, size: 24.sp),
                  SizedBox(width: 8.w),
                  Text(
                    'Sheet attached successfully',
                    style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: FinDT.success),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 8.w,
              top: 8.h,
              child: IconButton(
                onPressed: () => setState(() => _closingSheetUrl = null),
                icon: Icon(Icons.cancel, color: FinDT.danger, size: 20.sp),
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => _pickAndUploadSheet(provider, sessionId),
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        height: 120.h,
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.upload_file_outlined, size: 32.sp, color: const Color(0xFF13B1F2)),
            SizedBox(height: 8.h),
            Text(
              'Upload Daily Summary Sheet',
              style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: const Color(0xFF13B1F2)),
            ),
            SizedBox(height: 4.h),
            Text(
              'Capture page or upload PDF/Image summary',
              style: GoogleFonts.inter(fontSize: 10.sp, color: FinDT.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadSheet(PettyCashProvider provider, String sessionId) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    setState(() => _uploadingSheet = true);

    try {
      final url = await provider.uploadClosingSheet(file, sessionId);
      setState(() => _closingSheetUrl = url);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload: $e')),
      );
    } finally {
      setState(() => _uploadingSheet = false);
    }
  }

  Widget _buildSubmitButton(PettyCashProvider provider, PettyCashSessionEntity activeSession) {
    return SizedBox(
      width: double.infinity,
      height: 48.h,
      child: ElevatedButton(
        onPressed: _isSaving ? null : () => _submitForm(provider, activeSession),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF13B1F2),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
          elevation: 0,
        ),
        child: _isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                'Submit Daily Closing',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13.sp),
              ),
      ),
    );
  }

  Future<void> _submitForm(PettyCashProvider provider, PettyCashSessionEntity session) async {
    if (!_formKey.currentState!.validate()) return;
    if (_closingSheetUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a daily sheet file.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final cash = double.parse(_cashCtrl.text);
      final digital = double.tryParse(_digitalCtrl.text) ?? 0.0;
      final other = double.tryParse(_otherCtrl.text) ?? 0.0;
      final closing = cash + digital + other;

      final closed = session.copyWith(
        closingBalance: closing,
        cashInHand: cash,
        stcPayBalance: digital,
        otherDigitalBalance: other,
        closingSheetUrl: _closingSheetUrl,
        closedBy: _coordNameCtrl.text.toUpperCase().trim(),
        status: PettyCashSessionStatus.closed,
      );

      await provider.closeSession(closed);

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error closing: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: FinDT.success, size: 24.sp),
            SizedBox(width: 8.w),
            const Text('Closing Submitted!'),
          ],
        ),
        content: const Text(
          'Your Daily Petty Cash Closing has been successfully declared and submitted to Admin for verification. You can close this page.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resetForm();
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF13B1F2)),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    _coordNameCtrl.clear();
    _cashCtrl.clear();
    _digitalCtrl.clear();
    _otherCtrl.clear();
    _notesCtrl.clear();
    setState(() {
      _closingSheetUrl = null;
    });
  }
}
