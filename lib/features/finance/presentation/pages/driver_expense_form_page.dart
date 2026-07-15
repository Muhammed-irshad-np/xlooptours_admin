import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:xloop_invoice/features/finance/domain/entities/expense_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/fund_account_entity.dart';
import 'package:xloop_invoice/features/finance/presentation/providers/finance_provider.dart';
import 'package:xloop_invoice/features/finance/presentation/providers/fund_account_provider.dart';
import 'package:xloop_invoice/features/vehicle/presentation/providers/vehicle_provider.dart';

/// Public web/mobile form for drivers to submit expenses.
class DriverExpenseFormPage extends StatefulWidget {
  const DriverExpenseFormPage({super.key});

  @override
  State<DriverExpenseFormPage> createState() => _DriverExpenseFormPageState();
}

class _DriverExpenseFormPageState extends State<DriverExpenseFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _driverNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _mileageController = TextEditingController();

  String? _selectedVehicleId;
  String? _selectedType;
  XFile? _receiptFile;
  bool _isSaving = false;

  final List<String> _commonExpenseTypes = const [
    'Fuel',
    'Car Wash',
    'Toll / Gate Pass',
    'Maintenance / Repair',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VehicleProvider>().getAllVehiclesUseCase();
      context.read<FundAccountProvider>().fetchAllAccounts();
    });
  }

  @override
  void dispose() {
    _driverNameController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _mileageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (image != null) {
      setState(() {
        _receiptFile = image;
      });
    }
  }

  Future<void> _submitExpense() async {
    if (!_formKey.currentState!.validate()) return;
    if (_receiptFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please upload a photo of the receipt', style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final financeProvider = context.read<FinanceProvider>();
      final fundAccountProvider = context.read<FundAccountProvider>();
      final vehicleProvider = context.read<VehicleProvider>();

      final finalId = const Uuid().v4();
      final double amount = double.parse(_amountController.text);
      final double? mileage = double.tryParse(_mileageController.text);

      // Upload receipt
      final receiptUrl = await financeProvider.uploadReceipt(_receiptFile!, finalId);

      // Get vehicle details
      String? vehicleName;
      if (_selectedVehicleId != null) {
        try {
          final v = vehicleProvider.vehicles.firstWhere((element) => element.id == _selectedVehicleId);
          vehicleName = '${v.make} ${v.model} (${v.plateNumber})';
        } catch (_) {}
      }

      // Auto-assign to driver's fund account or petty cash
      String fundAccountId = '';
      String? fundAccountName;
      try {
        final defaultPC = fundAccountProvider.accounts.firstWhere((a) => a.type == FundAccountType.pettyCash);
        fundAccountId = defaultPC.id;
        fundAccountName = defaultPC.name;
      } catch (_) {}

      // Get next sequential reference number
      final nextRef = await financeProvider.generateReferenceNumber();

      final expense = ExpenseEntity(
        id: finalId,
        referenceNumber: nextRef,
        date: DateTime.now(),
        createdAt: DateTime.now(),
        submittedBy: _driverNameController.text.trim(),
        submittedByRole: 'DRIVER',
        expenseCategory: 'VEHICLES',
        expenseType: _selectedType ?? 'Other',
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        amount: amount,
        currency: 'SAR',
        fundAccountId: fundAccountId,
        fundAccountName: fundAccountName,
        status: ExpenseStatus.pending,
        vehicleId: _selectedVehicleId,
        vehicleName: vehicleName,
        mileageKm: mileage,
        receiptUrls: [receiptUrl],
      );

      await financeProvider.insertExpense(expense);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
            icon: Icon(Icons.check_circle, color: const Color(0xFF10B981), size: 48.sp),
            title: Text('Submitted Successfully', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            content: Text(
              'Your expense request of ${amount.toStringAsFixed(2)} SAR has been submitted for admin approval.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13.sp),
            ),
            actions: [
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _resetForm();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                  ),
                  child: Text('Submit Another', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: $e', style: GoogleFonts.inter()), backgroundColor: const Color(0xFFEF4444)),
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

  void _resetForm() {
    setState(() {
      _amountController.clear();
      _descriptionController.clear();
      _mileageController.clear();
      _selectedVehicleId = null;
      _selectedType = null;
      _receiptFile = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final vehicleProvider = context.watch<VehicleProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          'Submit Driver Expense',
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
                            _driverNameController,
                            'Driver Full Name',
                            validator: (v) => v!.isEmpty ? 'Enter your name' : null,
                          ),
                          SizedBox(height: 16.h),
                          _buildDropdownField<String>(
                            label: 'Select Vehicle',
                            value: _selectedVehicleId,
                            items: vehicleProvider.vehicles.map((v) {
                              return DropdownMenuItem(
                                value: v.id,
                                child: Text('${v.make} ${v.model} (${v.plateNumber})'),
                              );
                            }).toList(),
                            onChanged: (v) => setState(() => _selectedVehicleId = v),
                            validator: (v) => v == null ? 'Please select a vehicle' : null,
                          ),
                          SizedBox(height: 16.h),
                          _buildDropdownField<String>(
                            label: 'Expense Type',
                            value: _selectedType,
                            items: _commonExpenseTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: (v) => setState(() => _selectedType = v),
                            validator: (v) => v == null ? 'Select expense type' : null,
                          ),
                          SizedBox(height: 16.h),
                          _buildTextField(
                            _amountController,
                            'Amount (SAR)',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                            validator: (v) {
                              if (v!.isEmpty) return 'Enter amount';
                              if (double.tryParse(v) == null) return 'Invalid amount';
                              return null;
                            },
                          ),
                          SizedBox(height: 16.h),
                          _buildTextField(
                            _mileageController,
                            'Odometer/Mileage KM (Optional)',
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                          SizedBox(height: 16.h),
                          _buildTextField(
                            _descriptionController,
                            'Notes / Description (Optional)',
                            maxLines: 2,
                          ),
                          SizedBox(height: 20.h),
                          // Camera/Receipt Selector
                          Text(
                            'Receipt Photo',
                            style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: const Color(0xFF374151)),
                          ),
                          SizedBox(height: 8.h),
                          if (_receiptFile != null)
                            Container(
                              height: 180.h,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(color: const Color(0xFFD1D5DB)),
                                image: DecorationImage(image: FileImage(File(_receiptFile!.path)), fit: BoxFit.cover),
                              ),
                              child: Align(
                                alignment: Alignment.topRight,
                                child: IconButton(
                                  icon: const Icon(Icons.cancel, color: Colors.red),
                                  onPressed: () => setState(() => _receiptFile = null),
                                ),
                              ),
                            )
                          else
                            InkWell(
                              onTap: _pickImage,
                              child: Container(
                                height: 120.h,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(10.r),
                                  border: Border.all(color: const Color(0xFFD1D5DB), style: BorderStyle.solid),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.camera_alt, size: 28.sp, color: const Color(0xFF9CA3AF)),
                                      SizedBox(height: 6.h),
                                      Text(
                                        'Tap to take photo of receipt',
                                        style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF6B7280)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          SizedBox(height: 24.h),
                          ElevatedButton(
                            onPressed: _submitExpense,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              minimumSize: Size(double.infinity, 44.h),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                            ),
                            child: Text('Submit Expense', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13.sp)),
                          ),
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
