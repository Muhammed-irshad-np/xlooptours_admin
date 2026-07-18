import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/finance_provider.dart';
import '../providers/fund_account_provider.dart';
import '../../../vehicle/presentation/providers/vehicle_provider.dart';
import '../../domain/entities/expense_entity.dart';
import '../../domain/entities/fund_account_entity.dart';
import '../pages/finance_dashboard_page.dart';

/// Public-facing mobile web form for drivers to submit daily expenses.
class DriverExpenseFormPage extends StatefulWidget {
  const DriverExpenseFormPage({super.key});

  @override
  State<DriverExpenseFormPage> createState() => _DriverExpenseFormPageState();
}

class _DriverExpenseFormPageState extends State<DriverExpenseFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Form Controllers
  final _driverNameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _mileageCtrl = TextEditingController();
  final _tripsCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _selectedVehicleId;
  String? _selectedType;
  String? _receiptUrl;
  bool _uploadingReceipt = false;

  final List<String> _expenseTypes = ['Fuel', 'Car Wash', 'Maintenance & Repairs', 'Other'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VehicleProvider>().fetchAllVehicles();
      context.read<FundAccountProvider>().fetchAllAccounts();
    });
  }

  @override
  void dispose() {
    _driverNameCtrl.dispose();
    _amountCtrl.dispose();
    _mileageCtrl.dispose();
    _tripsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vehicleProv = context.watch<VehicleProvider>();
    final finProv = context.watch<FinanceProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          'Driver Expense Submission',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16.sp),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
              elevation: 2,
              color: Colors.white,
              child: Padding(
                padding: EdgeInsets.all(24.w),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Submit Daily Expense',
                        style: GoogleFonts.inter(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                          color: FinDT.textPrimary,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        'Upload a receipt and fill out details for fuel, car wash, or maintenance.',
                        style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textSecondary),
                      ),
                      SizedBox(height: 24.h),

                      // Driver Name
                      _buildLabel('Driver Name *'),
                      TextFormField(
                        controller: _driverNameCtrl,
                        decoration: _inputDecoration('Enter your full name'),
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      SizedBox(height: 16.h),

                      // Vehicle Dropdown
                      _buildLabel('Select Vehicle *'),
                      DropdownButtonFormField<String>(
                        value: _selectedVehicleId,
                        decoration: _inputDecoration('Choose vehicle plate/model'),
                        items: vehicleProv.vehicles.map((v) {
                          return DropdownMenuItem(
                            value: v.id,
                            child: Text('${v.plateNumber} - ${v.model}'),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedVehicleId = val),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      SizedBox(height: 16.h),

                      // Expense Type
                      _buildLabel('Expense Type *'),
                      DropdownButtonFormField<String>(
                        value: _selectedType,
                        decoration: _inputDecoration('Choose expense type'),
                        items: _expenseTypes.map((t) {
                          return DropdownMenuItem(value: t, child: Text(t));
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedType = val),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      SizedBox(height: 16.h),

                      // Amount
                      _buildLabel('Amount (SAR) *'),
                      TextFormField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        decoration: _inputDecoration('0.00'),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          final val = double.tryParse(v);
                          if (val == null || val <= 0) return 'Must be positive';
                          return null;
                        },
                      ),
                      SizedBox(height: 16.h),

                      // Mileage (Only relevant for vehicles)
                      _buildLabel('Current Mileage / Odometer (KM)'),
                      TextFormField(
                        controller: _mileageCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        decoration: _inputDecoration('e.g., 120450'),
                      ),
                      SizedBox(height: 16.h),

                      // Receipt Upload
                      _buildLabel('Receipt Photo *'),
                      _buildReceiptPicker(finProv),
                      SizedBox(height: 16.h),

                      // Driver Notes
                      _buildLabel('Notes / Comments'),
                      TextFormField(
                        controller: _notesCtrl,
                        maxLines: 2,
                        decoration: _inputDecoration('Any additional details...'),
                      ),
                      SizedBox(height: 28.h),

                      // Submit Button
                      _buildSubmitButton(finProv),
                    ],
                  ),
                ),
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

  Widget _buildReceiptPicker(FinanceProvider provider) {
    if (_uploadingReceipt) {
      return Container(
        height: 120.h,
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF13B1F2)),
        ),
      );
    }

    if (_receiptUrl != null) {
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
                    'Receipt attached successfully',
                    style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: FinDT.success),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 8.w,
              top: 8.h,
              child: IconButton(
                onPressed: () => setState(() => _receiptUrl = null),
                icon: Icon(Icons.cancel, color: FinDT.danger, size: 20.sp),
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => _pickAndUploadReceipt(provider),
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
            Icon(Icons.camera_alt_outlined, size: 32.sp, color: const Color(0xFF13B1F2)),
            SizedBox(height: 8.h),
            Text(
              'Capture Receipt Photo',
              style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: const Color(0xFF13B1F2)),
            ),
            SizedBox(height: 4.h),
            Text(
              'Ensure store name & total are visible',
              style: GoogleFonts.inter(fontSize: 10.sp, color: FinDT.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadReceipt(FinanceProvider provider) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (file == null) return;

    setState(() => _uploadingReceipt = true);

    try {
      final expenseId = const Uuid().v4();
      final url = await provider.uploadReceipt(file, expenseId);
      setState(() => _receiptUrl = url);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload: $e')),
      );
    } finally {
      setState(() => _uploadingReceipt = false);
    }
  }

  Widget _buildSubmitButton(FinanceProvider provider) {
    return SizedBox(
      width: double.infinity,
      height: 48.h,
      child: ElevatedButton(
        onPressed: _isSaving ? null : () => _submitForm(provider),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF13B1F2),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
          elevation: 0,
        ),
        child: _isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                'Submit Expense',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13.sp),
              ),
      ),
    );
  }

  Future<void> _submitForm(FinanceProvider provider) async {
    if (!_formKey.currentState!.validate()) return;
    if (_receiptUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a photo of the receipt.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final vehicleProv = context.read<VehicleProvider>();
      final accProv = context.read<FundAccountProvider>();

      final selectedVehicle = vehicleProv.vehicles.firstWhere((v) => v.id == _selectedVehicleId);

      // Find first Driver/Fuel Account to charge
      final defaultAccount = accProv.activeAccounts.firstWhere(
        (a) => a.type == FundAccountType.driverAccount || a.type == FundAccountType.pettyCash,
        orElse: () => accProv.activeAccounts.first,
      );

      final expense = ExpenseEntity(
        id: const Uuid().v4(),
        referenceNumber: await provider.generateReferenceNumber(),
        date: DateTime.now(),
        createdAt: DateTime.now(),
        submittedBy: _driverNameCtrl.text.toUpperCase().trim(),
        submittedByRole: 'DRIVER',
        expenseCategory: 'VEHICLES',
        expenseType: _selectedType!.toUpperCase(),
        amount: double.parse(_amountCtrl.text),
        currency: 'SAR',
        fundAccountId: defaultAccount.id,
        fundAccountName: defaultAccount.name,
        vehicleId: selectedVehicle.id,
        vehicleName: '${selectedVehicle.plateNumber} - ${selectedVehicle.model}',
        mileageKm: _mileageCtrl.text.isNotEmpty ? double.tryParse(_mileageCtrl.text) : null,
        receiptUrls: [_receiptUrl!],
        notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
        status: ExpenseStatus.pending,
      );

      await provider.insertExpense(expense);

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
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
            const Text('Submitted!'),
          ],
        ),
        content: const Text(
          'Your expense has been successfully submitted for review. You can close this page now.',
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
    _driverNameCtrl.clear();
    _amountCtrl.clear();
    _mileageCtrl.clear();
    _tripsCtrl.clear();
    _notesCtrl.clear();
    setState(() {
      _selectedVehicleId = null;
      _selectedType = null;
      _receiptUrl = null;
    });
  }
}
