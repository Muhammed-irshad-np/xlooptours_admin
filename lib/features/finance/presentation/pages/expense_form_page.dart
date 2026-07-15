import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:xloop_invoice/features/finance/domain/entities/expense_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/expense_category_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/fund_account_entity.dart';
import 'package:xloop_invoice/features/finance/presentation/providers/finance_provider.dart';
import 'package:xloop_invoice/features/finance/presentation/providers/fund_account_provider.dart';
import 'package:xloop_invoice/features/employee/presentation/providers/employee_provider.dart';
import 'package:xloop_invoice/features/vehicle/presentation/providers/vehicle_provider.dart';

/// Form screen to add or edit an expense.
class ExpenseFormPage extends StatefulWidget {
  final ExpenseEntity? expense;

  const ExpenseFormPage({super.key, this.expense});

  @override
  State<ExpenseFormPage> createState() => _ExpenseFormPageState();
}

class _ExpenseFormPageState extends State<ExpenseFormPage> {
  final _formKey = GlobalKey<FormState>();

  late DateTime _selectedDate;
  late String _submittedBy;
  late String _submittedByRole;
  String? _selectedCategory;
  String? _selectedType;
  String? _selectedAccountId;
  String? _selectedEmployeeId;
  String? _selectedVehicleId;

  final _amountController = TextEditingController();
  final _currencyController = TextEditingController(text: 'SAR');
  final _descriptionController = TextEditingController();
  final _paymentDetailsController = TextEditingController();
  final _mileageController = TextEditingController();
  final _srvNumberController = TextEditingController();
  final _numberOfTripsController = TextEditingController();
  final _simOperatorController = TextEditingController();
  final _countryController = TextEditingController();
  final _notesController = TextEditingController();

  List<String> _receiptUrls = [];
  List<XFile> _selectedReceiptFiles = [];
  bool _isSaving = false;
  String _refNumber = '';

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.expense?.date ?? DateTime.now();
    _submittedBy = widget.expense?.submittedBy ?? 'ADMIN';
    _submittedByRole = widget.expense?.submittedByRole ?? 'ADMIN';
    _selectedCategory = widget.expense?.expenseCategory;
    _selectedType = widget.expense?.expenseType;
    _selectedAccountId = widget.expense?.fundAccountId;
    _selectedEmployeeId = widget.expense?.employeeId;
    _selectedVehicleId = widget.expense?.vehicleId;

    if (widget.expense != null) {
      _refNumber = widget.expense!.referenceNumber;
      _amountController.text = widget.expense!.amount.toString();
      _currencyController.text = widget.expense!.currency;
      _descriptionController.text = widget.expense!.description ?? '';
      _paymentDetailsController.text = widget.expense!.paymentDetails ?? '';
      _mileageController.text = widget.expense!.mileageKm?.toString() ?? '';
      _srvNumberController.text = widget.expense!.srvNumber ?? '';
      _numberOfTripsController.text = widget.expense!.numberOfTrips?.toString() ?? '';
      _simOperatorController.text = widget.expense!.simOperator ?? '';
      _countryController.text = widget.expense!.country ?? '';
      _notesController.text = widget.expense!.notes ?? '';
      _receiptUrls = List.from(widget.expense!.receiptUrls);
    } else {
      _fetchNextRefNumber();
    }

