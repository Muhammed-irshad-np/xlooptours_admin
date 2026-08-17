import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/fund_account_provider.dart';
import '../../domain/entities/expense_entity.dart';
import '../../domain/entities/expense_category_entity.dart';
import '../../domain/entities/fund_account_entity.dart';
import '../../../../features/employee/presentation/providers/employee_provider.dart';
import '../../../../features/employee/domain/entities/employee_entity.dart';
import '../../../../features/vehicle/presentation/providers/vehicle_provider.dart';
import '../../../../features/vehicle/domain/entities/vehicle_entity.dart';
import '../widgets/finance_dialog_helpers.dart';
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
  String _paymentMethod = 'cash';
  String _selectedCurrency = 'SAR';
  String _submittedBy = '';
  String _submittedByRole = 'ADMIN';
  String? _selectedEmployeeId;
  String? _selectedVehicleId;
  String? _selectedVehicleName;
  List<String> _receiptUrls = [];

  bool get _isVehicleRelated {
    final cat = (_selectedCategory ?? '').trim().toUpperCase();
    final type = (_selectedType ?? '').trim().toUpperCase();

    // Check if category is vehicle related
    if (cat.contains('VEHICLE') ||
        cat.contains('FLEET') ||
        cat.contains('CAR') ||
        cat.contains('AUTO') ||
        cat.contains('TRANSPORT')) {
      return true;
    }

    // Check if expense type is vehicle related
    const vehicleKeywords = [
      'FUEL',
      'PETROL',
      'DIESEL',
      'GAS',
      'MAINTENANCE',
      'REPAIR',
      'CAR WASH',
      'WASH',
      'OIL',
      'TIRE',
      'TYRE',
      'SERVICE',
      'VEHICLE',
      'ODOMETER',
      'MILEAGE',
      'REGISTRATION',
      'FAHAS',
      'MVPI',
      'ISTIMARA',
      'TOLL',
      'SALIK',
      'SPARE',
    ];

    for (final kw in vehicleKeywords) {
      if (type.contains(kw)) return true;
    }

    return false;
  }

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

    _amountController.addListener(_onAmountChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final veh = context.read<VehicleProvider>();
      if (veh.vehicles.isEmpty) {
        veh.fetchAllVehicles();
      }
      final acc = context.read<FundAccountProvider>();
      if (acc.accounts.isEmpty) {
        acc.fetchAllAccounts();
      }
      final fin = context.read<FinanceProvider>();
      if (fin.categories.isEmpty) {
        fin.fetchCategories();
      }
      final emp = context.read<EmployeeProvider>();
      if (emp.employees.isEmpty) {
        emp.fetchAllEmployees();
      }
    });

    if (e != null) {
      _selectedDate = e.date;
      _selectedCategory = e.expenseCategory;
      _selectedType = e.expenseType;
      _selectedAccountId = e.fundAccountId;
      _paymentMethod = e.paymentMethod;
      _selectedCurrency = e.currency;
      _submittedBy = e.submittedBy;
      _submittedByRole = e.submittedByRole;
      _selectedEmployeeId = e.employeeId;
      _selectedVehicleId = e.vehicleId;
      _selectedVehicleName = e.vehicleName;
      _receiptUrls = List.from(e.receiptUrls);
    }
  }

  void _onAmountChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
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
      body: Consumer4<FinanceProvider, FundAccountProvider, EmployeeProvider,
          VehicleProvider>(
        builder: (context, finProv, accProv, empProv, vehProv, _) {
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
                        _buildSubmittedByField(empProv),
                      ]),
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

                  // ── Vehicle (mandatory for vehicle-related expenses) ───────────
                  if (_isVehicleRelated) ...[
                    _buildFormCard(
                      title: 'Vehicle Details *',
                      icon: Icons.directions_car_outlined,
                      children: [
                        _buildVehicleField(vehProv),
                        SizedBox(height: 16.h),
                        _buildMileageField(),
                      ],
                    ),
                    SizedBox(height: 20.h),
                  ],

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
        initialValue: _selectedCurrency,
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

  Widget _buildSubmittedByField(EmployeeProvider empProv) {
    EmployeeEntity? selectedEmp;
    if (_selectedEmployeeId != null && _selectedEmployeeId!.isNotEmpty) {
      final matches = empProv.employees.where((e) => e.id == _selectedEmployeeId);
      if (matches.isNotEmpty) selectedEmp = matches.first;
    }

    return _FieldWrapper(
      label: 'Submitted By *',
      child: FormField<String>(
        initialValue: _selectedEmployeeId,
        validator: (v) => (_selectedEmployeeId == null || _selectedEmployeeId!.isEmpty)
            ? 'Required'
            : null,
        builder: (state) {
          final displayText = selectedEmp != null
              ? '${selectedEmp.fullName}${selectedEmp.position.isNotEmpty ? " (${selectedEmp.position})" : ""}'
              : (_submittedBy.isNotEmpty ? _submittedBy : '');

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => _showEmployeeSearchDialog(context, empProv, (selected) {
                  setState(() {
                    _selectedEmployeeId = selected.id;
                    _submittedBy = selected.fullName;
                    _submittedByRole = selected.position;
                  });
                  state.didChange(selected.id);
                }),
                borderRadius: BorderRadius.circular(10.r),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                  decoration: BoxDecoration(
                    color: FinDT.bgPage,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: state.hasError ? FinDT.danger : FinDT.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_search_outlined,
                        size: 16.sp,
                        color: FinDT.brand,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          displayText.isNotEmpty ? displayText : 'Search & Select Employee...',
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            color: displayText.isNotEmpty
                                ? FinDT.textPrimary
                                : FinDT.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 20.sp,
                        color: FinDT.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              if (state.hasError) ...[
                SizedBox(height: 4.h),
                Padding(
                  padding: EdgeInsets.only(left: 4.w),
                  child: Text(
                    state.errorText!,
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      color: FinDT.danger,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _showEmployeeSearchDialog(
    BuildContext context,
    EmployeeProvider empProv,
    ValueChanged<EmployeeEntity> onSelect,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            final filtered = empProv.employees.where((e) {
              final q = searchQuery.toLowerCase();
              return e.fullName.toLowerCase().contains(q) ||
                  e.position.toLowerCase().contains(q);
            }).toList();

            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: finDialogShape,
              title: finDialogTitle('Select Employee', icon: Icons.person_search_outlined),
              content: SizedBox(
                width: 400.w,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      onChanged: (v) => setStateDialog(() => searchQuery = v),
                      decoration: finDialogInputDecoration(
                        label: 'Search Employee',
                        hint: 'Search by name or position...',
                        prefixIcon: Icons.search,
                      ),
                      style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
                    ),
                    SizedBox(height: 12.h),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: 300.h),
                      child: filtered.isEmpty
                          ? Padding(
                              padding: EdgeInsets.all(24.w),
                              child: Text(
                                'No employees found',
                                style: GoogleFonts.inter(
                                  fontSize: 12.sp,
                                  color: FinDT.textSecondary,
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(
                                height: 1,
                                color: FinDT.borderLight,
                              ),
                              itemBuilder: (context, index) {
                                final emp = filtered[index];
                                return ListTile(
                                  onTap: () {
                                    onSelect(emp);
                                    Navigator.pop(ctx);
                                  },
                                  leading: CircleAvatar(
                                    backgroundColor: FinDT.brand.withValues(alpha: 0.1),
                                    child: Text(
                                      emp.fullName.isNotEmpty
                                          ? emp.fullName[0].toUpperCase()
                                          : 'E',
                                      style: GoogleFonts.inter(
                                        color: FinDT.brand,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12.sp,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    emp.fullName,
                                    style: GoogleFonts.inter(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w600,
                                      color: FinDT.textPrimary,
                                    ),
                                  ),
                                  subtitle: Text(
                                    emp.position.isNotEmpty ? emp.position : 'Employee',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.sp,
                                      color: FinDT.textSecondary,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                finDialogCancelButton(ctx),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryDropdown(FinanceProvider finProv) {
    return _FieldWrapper(
      label: 'Category *',
      child: DropdownButtonFormField<String>(
        initialValue: _selectedCategory,
        items: finProv.categories
            .where((c) => c.isActive)
            .map((c) => DropdownMenuItem(value: c.name, child: Text(c.name)))
            .toList(),
        onChanged: (v) {
          setState(() {
            _selectedCategory = v;
            _selectedType = null;
            if (!_isVehicleRelated) {
              _selectedVehicleId = null;
              _selectedVehicleName = null;
              _mileageController.clear();
            }
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
        initialValue: _selectedType,
        items: types
            .map((t) => DropdownMenuItem(value: t.name, child: Text(t.name)))
            .toList(),
        onChanged: (v) {
          setState(() {
            _selectedType = v;
            if (!_isVehicleRelated) {
              _selectedVehicleId = null;
              _selectedVehicleName = null;
              _mileageController.clear();
            }
          });
        },
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
    final selectedAcc = accProv.getAccountById(_selectedAccountId ?? '');
    final isPettyCash = selectedAcc?.isPettyCash ?? false;
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldWrapper(
          label: 'Fund Account *',
          child: DropdownButtonFormField<String>(
            initialValue: _selectedAccountId,
            isExpanded: true,
            items: accProv.activeAccounts.map((a) {
              final isPos = a.currentBalance >= 0;
              return DropdownMenuItem<String>(
                value: a.id,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            a.name,
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: FinDT.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${a.code} • ${a.typeDisplayName}',
                            style: GoogleFonts.inter(
                              fontSize: 10.sp,
                              color: FinDT.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: isPos
                            ? FinDT.success.withValues(alpha: 0.08)
                            : FinDT.danger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6.r),
                        border: Border.all(
                          color: isPos
                              ? FinDT.success.withValues(alpha: 0.25)
                              : FinDT.danger.withValues(alpha: 0.25),
                          width: 0.8,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${a.currency} ${currencyFormat.format(a.currentBalance)}',
                            style: GoogleFonts.inter(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                              color: isPos ? FinDT.success : FinDT.danger,
                            ),
                          ),
                          Text(
                            'Available',
                            style: GoogleFonts.inter(
                              fontSize: 8.sp,
                              color: isPos ? FinDT.success : FinDT.danger,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            selectedItemBuilder: (context) {
              return accProv.activeAccounts.map((a) {
                final isPos = a.currentBalance >= 0;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${a.name} (${a.code})',
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: FinDT.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: isPos
                            ? FinDT.success.withValues(alpha: 0.1)
                            : FinDT.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        'Avail: ${a.currency} ${currencyFormat.format(a.currentBalance)}',
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                          color: isPos ? FinDT.success : FinDT.danger,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList();
            },
            onChanged: (v) => setState(() => _selectedAccountId = v),
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            decoration: _inputDecoration(hint: 'Select account'),
            style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
          ),
        ),
        if (selectedAcc != null) ...[
          SizedBox(height: 12.h),
          _buildAccountBalanceCard(selectedAcc, currencyFormat),
        ],
        if (isPettyCash && selectedAcc != null) ...[
          SizedBox(height: 14.h),
          _FieldWrapper(
            label: 'Payment Method (Petty Cash Bucket) *',
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _paymentMethod = 'cash'),
                    borderRadius: BorderRadius.circular(10.r),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(
                          vertical: 10.h, horizontal: 12.w),
                      decoration: BoxDecoration(
                        color: _paymentMethod == 'cash'
                            ? FinDT.brand.withValues(alpha: 0.1)
                            : FinDT.bgPage,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: _paymentMethod == 'cash'
                              ? FinDT.brand
                              : FinDT.border,
                          width: _paymentMethod == 'cash' ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.payments_outlined,
                                size: 15.sp,
                                color: _paymentMethod == 'cash'
                                    ? FinDT.brand
                                    : FinDT.textSecondary,
                              ),
                              SizedBox(width: 6.w),
                              Text(
                                'Physical Cash',
                                style: GoogleFonts.inter(
                                  fontSize: 12.sp,
                                  fontWeight: _paymentMethod == 'cash'
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: _paymentMethod == 'cash'
                                      ? FinDT.brand
                                      : FinDT.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            'Avail: ${selectedAcc.currency} ${currencyFormat.format(selectedAcc.cashBalance)}',
                            style: GoogleFonts.inter(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                              color: selectedAcc.cashBalance >= 0
                                  ? (_paymentMethod == 'cash'
                                      ? FinDT.brand
                                      : FinDT.textSecondary)
                                  : FinDT.danger,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _paymentMethod = 'stcPay'),
                    borderRadius: BorderRadius.circular(10.r),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(
                          vertical: 10.h, horizontal: 12.w),
                      decoration: BoxDecoration(
                        color: _paymentMethod == 'stcPay'
                            ? const Color(0xFF6D28D9).withValues(alpha: 0.1)
                            : FinDT.bgPage,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: _paymentMethod == 'stcPay'
                              ? const Color(0xFF6D28D9)
                              : FinDT.border,
                          width: _paymentMethod == 'stcPay' ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.phone_android_outlined,
                                size: 15.sp,
                                color: _paymentMethod == 'stcPay'
                                    ? const Color(0xFF6D28D9)
                                    : FinDT.textSecondary,
                              ),
                              SizedBox(width: 6.w),
                              Text(
                                'STC Pay',
                                style: GoogleFonts.inter(
                                  fontSize: 12.sp,
                                  fontWeight: _paymentMethod == 'stcPay'
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: _paymentMethod == 'stcPay'
                                      ? const Color(0xFF6D28D9)
                                      : FinDT.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            'Avail: ${selectedAcc.currency} ${currencyFormat.format(selectedAcc.stcPayBalance)}',
                            style: GoogleFonts.inter(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                              color: selectedAcc.stcPayBalance >= 0
                                  ? (_paymentMethod == 'stcPay'
                                      ? const Color(0xFF6D28D9)
                                      : FinDT.textSecondary)
                                  : FinDT.danger,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAccountBalanceCard(
    FundAccountEntity account,
    NumberFormat currencyFormat,
  ) {
    final isPettyCash = account.isPettyCash;
    final enteredAmount = double.tryParse(_amountController.text) ?? 0.0;
    final relevantBalance = isPettyCash
        ? (_paymentMethod == 'cash'
            ? account.cashBalance
            : account.stcPayBalance)
        : account.currentBalance;
    final isOverBalance = enteredAmount > 0 && enteredAmount > relevantBalance;
    final remaining = relevantBalance - enteredAmount;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: isOverBalance ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isOverBalance
              ? FinDT.danger.withValues(alpha: 0.3)
              : FinDT.success.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 16.sp,
                    color: isOverBalance ? FinDT.danger : FinDT.success,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Available Balance',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color:
                          isOverBalance ? FinDT.danger : const Color(0xFF166534),
                    ),
                  ),
                ],
              ),
              Text(
                '${account.currency} ${currencyFormat.format(account.currentBalance)}',
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: account.currentBalance >= 0
                      ? const Color(0xFF166534)
                      : FinDT.danger,
                ),
              ),
            ],
          ),
          if (isPettyCash) ...[
            SizedBox(height: 8.h),
            Divider(
              height: 1,
              color: isOverBalance
                  ? FinDT.danger.withValues(alpha: 0.15)
                  : FinDT.success.withValues(alpha: 0.15),
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.payments_outlined,
                          size: 13.sp, color: FinDT.brand),
                      SizedBox(width: 4.w),
                      Text(
                        'Cash: ',
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          color: FinDT.textSecondary,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          '${account.currency} ${currencyFormat.format(account.cashBalance)}',
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            color: account.cashBalance >= 0
                                ? FinDT.textPrimary
                                : FinDT.danger,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 12.h,
                  width: 1,
                  color: FinDT.border,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.phone_android_outlined,
                          size: 13.sp, color: const Color(0xFF6D28D9)),
                      SizedBox(width: 4.w),
                      Text(
                        'STC Pay: ',
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          color: FinDT.textSecondary,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          '${account.currency} ${currencyFormat.format(account.stcPayBalance)}',
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            color: account.stcPayBalance >= 0
                                ? FinDT.textPrimary
                                : FinDT.danger,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (enteredAmount > 0) ...[
            SizedBox(height: 8.h),
            Divider(
              height: 1,
              color: isOverBalance
                  ? FinDT.danger.withValues(alpha: 0.15)
                  : FinDT.success.withValues(alpha: 0.15),
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Icon(
                  isOverBalance
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 14.sp,
                  color: isOverBalance ? FinDT.danger : FinDT.success,
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    isOverBalance
                        ? 'Expense amount (${currencyFormat.format(enteredAmount)}) exceeds ${isPettyCash ? (_paymentMethod == "cash" ? "Physical Cash" : "STC Pay") : "available"} balance (${currencyFormat.format(relevantBalance)})'
                        : 'Projected balance after expense: ${account.currency} ${currencyFormat.format(remaining)}',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight:
                          isOverBalance ? FontWeight.w600 : FontWeight.w500,
                      color: isOverBalance
                          ? FinDT.danger
                          : const Color(0xFF166534),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVehicleField(VehicleProvider vehProv) {
    VehicleEntity? selected;
    if (_selectedVehicleId != null && _selectedVehicleId!.isNotEmpty) {
      final matches =
          vehProv.vehicles.where((v) => v.id == _selectedVehicleId);
      if (matches.isNotEmpty) selected = matches.first;
    }
    final display = selected != null
        ? '${selected.plateNumber} · ${selected.make} ${selected.model}'
        : (_selectedVehicleName ?? '');

    return FormField<String>(
      key: ValueKey(_selectedVehicleId),
      initialValue: _selectedVehicleId,
      validator: (v) {
        if (_isVehicleRelated &&
            (_selectedVehicleId == null || _selectedVehicleId!.isEmpty)) {
          return 'Please select a vehicle';
        }
        return null;
      },
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => _showVehicleSearchDialog(context, vehProv, (v) {
                setState(() {
                  _selectedVehicleId = v.id;
                  _selectedVehicleName =
                      '${v.plateNumber} · ${v.make} ${v.model}';
                });
                state.didChange(v.id);
              }),
              borderRadius: BorderRadius.circular(10.r),
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: FinDT.bgPage,
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: state.hasError ? FinDT.danger : FinDT.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.directions_car_outlined,
                      size: 16.sp,
                      color: FinDT.brand,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        display.isNotEmpty
                            ? display
                            : 'Search & select vehicle *',
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          color: display.isNotEmpty
                              ? FinDT.textPrimary
                              : FinDT.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_selectedVehicleId != null)
                      InkWell(
                        onTap: () {
                          setState(() {
                            _selectedVehicleId = null;
                            _selectedVehicleName = null;
                          });
                          state.didChange(null);
                        },
                        child: Icon(Icons.close, size: 16.sp, color: FinDT.textSecondary),
                      )
                    else
                      Icon(Icons.search, size: 16.sp, color: FinDT.textSecondary),
                  ],
                ),
              ),
            ),
            if (state.hasError)
              Padding(
                padding: EdgeInsets.only(top: 6.h, left: 4.w),
                child: Text(
                  state.errorText!,
                  style: GoogleFonts.inter(fontSize: 11.sp, color: FinDT.danger),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMileageField() {
    return _FieldWrapper(
      label: 'Odometer / Mileage (km)',
      child: TextFormField(
        controller: _mileageController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
        ],
        decoration: _inputDecoration(hint: 'Optional km reading'),
        style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
      ),
    );
  }

  void _showVehicleSearchDialog(
    BuildContext context,
    VehicleProvider vehProv,
    ValueChanged<VehicleEntity> onSelect,
  ) {
    final searchCtrl = TextEditingController();
    var query = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final vehicles = vehProv.vehicles.where((v) {
            if (!v.isActive) return false;
            if (query.isEmpty) return true;
            final q = query.toLowerCase();
            return v.plateNumber.toLowerCase().contains(q) ||
                v.make.toLowerCase().contains(q) ||
                v.model.toLowerCase().contains(q);
          }).toList();

          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: finDialogShape,
            title: finDialogTitle('Select Vehicle', icon: Icons.directions_car_outlined),
            content: SizedBox(
              width: 440.w,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchCtrl,
                    decoration: finDialogInputDecoration(
                      label: 'Search Vehicle',
                      hint: 'Search plate, make, model...',
                      prefixIcon: Icons.search,
                    ),
                    style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
                    onChanged: (v) => setLocal(() => query = v),
                  ),
                  SizedBox(height: 12.h),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: 300.h),
                    child: vehicles.isEmpty
                        ? Padding(
                            padding: EdgeInsets.all(24.w),
                            child: Text(
                              'No vehicles found',
                              style: GoogleFonts.inter(
                                fontSize: 12.sp,
                                color: FinDT.textSecondary,
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: vehicles.length,
                            separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              color: FinDT.borderLight,
                            ),
                            itemBuilder: (_, i) {
                              final v = vehicles[i];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: FinDT.brand.withValues(alpha: 0.1),
                                  child: Icon(
                                    Icons.directions_car_rounded,
                                    color: FinDT.brand,
                                    size: 18.sp,
                                  ),
                                ),
                                title: Text(
                                  v.plateNumber,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.sp,
                                    color: FinDT.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  '${v.make} ${v.model} · ${v.year}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.sp,
                                    color: FinDT.textSecondary,
                                  ),
                                ),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  onSelect(v);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              finDialogCancelButton(ctx),
            ],
          );
        },
      ),
    );
  }

  bool get _isReceiptRequired {
    final amt = double.tryParse(_amountController.text) ?? 0.0;
    return amt >= 100.0;
  }

  Widget _buildReceiptSection(FinanceProvider finProv) {
    final requiresReceipt = _isReceiptRequired;
    final isMissing = requiresReceipt && _receiptUrls.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (requiresReceipt)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            margin: EdgeInsets.only(bottom: 12.h),
            decoration: BoxDecoration(
              color: isMissing
                  ? FinDT.danger.withValues(alpha: 0.08)
                  : FinDT.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: isMissing
                    ? FinDT.danger.withValues(alpha: 0.3)
                    : FinDT.success.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isMissing
                      ? Icons.error_outline_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 16.sp,
                  color: isMissing ? FinDT.danger : FinDT.success,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    isMissing
                        ? 'Receipt is required for expenses of 100.00 SAR or more.'
                        : 'Receipt attached (policy requirement satisfied).',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: isMissing ? FinDT.danger : FinDT.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
        // Upload Button
        OutlinedButton.icon(
          onPressed: () => _pickAndUploadReceipt(finProv),
          icon: Icon(Icons.upload_file, size: 16.sp),
          label: Text(
            'Upload Receipt / Document',
            style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: isMissing ? FinDT.danger : FinDT.brand,
            side: BorderSide(color: isMissing ? FinDT.danger : FinDT.border),
            padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
            minimumSize: Size(double.infinity, 44.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.r),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(FinanceProvider finProv) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : () => _saveExpense(finProv),
        style: ElevatedButton.styleFrom(
          backgroundColor: FinDT.brand,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16.h),
          elevation: 0,
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
                _isEditing ? 'Update Expense' : 'Submit Expense',
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
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

    if (_isVehicleRelated &&
        (_selectedVehicleId == null || _selectedVehicleId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a vehicle for vehicle-related expenses'),
          backgroundColor: FinDT.danger,
        ),
      );
      return;
    }

    final policy = finProv.policy;
    final amountVal = double.tryParse(_amountController.text) ?? 0.0;
    if (amountVal >= policy.receiptRequiredAbove && _receiptUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'A receipt or bill document is required for expenses of ${policy.receiptRequiredAbove.toStringAsFixed(2)} SAR or more.',
          ),
          backgroundColor: FinDT.danger,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final accProv = context.read<FundAccountProvider>();
      final account = accProv.getAccountById(_selectedAccountId ?? '');

      final authUser = context.read<AuthProvider>().user;
      final amount = double.parse(_amountController.text);

      final expense = ExpenseEntity(
        id: _isEditing ? widget.expense!.id : const Uuid().v4(),
        referenceNumber: _isEditing
            ? widget.expense!.referenceNumber
            : await finProv.generateReferenceNumber(),
        date: _selectedDate,
        createdAt:
            _isEditing ? widget.expense!.createdAt : DateTime.now(),
        updatedAt: _isEditing ? DateTime.now() : null,
        submittedBy: _submittedBy.isNotEmpty
            ? _submittedBy
            : (authUser?.actorLabel ?? ''),
        submittedByRole: _submittedByRole.isNotEmpty
            ? _submittedByRole
            : (authUser?.role.name.toUpperCase() ?? 'USER'),
        submittedByUserId:
            widget.expense?.submittedByUserId ?? authUser?.id,
        expenseCategory: _selectedCategory!,
        expenseType: _selectedType!,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        paymentDetails: _paymentDetailsController.text.isEmpty
            ? null
            : _paymentDetailsController.text,
        paymentMethod: _paymentMethod,
        amount: amount,
        amountMinor: (amount * 100).round(),
        currency: _selectedCurrency,
        fundAccountId: _selectedAccountId!,
        fundAccountName: account?.name,
        isNonWallet: false,
        status: _isEditing
            ? widget.expense!.status
            : ExpenseStatus.pending,
        employeeId: _selectedEmployeeId,
        vehicleId: _isVehicleRelated ? _selectedVehicleId : null,
        vehicleName: _isVehicleRelated ? _selectedVehicleName : null,
        mileageKm: _isVehicleRelated && _mileageController.text.isNotEmpty
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
