import 'package:flutter/material.dart';
import 'package:xloop_invoice/core/utils/app_snack_bar.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/vault_provider.dart';
import '../../domain/entities/vault_data.dart';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/utils/activity_logger.dart';

class VatFilingDialog extends StatefulWidget {
  final VatFiling? filing;
  const VatFilingDialog({super.key, this.filing});

  @override
  State<VatFilingDialog> createState() => _VatFilingDialogState();
}

class _VatFilingDialogState extends State<VatFilingDialog> {
  final _amountController = TextEditingController();
  final _billNumberController = TextEditingController();
  String _currency = 'SAR';
  DateTime? _date;
  DateTime? _fromDate;
  DateTime? _toDate;
  VaultDocument? _billReceipt;
  VaultDocument? _bankStatement;
  VaultDocument? _paymentReceipt;
  XFile? _selectedBillReceipt;
  XFile? _selectedBankStatement;
  XFile? _selectedPaymentReceipt;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.filing != null) {
      _date = widget.filing!.date;
      _fromDate = widget.filing!.fromDate;
      _toDate = widget.filing!.toDate;
      _amountController.text = widget.filing!.amount.toString();
      _billNumberController.text = widget.filing!.billNumber;
      _currency = widget.filing!.currency;

      final docs = widget.filing!.documents;
      int fallbackIndex = 0;
      for (var doc in docs) {
        if (doc.name == 'Bill Receipt') {
          _billReceipt = doc;
        } else if (doc.name == 'Bank Statement') {
          _bankStatement = doc;
        } else if (doc.name == 'Payment Receipt') {
          _paymentReceipt = doc;
        } else {
          // Fallback for older documents without these names
          if (fallbackIndex == 0) {
            _billReceipt = doc;
          } else if (fallbackIndex == 1) {
            _bankStatement = doc;
          } else if (fallbackIndex == 2) {
            _paymentReceipt = doc;
          }
          fallbackIndex++;
        }
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _billNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickFileForSlot(String slot) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
        withData: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final pf = result.files.first;
        if (pf.path != null) {
          final xf = XFile(pf.path!, name: pf.name);
          final size = await xf.length();
          if (size > 5 * 1024 * 1024) {
            if (mounted) {
              AppSnackBar.showError(context, '${pf.name} exceeds 5MB limit');
            }
            return;
          }
          setState(() {
            if (slot == 'billReceipt') {
              _selectedBillReceipt = xf;
              _billReceipt = null; // Replace existing
            } else if (slot == 'bankStatement') {
              _selectedBankStatement = xf;
              _bankStatement = null; // Replace existing
            } else if (slot == 'paymentReceipt') {
              _selectedPaymentReceipt = xf;
              _paymentReceipt = null; // Replace existing
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Error picking file: $e');
      }
    }
  }

  Future<void> _selectDate(
    BuildContext context,
    DateTime? initialDate,
    Function(DateTime) onSelect,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0F172A),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) onSelect(picked);
  }

  Future<void> _saveFiling() async {
    if (_date == null ||
        _fromDate == null ||
        _toDate == null ||
        _amountController.text.isEmpty) {
      AppSnackBar.showInfo(context, 'Please fill all date and amount fields');
      return;
    }

    final amountValue = double.tryParse(_amountController.text);
    if (amountValue == null) {
      AppSnackBar.showInfo(context, 'Invalid amount');
      return;
    }

    setState(() => _isSaving = true);
    final provider = context.read<VaultProvider>();

    // 1. Upload any newly selected files for each slot and label them correctly
    VaultDocument? billReceipt = _billReceipt;
    if (_selectedBillReceipt != null) {
      final doc = await provider.uploadDocument(
        _selectedBillReceipt!,
        'vat_filings',
      );
      if (doc != null) {
        billReceipt = VaultDocument(url: doc.url, name: 'Bill Receipt');
      }
    } else if (billReceipt != null) {
      billReceipt = VaultDocument(url: billReceipt.url, name: 'Bill Receipt');
    }

    VaultDocument? bankStatement = _bankStatement;
    if (_selectedBankStatement != null) {
      final doc = await provider.uploadDocument(
        _selectedBankStatement!,
        'vat_filings',
      );
      if (doc != null) {
        bankStatement = VaultDocument(url: doc.url, name: 'Bank Statement');
      }
    } else if (bankStatement != null) {
      bankStatement = VaultDocument(
        url: bankStatement.url,
        name: 'Bank Statement',
      );
    }

    VaultDocument? paymentReceipt = _paymentReceipt;
    if (_selectedPaymentReceipt != null) {
      final doc = await provider.uploadDocument(
        _selectedPaymentReceipt!,
        'vat_filings',
      );
      if (doc != null) {
        paymentReceipt = VaultDocument(url: doc.url, name: 'Payment Receipt');
      }
    } else if (paymentReceipt != null) {
      paymentReceipt = VaultDocument(
        url: paymentReceipt.url,
        name: 'Payment Receipt',
      );
    }

    final List<VaultDocument> finalDocuments = [];
    if (billReceipt != null) finalDocuments.add(billReceipt);
    if (bankStatement != null) finalDocuments.add(bankStatement);
    if (paymentReceipt != null) finalDocuments.add(paymentReceipt);

    final filing = VatFiling(
      id: widget.filing?.id ?? '',
      date: _date!,
      amount: amountValue,
      currency: _currency,
      billNumber: _billNumberController.text.trim(),
      fromDate: _fromDate!,
      toDate: _toDate!,
      documents: finalDocuments,
    );

    final success = widget.filing == null
        ? await provider.addVatFiling(filing)
        : await provider.updateVatFiling(filing);

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        await ActivityLogger.log(
          context,
          title: widget.filing == null
              ? 'VAT Filing Added'
              : 'VAT Filing Updated',
          message:
              'VAT filing for bill ${_billNumberController.text.trim()} has been ${widget.filing == null ? 'added' : 'updated'}.',
          relatedId: 'vault',
        );
        Navigator.pop(context);
        AppSnackBar.showInfo(context, 'VAT filing saved successfully');
      } else {
        AppSnackBar.showError(context, 'Failed to save filing: ${provider.errorMessage}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: 500.w,
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Filing Details'),
                    SizedBox(height: 12.h),
                    _buildDatePickerTile(
                      label: 'Filing Date',
                      date: _date,
                      icon: Icons.calendar_today_outlined,
                      onTap: () => _selectDate(
                        context,
                        _date,
                        (d) => setState(() => _date = d),
                      ),
                      semanticsLabel: 'Date of filing',
                    ),
                    SizedBox(height: 16.h),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Semantics(
                            label: 'VAT amount',
                            child: _buildTextField(
                              controller: _amountController,
                              label: 'Amount',
                              icon: Icons.payments_outlined,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(flex: 1, child: _buildCurrencyDropdown()),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    Semantics(
                      label: 'Bill Number',
                      child: _buildTextField(
                        controller: _billNumberController,
                        label: 'Bill Number',
                        icon: Icons.receipt_outlined,
                        hint: 'Enter bill number…',
                      ),
                    ),
                    SizedBox(height: 24.h),
                    _buildSectionTitle('Filing Period'),
                    SizedBox(height: 12.h),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDatePickerTile(
                            label: 'From',
                            date: _fromDate,
                            semanticsLabel: 'Period start date',
                            onTap: () => _selectDate(
                              context,
                              _fromDate,
                              (d) => setState(() => _fromDate = d),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: _buildDatePickerTile(
                            label: 'To',
                            date: _toDate,
                            semanticsLabel: 'Period end date',
                            onTap: () => _selectDate(
                              context,
                              _toDate,
                              (d) => setState(() => _toDate = d),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24.h),
                    _buildSectionTitle('Documents'),
                    SizedBox(height: 12.h),
                    _buildDocumentManager(),
                  ],
                ),
              ),
            ),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
      color: const Color(0xFF0F172A),
      child: Row(
        children: [
          const ExcludeSemantics(
            child: Icon(
              Icons.description_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
          SizedBox(width: 12.w),
          Text(
            widget.filing == null ? 'Add VAT Filing' : 'Edit VAT Filing',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Semantics(
            label: 'Close dialog',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11.sp,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF64748B),
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? hint,
  }) {
    // Automatically derive inputFormatters from keyboardType
    List<TextInputFormatter>? formatters;
    if (keyboardType == TextInputType.number) {
      formatters = [FilteringTextInputFormatter.digitsOnly];
    } else if (keyboardType != null &&
        keyboardType.toString().contains('number')) {
      formatters = [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))];
    }
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14.sp,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: ExcludeSemantics(child: Icon(icon, size: 20.sp)),
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide.none,
        ),
        labelStyle: TextStyle(color: const Color(0xFF64748B), fontSize: 13.sp),
        hintText: hint ?? '0.00…',
      ),
    );
  }

  Widget _buildCurrencyDropdown() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: _currency,
          decoration: const InputDecoration(border: InputBorder.none),
          items: ['SAR', 'BHD']
              .map(
                (c) => DropdownMenuItem(
                  value: c,
                  child: Text(
                    c,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _currency = v ?? 'SAR'),
        ),
      ),
    );
  }

  Widget _buildDatePickerTile({
    required String label,
    DateTime? date,
    IconData? icon,
    String? semanticsLabel,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: semanticsLabel ?? label,
      value: date != null
          ? DateFormat('dd MMM yyyy').format(date)
          : 'Not selected',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                ExcludeSemantics(
                  child: Icon(
                    icon,
                    size: 20.sp,
                    color: const Color(0xFF64748B),
                  ),
                ),
                SizedBox(width: 12.w),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: const Color(0xFF64748B),
                        fontSize: 11.sp,
                      ),
                    ),
                    Text(
                      date != null
                          ? DateFormat('dd MMM yyyy').format(date)
                          : 'Select Date…',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: date != null
                            ? const Color(0xFF1E293B)
                            : const Color(0xFF94A3B8),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              ExcludeSemantics(
                child: Icon(
                  Icons.calendar_month_outlined,
                  size: 18.sp,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentManager() {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDocumentSlot(
            label: 'Bill Receipt',
            document: _billReceipt,
            selectedFile: _selectedBillReceipt,
            onPick: () => _pickFileForSlot('billReceipt'),
            onRemove: () => setState(() {
              _billReceipt = null;
              _selectedBillReceipt = null;
            }),
          ),
          SizedBox(height: 16.h),
          _buildDocumentSlot(
            label: 'Bank Statement',
            document: _bankStatement,
            selectedFile: _selectedBankStatement,
            onPick: () => _pickFileForSlot('bankStatement'),
            onRemove: () => setState(() {
              _bankStatement = null;
              _selectedBankStatement = null;
            }),
          ),
          SizedBox(height: 16.h),
          _buildDocumentSlot(
            label: 'Payment Receipt',
            document: _paymentReceipt,
            selectedFile: _selectedPaymentReceipt,
            onPick: () => _pickFileForSlot('paymentReceipt'),
            onRemove: () => setState(() {
              _paymentReceipt = null;
              _selectedPaymentReceipt = null;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentSlot({
    required String label,
    required VaultDocument? document,
    required XFile? selectedFile,
    required VoidCallback onPick,
    required VoidCallback onRemove,
  }) {
    final hasFile = document != null || selectedFile != null;
    final displayName = document != null
        ? document.name
        : (selectedFile != null ? selectedFile.name : 'No file selected');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF475569),
          ),
        ),
        SizedBox(height: 6.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Icon(
                hasFile
                    ? Icons.file_present_outlined
                    : Icons.upload_file_outlined,
                size: 18.sp,
                color: hasFile
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF94A3B8),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  displayName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.sp,
                    color: hasFile
                        ? const Color(0xFF1E293B)
                        : const Color(0xFF94A3B8),
                    fontWeight: hasFile ? FontWeight.w500 : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasFile) ...[
                if (document != null)
                  IconButton(
                    icon: Icon(
                      Icons.visibility_outlined,
                      size: 16.sp,
                      color: const Color(0xFF64748B),
                    ),
                    onPressed: () => _viewDocument(document.url),
                    constraints: BoxConstraints(
                      minWidth: 32.w,
                      minHeight: 32.h,
                    ),
                    padding: EdgeInsets.zero,
                    tooltip: 'View',
                  ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 16.sp,
                    color: const Color(0xFFF43F5E),
                  ),
                  onPressed: onRemove,
                  constraints: BoxConstraints(minWidth: 32.w, minHeight: 32.h),
                  padding: EdgeInsets.zero,
                  tooltip: 'Remove',
                ),
              ] else
                TextButton(
                  onPressed: onPick,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 4.h,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Upload',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          _isSaving
              ? Row(
                  children: [
                    SizedBox(
                      width: 20.r,
                      height: 20.r,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      'Saving Filing…',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                )
              : Semantics(
                  label: 'Save VAT filing record',
                  button: true,
                  child: ElevatedButton(
                    onPressed: _saveFiling,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 32.w,
                        vertical: 14.h,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Save Filing',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Future<void> _viewDocument(String url) async {
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri)) {
        if (mounted) {
          AppSnackBar.showInfo(context, 'Could not open document');
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Failed to open document: $e');
      }
    }
  }
}