    // Load related providers.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmployeeProvider>().fetchAllEmployees();
      context.read<VehicleProvider>().getAllVehiclesUseCase(); // Ensure vehicles loaded
    });
  }

  Future<void> _fetchNextRefNumber() async {
    final nextRef = await context.read<FinanceProvider>().generateReferenceNumber();
    if (mounted) {
      setState(() {
        _refNumber = nextRef;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _currencyController.dispose();
    _descriptionController.dispose();
    _paymentDetailsController.dispose();
    _mileageController.dispose();
    _srvNumberController.dispose();
    _numberOfTripsController.dispose();
    _simOperatorController.dispose();
    _countryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      setState(() {
        _selectedReceiptFiles.add(image);
      });
    }
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final financeProvider = context.read<FinanceProvider>();
      final fundAccountProvider = context.read<FundAccountProvider>();
      final employeeProvider = context.read<EmployeeProvider>();
      final vehicleProvider = context.read<VehicleProvider>();

      final finalId = widget.expense?.id ?? const Uuid().v4();
      final double amount = double.parse(_amountController.text);
      final double? mileage = double.tryParse(_mileageController.text);
      final int? numTrips = int.tryParse(_numberOfTripsController.text);

      // Upload newly selected local receipt images.
      final List<String> uploadedUrls = List.from(_receiptUrls);
      for (final file in _selectedReceiptFiles) {
        final url = await financeProvider.uploadReceipt(file, finalId);
        uploadedUrls.add(url);
      }

      // Find details from selected relationships.
      String? fundAccountName;
      if (_selectedAccountId != null) {
        fundAccountName = fundAccountProvider.getAccountById(_selectedAccountId!)?.name;
      }

      String? employeeName;
      if (_selectedEmployeeId != null) {
        try {
          employeeName = employeeProvider.employees
              .firstWhere((e) => e.id == _selectedEmployeeId)
              .fullName;
        } catch (_) {}
      }

      String? vehicleName;
      if (_selectedVehicleId != null) {
        try {
          final v = vehicleProvider.getAllVehiclesUseCase(); // Wait, let's look at Provider
          // Let's just find in the local vehicles list exposed by Provider
          final localV = vehicleProvider.getAllVehiclesUseCase; 
          // Let's check how vehicles is fetched:
          // final list = vehicleProvider.vehicles;
          // In vehicle_provider.dart, the field is `List<VehicleEntity> _vehicles = [];` with getter `vehicles`
        } catch (_) {}
      }

      // Try safely getting vehicle name:
      try {
        final v = context.read<VehicleProvider>().vehicles.firstWhere((element) => element.id == _selectedVehicleId);
        vehicleName = '${v.make} ${v.model} (${v.plateNumber})';
      } catch (_) {}

      final newExpense = ExpenseEntity(
        id: finalId,
        referenceNumber: _refNumber,
        date: _selectedDate,
        createdAt: widget.expense?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        submittedBy: _submittedBy,
        submittedByRole: _submittedByRole,
        expenseCategory: _selectedCategory ?? '',
        expenseType: _selectedType ?? '',
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        paymentDetails: _paymentDetailsController.text.trim().isEmpty ? null : _paymentDetailsController.text.trim(),
        amount: amount,
        currency: _currencyController.text.trim(),
        fundAccountId: _selectedAccountId ?? '',
        fundAccountName: fundAccountName,
        status: widget.expense?.status ?? ExpenseStatus.pending,
        employeeId: _selectedEmployeeId,
        employeeName: employeeName,
        vehicleId: _selectedVehicleId,
        vehicleName: vehicleName,
        mileageKm: mileage,
        receiptUrls: uploadedUrls,
        srvNumber: _srvNumberController.text.trim().isEmpty ? null : _srvNumberController.text.trim(),
        numberOfTrips: numTrips,
        simOperator: _simOperatorController.text.trim().isEmpty ? null : _simOperatorController.text.trim(),
        country: _countryController.text.trim().isEmpty ? null : _countryController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        approvedBy: widget.expense?.approvedBy,
        approvedAt: widget.expense?.approvedAt,
        rejectionReason: widget.expense?.rejectionReason,
      );

      if (widget.expense == null) {
        await financeProvider.insertExpense(newExpense);
      } else {
        await financeProvider.updateExpense(newExpense);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.expense == null ? 'Expense added successfully' : 'Expense updated successfully',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save expense: $e', style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFFEF4444),
          ),
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
    final financeProvider = context.watch<FinanceProvider>();
    final fundAccountProvider = context.watch<FundAccountProvider>();
    final employeeProvider = context.watch<EmployeeProvider>();
    final vehicleProvider = context.watch<VehicleProvider>();

    final categories = financeProvider.categories;
    final activeAccounts = fundAccountProvider.activeAccounts;

    // Get types for selected category
    final types = _selectedCategory != null
        ? financeProvider.getTypesForCategory(_selectedCategory!)
        : <ExpenseTypeEntity>[];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.expense == null ? 'Add Expense $_refNumber' : 'Edit Expense $_refNumber',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 16.sp,
            color: const Color(0xFF111827),
          ),
        ),
        actions: [
          if (!_isSaving)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: ElevatedButton(
                onPressed: _saveForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                ),
                child: Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column (Core Details)
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              _buildCard(
                                title: 'Expense Details',
                                children: [
                                  Row(
                                    children: [
                                      // Date Selection
                                      Expanded(
                                        child: _buildDatePickerField(
                                          label: 'Date',
                                          value: DateFormat('yyyy-MM-dd').format(_selectedDate),
                                          onTap: () async {
                                            final date = await showDatePicker(
                                              context: context,
                                              initialDate: _selectedDate,
                                              firstDate: DateTime(2020),
                                              lastDate: DateTime(2030),
                                            );
                                            if (date != null) {
                                              setState(() {
                                                _selectedDate = date;
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                      SizedBox(width: 16.w),
                                      // Fund Account Selection
                                      Expanded(
                                        child: _buildDropdownField<String>(
                                          label: 'Charge To Account',
                                          value: _selectedAccountId,
                                          items: activeAccounts.map((a) {
                                            return DropdownMenuItem(
                                              value: a.id,
                                              child: Text('${a.name} (${a.currentBalance} ${a.currency})'),
                                            );
                                          }).toList(),
                                          onChanged: (v) {
                                            setState(() {
                                              _selectedAccountId = v;
                                            });
                                          },
                                          validator: (v) => v == null ? 'Please select an account' : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 16.h),
                                  Row(
                                    children: [
                                      // Category Selection
                                      Expanded(
                                        child: _buildDropdownField<String>(
                                          label: 'Category',
                                          value: _selectedCategory,
                                          items: categories.map((c) {
                                            return DropdownMenuItem(
                                              value: c.name,
                                              child: Text(c.name),
                                            );
                                          }).toList(),
                                          onChanged: (v) {
                                            setState(() {
                                              _selectedCategory = v;
                                              _selectedType = null;
                                            });
                                          },
                                          validator: (v) => v == null ? 'Please select category' : null,
                                        ),
                                      ),
                                      SizedBox(width: 16.w),
                                      // Type Selection
                                      Expanded(
                                        child: _buildDropdownField<String>(
                                          label: 'Expense Type',
                                          value: _selectedType,
                                          items: types.map((t) {
                                            return DropdownMenuItem(
                                              value: t.name,
                                              child: Text(t.name),
                                            );
                                          }).toList(),
                                          onChanged: (v) {
                                            setState(() {
                                              _selectedType = v;
                                            });
                                          },
                                          validator: (v) => v == null ? 'Please select type' : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 16.h),
                                  Row(
                                    children: [
                                      // Amount Input (Decimal)
                                      Expanded(
                                        flex: 3,
                                        child: _buildTextField(
                                          controller: _amountController,
                                          label: 'Amount',
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                          ],
                                          validator: (v) {
                                            if (v == null || v.isEmpty) return 'Please enter amount';
                                            if (double.tryParse(v) == null) return 'Invalid numeric value';
                                            return null;
                                          },
                                        ),
                                      ),
                                      SizedBox(width: 16.w),
                                      // Currency
                                      Expanded(
                                        flex: 1,
                                        child: _buildDropdownField<String>(
                                          label: 'Currency',
                                          value: _currencyController.text,
                                          items: const [
                                            DropdownMenuItem(value: 'SAR', child: Text('SAR')),
                                            DropdownMenuItem(value: 'BHD', child: Text('BHD')),
                                          ],
                                          onChanged: (v) {
                                            if (v != null) {
                                              setState(() {
                                                _currencyController.text = v;
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 16.h),
                                  _buildTextField(
                                    controller: _descriptionController,
                                    label: 'Description / Purpose',
                                    maxLines: 3,
                                  ),
                                  SizedBox(height: 16.h),
                                  _buildTextField(
                                    controller: _paymentDetailsController,
                                    label: 'Payment Details / Reference ID',
                                  ),
                                ],
                              ),
                              SizedBox(height: 24.h),
                              // Optional Dynamic Sections based on category type
                              if (_selectedCategory == 'VEHICLES')
                                _buildCard(
                                  title: 'Vehicle Information',
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildDropdownField<String>(
                                            label: 'Select Vehicle',
                                            value: _selectedVehicleId,
                                            items: vehicleProvider.vehicles.map((v) {
                                              return DropdownMenuItem(
                                                value: v.id,
                                                child: Text('${v.make} ${v.model} (${v.plateNumber})'),
                                              );
                                            }).toList(),
                                            onChanged: (v) {
                                              setState(() {
                                                _selectedVehicleId = v;
                                              });
                                            },
                                          ),
                                        ),
                                        SizedBox(width: 16.w),
                                        Expanded(
                                          child: _buildTextField(
                                            controller: _mileageController,
                                            label: 'Odometer/Mileage (KM)',
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              if (_selectedCategory == 'EMPLOYEES')
                                _buildCard(
                                  title: 'Employee Information',
                                  children: [
                                    _buildDropdownField<String>(
                                      label: 'Select Employee',
                                      value: _selectedEmployeeId,
                                      items: employeeProvider.employees.map((e) {
                                        return DropdownMenuItem(
                                          value: e.id,
                                          child: Text(e.fullName),
                                        );
                                      }).toList(),
                                      onChanged: (v) {
                                        setState(() {
                                          _selectedEmployeeId = v;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              if (_selectedCategory == 'TELECOM & SIM')
                                _buildCard(
                                  title: 'Sim / Telecom Specifics',
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildTextField(
                                            controller: _srvNumberController,
                                            label: 'SRV Number',
                                          ),
                                        ),
                                        SizedBox(width: 16.w),
                                        Expanded(
                                          child: _buildTextField(
                                            controller: _simOperatorController,
                                            label: 'SIM Operator',
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 16.h),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildTextField(
                                            controller: _countryController,
                                            label: 'Country',
                                          ),
                                        ),
                                        SizedBox(width: 16.w),
                                        Expanded(
                                          child: _buildTextField(
                                            controller: _numberOfTripsController,
                                            label: 'Number of Trips',
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        SizedBox(width: 24.w),
                        // Right Column (Receipts & Metadata)
                        Expanded(
                          flex: 1,
                          child: Column(
                            children: [
                              _buildCard(
                                title: 'Receipt Attachments',
                                children: [
                                  if (_receiptUrls.isNotEmpty || _selectedReceiptFiles.isNotEmpty)
                                    GridView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: 10.w,
                                        mainAxisSpacing: 10.h,
                                      ),
                                      itemCount: _receiptUrls.length + _selectedReceiptFiles.length,
                                      itemBuilder: (context, index) {
                                        if (index < _receiptUrls.length) {
                                          final url = _receiptUrls[index];
                                          return Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              Image.network(url, fit: BoxFit.cover),
                                              Positioned(
                                                right: 5,
                                                top: 5,
                                                child: CircleAvatar(
                                                  radius: 12,
                                                  backgroundColor: Colors.black.withOpacity(0.5),
                                                  child: IconButton(
                                                    icon: const Icon(Icons.close, size: 10, color: Colors.white),
                                                    onPressed: () {
                                                      setState(() {
                                                        _receiptUrls.removeAt(index);
                                                      });
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        } else {
                                          final fileIdx = index - _receiptUrls.length;
                                          final file = _selectedReceiptFiles[fileIdx];
                                          return Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              Image.file(File(file.path), fit: BoxFit.cover),
                                              Positioned(
                                                right: 5,
                                                top: 5,
                                                child: CircleAvatar(
                                                  radius: 12,
                                                  backgroundColor: Colors.black.withOpacity(0.5),
                                                  child: IconButton(
                                                    icon: const Icon(Icons.close, size: 10, color: Colors.white),
                                                    onPressed: () {
                                                      setState(() {
                                                        _selectedReceiptFiles.removeAt(fileIdx);
                                                      });
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        }
                                      },
                                    ),
                                  if (_receiptUrls.isEmpty && _selectedReceiptFiles.isEmpty)
                                    Container(
                                      padding: EdgeInsets.symmetric(vertical: 40.h),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'No receipts attached',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF9CA3AF),
                                          fontSize: 12.sp,
                                        ),
                                      ),
                                    ),
                                  SizedBox(height: 16.h),
                                  OutlinedButton.icon(
                                    onPressed: _pickImage,
                                    icon: const Icon(Icons.camera_alt),
                                    label: const Text('Add Receipt Photo'),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: Size(double.infinity, 44.h),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 24.h),
                              _buildCard(
                                title: 'Submission Metadata',
                                children: [
                                  _buildDropdownField<String>(
                                    label: 'Submitted By (Name)',
                                    value: _submittedBy,
                                    items: const [
                                      DropdownMenuItem(value: 'ADMIN', child: Text('ADMIN')),
                                      DropdownMenuItem(value: 'NITHIN', child: Text('NITHIN')),
                                      DropdownMenuItem(value: 'SHAMNAD', child: Text('SHAMNAD')),
                                      DropdownMenuItem(value: 'COORDINATOR', child: Text('COORDINATOR')),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() {
                                          _submittedBy = v;
                                        });
                                      }
                                    },
                                  ),
                                  SizedBox(height: 16.h),
                                  _buildDropdownField<String>(
                                    label: 'Submitted By (Role)',
                                    value: _submittedByRole,
                                    items: const [
                                      DropdownMenuItem(value: 'ADMIN', child: Text('ADMIN')),
                                      DropdownMenuItem(value: 'COORDINATOR', child: Text('COORDINATOR')),
                                      DropdownMenuItem(value: 'DRIVER', child: Text('DRIVER')),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() {
                                          _submittedByRole = v;
                                        });
                                      }
                                    },
                                  ),
                                  SizedBox(height: 16.h),
                                  _buildTextField(
                                    controller: _notesController,
                                    label: 'Administrative Notes',
                                    maxLines: 3,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 24.h),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 14.sp,
              color: const Color(0xFF111827),
            ),
          ),
          SizedBox(height: 16.h),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
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
          style: GoogleFonts.inter(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
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
            contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
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
          style: GoogleFonts.inter(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
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
            contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
        ),
        SizedBox(height: 6.h),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: const Color(0xFFD1D5DB)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(fontSize: 13.sp),
                ),
                Icon(Icons.calendar_today, size: 16.sp, color: const Color(0xFF6B7280)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
