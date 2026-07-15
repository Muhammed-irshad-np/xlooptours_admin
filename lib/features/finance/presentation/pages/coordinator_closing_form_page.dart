import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:xloop_invoice/features/finance/domain/entities/fund_account_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/petty_cash_session_entity.dart';
import 'package:xloop_invoice/features/finance/presentation/providers/fund_account_provider.dart';
import 'package:xloop_invoice/features/finance/presentation/providers/petty_cash_provider.dart';

/// Public web/mobile form for coordinators to report daily petty cash closing.
class CoordinatorClosingFormPage extends StatefulWidget {
  const CoordinatorClosingFormPage({super.key});

  @override
  State<CoordinatorClosingFormPage> createState() => _CoordinatorClosingFormPageState();
}

class _CoordinatorClosingFormPageState extends State<CoordinatorClosingFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _coordinatorNameController = TextEditingController();
  final _cashController = TextEditingController();
  final _stcController = TextEditingController(text: '0.0');
  final _otherController = TextEditingController(text: '0.0');
  final _notesController = TextEditingController();

  String? _selectedAccountId;
  XFile? _closingSheetFile;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final fap = context.read<FundAccountProvider>();
      fap.fetchAllAccounts().then((_) {
        final pcAccounts = fap.accounts.where((a) => a.type == FundAccountType.pettyCash).toList();
        if (pcAccounts.isNotEmpty) {
          setState(() {
            _selectedAccountId = pcAccounts.first.id;
          });
          context.read<PettyCashProvider>().loadSessions(pcAccounts.first.id);
        }
      });
    });
  }

  void _onAccountChanged(String? accountId) {
    if (accountId != null) {
      setState(() {
        _selectedAccountId = accountId;
        _closingSheetFile = null;
      });
      context.read<PettyCashProvider>().loadSessions(accountId);
    }
  }

  Future<void> _pickFile() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      setState(() {
        _closingSheetFile = image;
      });
    }
  }

  Future<void> _submitClosing() async {
    if (!_formKey.currentState!.validate()) return;

    final pettyCashProvider = context.read<PettyCashProvider>();
    final session = pettyCashProvider.currentSession;

    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No active daily session open for this account', style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      String? closingSheetUrl;
      if (_closingSheetFile != null) {
        closingSheetUrl = await pettyCashProvider.uploadClosingSheet(_closingSheetFile!, session.id);
      }

      final double actualCash = double.parse(_cashController.text);
      final double stc = double.tryParse(_stcController.text) ?? 0.0;
      final double other = double.tryParse(_otherController.text) ?? 0.0;
      final double closingBal = actualCash + stc + other;

      final closedSession = session.copyWith(
        closedBy: _coordinatorNameController.text.trim(),
        closingBalance: closingBal,
        cashInHand: actualCash,
        stcPayBalance: stc,
        otherDigitalBalance: other,
        closingSheetUrl: closingSheetUrl,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      await pettyCashProvider.closeSession(closedSession);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
            icon: Icon(Icons.check_circle, color: const Color(0xFF10B981), size: 48.sp),
            title: Text('Daily Petty Cash Closed', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            content: Text(
              'Daily petty cash closing for ${DateFormat('dd MMM yyyy').format(session.date)} has been reported.\nClosing Balance: ${closingBal.toStringAsFixed(2)} SAR',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13.sp),
            ),
            actions: [
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Done', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit daily closing: $e', style: GoogleFonts.inter()), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fundAccountProvider = context.watch<FundAccountProvider>();
    final pettyCashProvider = context.watch<PettyCashProvider>();

    final pcAccounts = fundAccountProvider.accounts.where((a) => a.type == FundAccountType.pettyCash).toList();
    final activeSession = pettyCashProvider.currentSession;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          'Daily Petty Cash Closing',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16.sp, color: const Color(0xFF111827)),
        ),
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextField(
                            _coordinatorNameController,
                            'Coordinator Full Name',
                            validator: (v) => v!.isEmpty ? 'Enter your name' : null,
                          ),
                          SizedBox(height: 16.h),
                          _buildDropdownField<String>(
                            label: 'Select Petty Cash Account',
                            value: _selectedAccountId,
                            items: pcAccounts.map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} (${a.code})'))).toList(),
                            onChanged: _onAccountChanged,
                            validator: (v) => v == null ? 'Select petty cash account' : null,
                          ),
                          SizedBox(height: 16.h),
                          if (activeSession == null) ...[
                            Container(
                              padding: EdgeInsets.all(16.w),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1F2),
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(color: const Color(0xFFFFCDD2)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline, color: const Color(0xFFEF4444), size: 20.sp),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: Text(
                                      'There is no active session open for this petty cash account. Please ask the administrator to open a session.',
                                      style: GoogleFonts.inter(fontSize: 12.sp, color: const Color(0xFF991B1B)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            Container(
                              padding: EdgeInsets.all(12.w),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Active Session Details:',
                                    style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700),
                                  ),
                                  SizedBox(height: 8.h),
                                  Text(
                                    '• Date: ${DateFormat('dd MMMM yyyy').format(activeSession.date)}',
                                    style: GoogleFonts.inter(fontSize: 12.sp),
                                  ),
                                  Text(
                                    '• Opening Balance: ${activeSession.openingBalance.toStringAsFixed(2)} SAR',
                                    style: GoogleFonts.inter(fontSize: 12.sp),
                                  ),
                                  Text(
                                    '• Expected Closing Balance: ${activeSession.expectedClosingBalance.toStringAsFixed(2)} SAR',
                                    style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: const Color(0xFF4F46E5)),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 20.h),
                            _buildTextField(
                              _cashController,
                              'Actual Cash in Hand (SAR)',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                              validator: (v) {
                                if (v!.isEmpty) return 'Enter cash amount';
                                if (double.tryParse(v) == null) return 'Invalid number';
                                return null;
                              },
                            ),
                            SizedBox(height: 16.h),
                            _buildTextField(
                              _stcController,
                              'STC Pay Balance (Optional)',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                            ),
                            SizedBox(height: 16.h),
                            _buildTextField(
                              _otherController,
                              'Other Digital Wallet Balance (Optional)',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                            ),
                            SizedBox(height: 16.h),
                            _buildTextField(
                              _notesController,
                              'Daily Closing Notes (Optional)',
                              maxLines: 2,
                            ),
                            SizedBox(height: 20.h),
                            // Closing Sheet Upload
                            Text(
                              'Attach Daily Sheet Photo/Scan',
                              style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w600, color: const Color(0xFF374151)),
                            ),
                            SizedBox(height: 8.h),
                            if (_closingSheetFile != null)
                              Container(
                                height: 160.h,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10.r),
                                  border: Border.all(color: const Color(0xFFD1D5DB)),
                                  image: DecorationImage(image: FileImage(File(_closingSheetFile!.path)), fit: BoxFit.cover),
                                ),
                                child: Align(
                                  alignment: Alignment.topRight,
                                  child: IconButton(
                                    icon: const Icon(Icons.cancel, color: Colors.red),
                                    onPressed: () => setState(() => _closingSheetFile = null),
                                  ),
                                ),
                              )
                            else
                              InkWell(
                                onTap: _pickFile,
                                child: Container(
                                  height: 100.h,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(10.r),
                                    border: Border.all(color: const Color(0xFFD1D5DB)),
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.upload_file, size: 24.sp, color: const Color(0xFF9CA3AF)),
                                        SizedBox(height: 6.h),
                                        Text(
                                          'Select photo/scan of physical log sheet',
                                          style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF6B7280)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            SizedBox(height: 24.h),
                            ElevatedButton(
                              onPressed: _submitClosing,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                minimumSize: Size(double.infinity, 44.h),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                              ),
                              child: Text('Close Daily Petty Cash', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13.sp)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w600, color: const Color(0xFF374151)),
        ),
        SizedBox(height: 6.h),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          style: GoogleFonts.inter(fontSize: 13.sp),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    String? Function(T?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w600, color: const Color(0xFF374151)),
        ),
        SizedBox(height: 6.h),
        DropdownButtonFormField<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          validator: validator,
          style: GoogleFonts.inter(fontSize: 13.sp, color: Colors.black),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
          ),
        ),
      ],
    );
  }
}
