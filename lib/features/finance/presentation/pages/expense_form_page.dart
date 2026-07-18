import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/finance_provider.dart';
import '../providers/fund_account_provider.dart';
import '../../domain/entities/expense_entity.dart';
import '../../domain/entities/expense_category_entity.dart';
import 'finance_dashboard_page.dart';

/// Full-featured expense entry/edit form.
class ExpenseFormPage extends StatefulWidget {
  final ExpenseEntity? expense;

  const ExpenseFormPage({super.key, this.expense});

  @override
  State<ExpenseFormPage> createState() => _ExpenseFormPageState();
}

class _ExpenseFormPageState extends State<ExpenseFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;
  bool _isSaving = false;

  // Controllers
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  late TextEditingController _paymentDetailsController;
  late TextEditingController _notesController;
  late TextEditingController _mileageController;
  late TextEditingController _srvNumberController;
  late TextEditingController _tripsController;

  // Selections
  DateTime _selectedDate = DateTime.now();
  String? _selectedCategory;
  String? _selectedType;
  String? _selectedAccountId;
  String _selectedCurrency = 'SAR';
  String _submittedBy = '';
  String _submittedByRole = 'ADMIN';
  String? _selectedEmployeeId;
  String? _selectedVehicleId;
  List<String> _receiptUrls = [];

  @override
  void initState() {
    super.initState();
    _isEditing = widget.expense != null;
    final e = widget.expense;

    _amountController = TextEditingController(
      text: e != null ? e.amount.toString() : '',
    );
    _descriptionController = TextEditingController(
      text: e?.description ?? '',
    );
    _paymentDetailsController = TextEditingController(
      text: e?.paymentDetails ?? '',
    );
    _notesController = TextEditingController(text: e?.notes ?? '');
    _mileageController = TextEditingController(
      text: e?.mileageKm?.toString() ?? '',
    );
    _srvNumberController = TextEditingController(
      text: e?.srvNumber ?? '',
    );
    _tripsController = TextEditingController(
      text: e?.numberOfTrips?.toString() ?? '',
    );

    if (e != null) {
      _selectedDate = e.date;
      _selectedCategory = e.expenseCategory;
      _selectedType = e.expenseType;
      _selectedAccountId = e.fundAccountId;
      _selectedCurrency = e.currency;
      _submittedBy = e.submittedBy;
      _submittedByRole = e.submittedByRole;
      _selectedEmployeeId = e.employeeId;
      _selectedVehicleId = e.vehicleId;
      _receiptUrls = List.from(e.receiptUrls);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _paymentDetailsController.dispose();
    _notesController.dispose();
    _mileageController.dispose();
    _srvNumberController.dispose();
    _tripsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinDT.bgPage,
      appBar: _buildAppBar(),
      body: Consumer2<FinanceProvider, FundAccountProvider>(
        builder: (context, finProv, accProv, _) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(28.w),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Form Card ─────────────────────────────────
                  _buildFormCard(
                    title: 'Basic Information',
                    icon: Icons.info_outline_rounded,
                    children: [
                      _buildRow([
                        _buildDateField(),
                        _buildCurrencyField(),
                      ]),
                      SizedBox(height: 16.h),
                      _buildRow([
                        _buildAmountField(),
                        _buildSubmittedByField(),
                      ]),
                      SizedBox(height: 16.h),
                      _buildPaymentDetailsField(),
                    ],
                  ),
                  SizedBox(height: 20.h),

                  // ── Category & Type ───────────────────────────
                  _buildFormCard(
                    title: 'Expense Classification',
                    icon: Icons.category_outlined,
                    children: [
                      _buildRow([
                        _buildCategoryDropdown(finProv),
                        _buildTypeDropdown(finProv),
                      ]),
                      SizedBox(height: 16.h),
                      _buildAccountDropdown(accProv),
                    ],
                  ),
                  SizedBox(height: 20.h),

                  // ── Details ───────────────────────────────────
                  _buildFormCard(
                    title: 'Additional Details',
                    icon: Icons.description_outlined,
                    children: [
                      _buildDescriptionField(),
                      SizedBox(height: 16.h),
                      _buildRow([
                        _buildMileageField(),
                        _buildTripsField(),
                      ]),
                      SizedBox(height: 16.h),
                      _buildNotesField(),
                    ],
                  ),
                  SizedBox(height: 20.h),

                  // ── Receipt Upload ────────────────────────────
                  _buildFormCard(
                    title: 'Receipts & Documents',
                    icon: Icons.attach_file_rounded,
                    children: [
                      _buildReceiptSection(finProv),
                    ],
                  ),
                  SizedBox(height: 28.h),

                  // ── Submit ────────────────────────────────────
                  _buildSubmitButton(finProv),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isEditing ? 'Edit Expense' : 'New Expense',
            style: GoogleFonts.inter(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: FinDT.textPrimary,
            ),
          ),
          if (_isEditing)
            Text(
              widget.expense!.referenceNumber,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: FinDT.brand,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFormCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18.sp, color: FinDT.brand),
              SizedBox(width: 8.w),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: FinDT.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRow(List<Widget> children) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children
          .expand((w) => [Expanded(child: w), SizedBox(width: 16.w)])
          .toList()
        ..removeLast(),
    );
  }

  Widget _buildDateField() {
    return _FieldWrapper(
      label: 'Date',
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _selectedDate,
            firstDate: DateTime(2024),
            lastDate: DateTime.now().add(const Duration(days: 30)),
            builder: (context, child) => Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(primary: FinDT.brand),
              ),
              child: child!,
            ),
          );
          if (picked != null) setState(() => _selectedDate = picked);
        },
        borderRadius: BorderRadius.circular(10.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: FinDT.bgPage,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: FinDT.border),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 14.sp,
                color: FinDT.textSecondary,
              ),
              SizedBox(width: 8.w),
              Text(
                DateFormat('dd MMMM yyyy').format(_selectedDate),
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  color: FinDT.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrencyField() {
    return _FieldWrapper(
      label: 'Currency',
      child: DropdownButtonFormField<String>(
        value: _selectedCurrency,
        items: ['SAR', 'BHD', 'AED', 'QAR', 'USD']
            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
            .toList(),
        onChanged: (v) => setState(() => _selectedCurrency = v ?? 'SAR'),
        decoration: _inputDecoration(),
        style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
      ),
    );
  }

  Widget _buildAmountField() {
    return _FieldWrapper(
      label: 'Amount *',
      child: TextFormField(
        controller: _amountController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
        ],
        validator: (v) {
          if (v == null || v.isEmpty) return 'Required';
          if (double.tryParse(v) == null) return 'Invalid amount';
          return null;
        },
        decoration: _inputDecoration(hint: 'Enter amount'),
        style: GoogleFonts.inter(
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
          color: FinDT.textPrimary,
        ),
      ),
    );
  }

  Widget _buildSubmittedByField() {
    return _FieldWrapper(
      label: 'Submitted By *',
      child: TextFormField(
        initialValue: _submittedBy,
        onChanged: (v) => _submittedBy = v,
        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        decoration: _inputDecoration(hint: 'e.g., NITHIN'),
        style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
      ),
    );
  }

  Widget _buildPaymentDetailsField() {
    return _FieldWrapper(
      label: 'Payment Details',
      child: TextFormField(
        controller: _paymentDetailsController,
        decoration: _inputDecoration(hint: 'e.g., Cash, STC Pay, Bank Transfer'),
        style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
      ),
    );
  }

  Widget _buildCategoryDropdown(FinanceProvider finProv) {
    return _FieldWrapper(
      label: 'Category *',
      child: DropdownButtonFormField<String>(
        value: _selectedCategory,
        items: finProv.categories
            .where((c) => c.isActive)
            .map((c) => DropdownMenuItem(value: c.name, child: Text(c.name)))
            .toList(),
        onChanged: (v) {
          setState(() {
            _selectedCategory = v;
            _selectedType = null;
          });
        },
        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        decoration: _inputDecoration(hint: 'Select category'),
        style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
      ),
    );
  }

  Widget _buildTypeDropdown(FinanceProvider finProv) {
    final types = _selectedCategory != null
        ? finProv.getTypesForCategory(_selectedCategory!)
        : <ExpenseTypeEntity>[];

    return _FieldWrapper(
      label: 'Type *',
      child: DropdownButtonFormField<String>(
        value: _selectedType,
        items: types
            .map((t) => DropdownMenuItem(value: t.name, child: Text(t.name)))
            .toList(),
        onChanged: (v) => setState(() => _selectedType = v),
        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        decoration: _inputDecoration(
          hint: _selectedCategory == null
              ? 'Select category first'
              : 'Select type',
        ),
        style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
      ),
    );
  }

  Widget _buildAccountDropdown(FundAccountProvider accProv) {
    return _FieldWrapper(
      label: 'Fund Account *',
      child: DropdownButtonFormField<String>(
        value: _selectedAccountId,
        items: accProv.activeAccounts
            .map((a) => DropdownMenuItem(
                  value: a.id,
                  child: Text('${a.name} (${a.code})'),
                ))
            .toList(),
        onChanged: (v) => setState(() => _selectedAccountId = v),
        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        decoration: _inputDecoration(hint: 'Select account'),
        style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
      ),
    );
  }

  Widget _buildDescriptionField() {
    return _FieldWrapper(
      label: 'Description',
      child: TextFormField(
        controller: _descriptionController,
        maxLines: 3,
        decoration: _inputDecoration(hint: 'Brief description of the expense'),
        style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
      ),
    );
  }

  Widget _buildMileageField() {
    return _FieldWrapper(
      label: 'Mileage (KM)',
      child: TextFormField(
        controller: _mileageController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
        ],
        decoration: _inputDecoration(hint: 'e.g., 150'),
        style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
      ),
    );
  }

  Widget _buildTripsField() {
    return _FieldWrapper(
      label: 'Number of Trips',
      child: TextFormField(
        controller: _tripsController,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: _inputDecoration(hint: 'e.g., 5'),
        style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
      ),
    );
  }

  Widget _buildNotesField() {
    return _FieldWrapper(
      label: 'Notes',
      child: TextFormField(
        controller: _notesController,
        maxLines: 2,
        decoration: _inputDecoration(hint: 'Internal notes (optional)'),
        style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
      ),
    );
  }

  Widget _buildReceiptSection(FinanceProvider finProv) {
    return Column(
      children: [
        // Existing receipts
        if (_receiptUrls.isNotEmpty) ...[
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: _receiptUrls.asMap().entries.map((entry) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: FinDT.bgPage,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: FinDT.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.insert_drive_file_outlined,
                      size: 14.sp,
                      color: FinDT.brand,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'Receipt ${entry.key + 1}',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        color: FinDT.textPrimary,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    InkWell(
                      onTap: () {
                        setState(() => _receiptUrls.removeAt(entry.key));
                      },
                      child: Icon(
                        Icons.close_rounded,
                        size: 14.sp,
                        color: FinDT.danger,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 12.h),
        ],
        // Upload button
        InkWell(
          onTap: () => _pickAndUploadReceipt(finProv),
          borderRadius: BorderRadius.circular(12.r),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 24.h),
            decoration: BoxDecoration(
              border: Border.all(color: FinDT.border, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(12.r),
              color: FinDT.bgPage,
            ),
            child: Column(
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  size: 28.sp,
                  color: FinDT.brand,
                ),
                SizedBox(height: 8.h),
                Text(
                  'Click to upload receipt',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: FinDT.textSecondary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'JPG, PNG, PDF up to 10MB',
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    color: FinDT.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(FinanceProvider finProv) {
    return SizedBox(
      width: double.infinity,
      height: 48.h,
      child: FilledButton(
        onPressed: _isSaving ? null : () => _saveExpense(finProv),
        style: FilledButton.styleFrom(
          backgroundColor: FinDT.brand,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        child: _isSaving
            ? SizedBox(
                width: 20.w,
                height: 20.w,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                _isEditing ? 'Update Expense' : 'Save Expense',
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textMuted),
      filled: true,
      fillColor: FinDT.bgPage,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide(color: FinDT.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide(color: FinDT.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide(color: FinDT.brand, width: 1.5),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      isDense: true,
    );
  }

  Future<void> _pickAndUploadReceipt(FinanceProvider finProv) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    final expenseId = _isEditing
        ? widget.expense!.id
        : const Uuid().v4();

    try {
      final url = await finProv.uploadReceipt(file, expenseId);
      setState(() => _receiptUrls.add(url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload: $e')),
        );
      }
    }
  }

  Future<void> _saveExpense(FinanceProvider finProv) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final accProv = context.read<FundAccountProvider>();
      final account = accProv.getAccountById(_selectedAccountId ?? '');

      final expense = ExpenseEntity(
        id: _isEditing ? widget.expense!.id : const Uuid().v4(),
        referenceNumber: _isEditing
            ? widget.expense!.referenceNumber
            : await finProv.generateReferenceNumber(),
        date: _selectedDate,
        createdAt:
            _isEditing ? widget.expense!.createdAt : DateTime.now(),
        updatedAt: _isEditing ? DateTime.now() : null,
        submittedBy: _submittedBy,
        submittedByRole: _submittedByRole,
        expenseCategory: _selectedCategory!,
        expenseType: _selectedType!,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        paymentDetails: _paymentDetailsController.text.isEmpty
            ? null
            : _paymentDetailsController.text,
        amount: double.parse(_amountController.text),
        currency: _selectedCurrency,
        fundAccountId: _selectedAccountId!,
        fundAccountName: account?.name,
        status: _isEditing
            ? widget.expense!.status
            : ExpenseStatus.pending,
        employeeId: _selectedEmployeeId,
        vehicleId: _selectedVehicleId,
        mileageKm: _mileageController.text.isNotEmpty
            ? double.tryParse(_mileageController.text)
            : null,
        receiptUrls: _receiptUrls,
        srvNumber: _srvNumberController.text.isEmpty
            ? null
            : _srvNumberController.text,
        numberOfTrips: _tripsController.text.isNotEmpty
            ? int.tryParse(_tripsController.text)
            : null,
        notes:
            _notesController.text.isEmpty ? null : _notesController.text,
      );

      if (_isEditing) {
        await finProv.updateExpense(expense);
      } else {
        await finProv.insertExpense(expense);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? 'Expense updated!' : 'Expense saved!',
            ),
            backgroundColor: FinDT.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: FinDT.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FIELD WRAPPER
// ═══════════════════════════════════════════════════════════════════════════════

class _FieldWrapper extends StatelessWidget {
  final String label;
  final Widget child;

  const _FieldWrapper({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            color: FinDT.textSecondary,
          ),
        ),
        SizedBox(height: 6.h),
        child,
      ],
    );
  }
}
