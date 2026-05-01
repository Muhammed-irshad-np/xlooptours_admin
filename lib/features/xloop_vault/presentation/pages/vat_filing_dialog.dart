import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/vault_provider.dart';
import '../../domain/entities/vault_data.dart';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

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
  List<XFile> _selectedFiles = [];
  List<VaultDocument> _existingDocuments = [];
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
      _existingDocuments = List.from(widget.filing!.documents);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _billNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        withData: false,
      );
      if (result != null) {
        final totalAfterAdd = result.files.length + _selectedFiles.length + _existingDocuments.length;
        if (totalAfterAdd > 3) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Maximum 3 documents allowed total')),
            );
          }
          return;
        }

        final List<XFile> validFiles = [];
        for (final pf in result.files) {
          if (pf.path != null) {
            final xf = XFile(pf.path!);
            final size = await xf.length();
            if (size > 5 * 1024 * 1024) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${pf.name} exceeds 5MB limit')),
                );
              }
              continue; // skip oversized files, allow rest
            }
            validFiles.add(xf);
          }
        }

        if (validFiles.isNotEmpty) {
          setState(() {
            _selectedFiles = [..._selectedFiles, ...validFiles];
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking files: $e')),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context, DateTime? initialDate, Function(DateTime) onSelect) async {
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
    if (_date == null || _fromDate == null || _toDate == null || _amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all date and amount fields')));
      return;
    }

    final amountValue = double.tryParse(_amountController.text);
    if (amountValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid amount')));
      return;
    }

    setState(() => _isSaving = true);
    final provider = context.read<VaultProvider>();

    List<VaultDocument> uploadedDocuments = [];
    for (var file in _selectedFiles) {
      final doc = await provider.uploadDocument(file, 'vat_filings');
      if (doc != null) {
        uploadedDocuments.add(doc);
      }
    }

    final filing = VatFiling(
      id: widget.filing?.id ?? '', 
      date: _date!,
      amount: amountValue,
      currency: _currency,
      billNumber: _billNumberController.text.trim(),
      fromDate: _fromDate!,
      toDate: _toDate!,
      documents: [..._existingDocuments, ...uploadedDocuments],
    );

    final success = widget.filing == null 
        ? await provider.addVatFiling(filing)
        : await provider.updateVatFiling(filing);

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('VAT filing saved successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save filing: ${provider.errorMessage}')));
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
                      onTap: () => _selectDate(context, _date, (d) => setState(() => _date = d)),
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
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          flex: 1,
                          child: _buildCurrencyDropdown(),
                        ),
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
                            onTap: () => _selectDate(context, _fromDate, (d) => setState(() => _fromDate = d)),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: _buildDatePickerTile(
                            label: 'To',
                            date: _toDate,
                            semanticsLabel: 'Period end date',
                            onTap: () => _selectDate(context, _toDate, (d) => setState(() => _toDate = d)),
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
            child: Icon(Icons.description_outlined, color: Colors.white, size: 24),
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

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, TextInputType? keyboardType, String? hint}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
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
          items: ['SAR', 'BHD'].map((c) => DropdownMenuItem(
            value: c,
            child: Text(c, style: GoogleFonts.plusJakartaSans(fontSize: 14.sp, fontWeight: FontWeight.bold)),
          )).toList(),
          onChanged: (v) => setState(() => _currency = v ?? 'SAR'),
        ),
      ),
    );
  }

  Widget _buildDatePickerTile({required String label, DateTime? date, IconData? icon, String? semanticsLabel, required VoidCallback onTap}) {
    return Semantics(
      button: true,
      label: semanticsLabel ?? label,
      value: date != null ? DateFormat('dd MMM yyyy').format(date) : 'Not selected',
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
                ExcludeSemantics(child: Icon(icon, size: 20.sp, color: const Color(0xFF64748B))),
                SizedBox(width: 12.w),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(color: const Color(0xFF64748B), fontSize: 11.sp)),
                    Text(
                      date != null ? DateFormat('dd MMM yyyy').format(date) : 'Select Date…',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: date != null ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              ExcludeSemantics(child: Icon(Icons.calendar_month_outlined, size: 18.sp, color: const Color(0xFF94A3B8))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentManager() {
    final int totalDocs = _selectedFiles.length + _existingDocuments.length;
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE2E8F0), style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          if (_existingDocuments.isNotEmpty) ...[
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: _existingDocuments.asMap().entries.map((entry) {
                final doc = entry.value;
                return Semantics(
                  label: 'Uploaded document ${entry.key + 1}: ${doc.name}',
                  child: InputChip(
                    backgroundColor: const Color(0xFFE2E8F0),
                    avatar: Icon(Icons.visibility_outlined, size: 14.sp, color: const Color(0xFF2563EB)),
                    label: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 100.w),
                      child: Text(
                        doc.name, 
                        style: TextStyle(fontSize: 11.sp),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    onPressed: () => _viewDocument(doc.url),
                    onDeleted: () => setState(() => _existingDocuments.removeAt(entry.key)),
                    deleteIconColor: const Color(0xFFF43F5E),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 12.h),
          ],
          if (_selectedFiles.isNotEmpty) ...[
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: _selectedFiles.asMap().entries.map((entry) {
                final file = entry.value;
                return Semantics(
                  label: 'New file to upload: ${file.name}',
                  child: InputChip(
                    backgroundColor: const Color(0xFF2563EB).withOpacity(0.1),
                    label: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 100.w),
                      child: Text(
                        file.name, 
                        style: TextStyle(fontSize: 11.sp, color: const Color(0xFF2563EB)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    onDeleted: () => setState(() => _selectedFiles.removeAt(entry.key)),
                    deleteIconColor: const Color(0xFF2563EB),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 12.h),
          ],
          Semantics(
            label: 'Attach up to 3 VAT documents',
            button: true,
            enabled: totalDocs < 3,
            child: OutlinedButton.icon(
              onPressed: totalDocs < 3 ? _pickFiles : null,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text('Add Documentation ($totalDocs/3)'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
              ),
            ),
          ),
        ],
      ),
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
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          SizedBox(width: 12.w),
          _isSaving 
            ? Row(
                children: [
                  SizedBox(width: 20.r, height: 20.r, child: const CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 12.w),
                  Text('Saving Filing…', style: TextStyle(fontSize: 13.sp, color: const Color(0xFF64748B))),
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
                    padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 14.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                    elevation: 0,
                  ),
                  child: Text('Save Filing', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open document')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open document: $e')),
        );
      }
    }
  }
}
