import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../employee/presentation/providers/employee_provider.dart';
import '../../domain/entities/cash_advance_entity.dart';
import '../../domain/entities/expense_category_entity.dart';
import '../../domain/entities/expense_entity.dart';
import '../pages/finance_dashboard_page.dart';
import '../providers/cash_advance_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/fund_account_provider.dart';
import 'finance_dialog_helpers.dart';

/// Settles an advance as cash handed back and/or what the employee spent it
/// on. Each spend is recorded as a tracking-only expense, so the Expenses
/// list shows the real cost without taking the money out of the fund twice.
Future<void> showSettleAdvanceDialog(
  BuildContext context,
  CashAdvanceEntity advance,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _SettleAdvanceDialog(advance: advance),
  );
}

/// One thing the employee paid for out of the advance.
class _SpentLine {
  _SpentLine(this.date);

  String? category;
  String? type;
  DateTime date;
  XFile? receipt;
  final amount = TextEditingController();
  final description = TextEditingController();

  double get value => double.tryParse(amount.text.trim()) ?? 0;

  void dispose() {
    amount.dispose();
    description.dispose();
  }
}

class _SettleAdvanceDialog extends StatefulWidget {
  final CashAdvanceEntity advance;

  const _SettleAdvanceDialog({required this.advance});

  @override
  State<_SettleAdvanceDialog> createState() => _SettleAdvanceDialogState();
}

class _SettleAdvanceDialogState extends State<_SettleAdvanceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _returned = TextEditingController();
  final _lines = <_SpentLine>[];
  bool _isSettling = false;
  String? _error;

  CashAdvanceEntity get _advance => widget.advance;
  double get _returnedValue => double.tryParse(_returned.text.trim()) ?? 0;
  double get _spentTotal => _lines.fold(0.0, (acc, l) => acc + l.value);
  double get _total => _returnedValue + _spentTotal;
  double get _remaining => _advance.outstanding - _total;

  @override
  void initState() {
    super.initState();
    _returned.addListener(_refresh);
    final fin = context.read<FinanceProvider>();
    if (fin.categories.isEmpty) fin.fetchCategories();
  }

  @override
  void dispose() {
    _returned.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  void _refresh() => setState(() {});

  void _addLine() {
    final line = _SpentLine(DateUtils.dateOnly(DateTime.now()));
    line.amount.addListener(_refresh);
    setState(() => _lines.add(line));
  }

  void _removeLine(_SpentLine line) {
    setState(() => _lines.remove(line));
    line.dispose();
  }

  String _fmt(double v) => v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final fin = context.watch<FinanceProvider>();
    final categories = fin.categories.where((c) => c.isActive).toList();

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: finDialogShape,
      title: finDialogTitle(
        'Settle Cash Advance',
        icon: Icons.receipt_long_rounded,
      ),
      content: SizedBox(
        width: 480.w,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryBox(),
                SizedBox(height: 14.h),
                TextFormField(
                  controller: _returned,
                  enabled: !_isSettling,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  decoration: finDialogInputDecoration(
                    label: 'Cash Returned',
                    hint: '0.00',
                    prefixIcon: Icons.keyboard_return_rounded,
                    suffixText: _advance.currency,
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: FinDT.textPrimary,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: 4.w, top: 4.h),
                  child: Text(
                    'Deposited back to '
                    '${_advance.fundAccountName ?? _advance.fundAccountId}',
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      color: FinDT.textSecondary,
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Spent by ${_advance.employeeName}',
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: FinDT.textPrimary,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _isSettling ? null : _addLine,
                      icon: Icon(Icons.add_rounded, size: 16.sp),
                      label: Text(
                        'Add Expense',
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_lines.isEmpty)
                  Text(
                    'Add what the advance was spent on. Each one is recorded '
                    'in Expenses without being deducted from the fund again.',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      color: FinDT.textMuted,
                    ),
                  ),
                for (final line in _lines) ...[
                  _buildLine(line, categories, fin),
                  SizedBox(height: 10.h),
                ],
                SizedBox(height: 12.h),
                _buildTotals(),
                if (_error != null) ...[
                  SizedBox(height: 8.h),
                  Text(
                    _error!,
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      color: FinDT.danger,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        finDialogCancelButton(
          context,
          onPressed: _isSettling ? () {} : null,
        ),
        finDialogActionButton(
          onPressed: _isSettling ? null : _submit,
          label: 'Confirm Settlement',
          backgroundColor: FinDT.brand,
          isLoading: _isSettling,
        ),
      ],
    );
  }

  Widget _buildSummaryBox() {
    Widget row(String label, String value, Color color) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: FinDT.textSecondary,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        );

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: FinDT.bgPage,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: FinDT.border),
      ),
      child: Column(
        children: [
          row('Recipient Staff:', _advance.employeeName, FinDT.textPrimary),
          SizedBox(height: 6.h),
          row(
            'Outstanding Float:',
            '${_fmt(_advance.outstanding)} ${_advance.currency}',
            FinDT.brand,
          ),
        ],
      ),
    );
  }

  Widget _buildLine(
    _SpentLine line,
    List<ExpenseCategoryEntity> categories,
    FinanceProvider fin,
  ) {
    final category =
        categories.where((c) => c.name == line.category).firstOrNull;
    final types = category == null
        ? const <String>[]
        : category.expenseTypes
            .where((t) => t.isActive)
            .map((t) => t.name)
            .toList();
    final receiptRequired =
        line.value >= fin.policy.receiptRequiredAbove && line.receipt == null;
    final textStyle = GoogleFonts.inter(
      fontSize: 12.sp,
      color: FinDT.textPrimary,
    );

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: FinDT.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: line.category,
                  isExpanded: true,
                  decoration: finDialogInputDecoration(label: 'Category *'),
                  style: textStyle,
                  items: categories
                      .map((c) => DropdownMenuItem(
                            value: c.name,
                            child: Text(c.name),
                          ))
                      .toList(),
                  onChanged: _isSettling
                      ? null
                      : (v) => setState(() {
                            line.category = v;
                            line.type = null;
                          }),
                  validator: (v) => v == null ? 'Required' : null,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('type_${line.hashCode}_${line.category}'),
                  initialValue: line.type,
                  isExpanded: true,
                  decoration: finDialogInputDecoration(label: 'Type *'),
                  style: textStyle,
                  items: types
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: _isSettling
                      ? null
                      : (v) => setState(() => line.type = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: _isSettling ? null : () => _removeLine(line),
                icon: Icon(
                  Icons.close_rounded,
                  size: 18.sp,
                  color: FinDT.textSecondary,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: line.amount,
                  enabled: !_isSettling,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  decoration: finDialogInputDecoration(
                    label: 'Amount *',
                    suffixText: _advance.currency,
                  ),
                  style: textStyle,
                  validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                      ? 'Enter an amount'
                      : null,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: InkWell(
                  onTap: _isSettling ? null : () => _pickDate(line),
                  borderRadius: BorderRadius.circular(10.r),
                  child: InputDecorator(
                    decoration: finDialogInputDecoration(
                      label: 'Spent On *',
                      prefixIcon: Icons.calendar_today_rounded,
                    ),
                    child: Text(
                      DateFormat('dd MMM yyyy').format(line.date),
                      style: textStyle,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          TextFormField(
            controller: line.description,
            enabled: !_isSettling,
            decoration: finDialogInputDecoration(
              label: 'Description',
              hint: 'What was this spent on?',
            ),
            style: textStyle,
          ),
          SizedBox(height: 6.h),
          TextButton.icon(
            onPressed: _isSettling ? null : () => _pickReceipt(line),
            icon: Icon(
              line.receipt != null
                  ? Icons.check_circle_rounded
                  : Icons.attach_file_rounded,
              size: 16.sp,
              color: line.receipt != null ? FinDT.success : FinDT.brand,
            ),
            label: Text(
              line.receipt != null ? line.receipt!.name : 'Attach Receipt',
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: line.receipt != null ? FinDT.success : FinDT.brand,
              ),
            ),
          ),
          if (receiptRequired)
            Text(
              'A receipt is required for amounts of '
              '${_fmt(fin.policy.receiptRequiredAbove)} SAR or more.',
              style: GoogleFonts.inter(fontSize: 10.sp, color: FinDT.warning),
            ),
        ],
      ),
    );
  }

  Widget _buildTotals() {
    final over = _remaining < -1e-6;
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: over ? FinDT.danger.withValues(alpha: 0.06) : FinDT.bgPage,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: over ? FinDT.danger.withValues(alpha: 0.4) : FinDT.border,
        ),
      ),
      child: Text(
        over
            ? 'Returned + spent is ${_fmt(_total)} ${_advance.currency}, more '
                'than the ${_fmt(_advance.outstanding)} outstanding.'
            : 'Settling ${_fmt(_total)} ${_advance.currency} '
                '(${_fmt(_returnedValue)} returned, ${_fmt(_spentTotal)} spent). '
                '${_remaining <= 1e-6 ? 'The advance will be closed.' : '${_fmt(_remaining)} stays outstanding.'}',
        style: GoogleFonts.inter(
          fontSize: 11.sp,
          color: over ? FinDT.danger : FinDT.textSecondary,
        ),
      ),
    );
  }

  Future<void> _pickDate(_SpentLine line) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: line.date,
      firstDate: DateUtils.dateOnly(_advance.issuedAt),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: FinDT.brand),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => line.date = picked);
  }

  Future<void> _pickReceipt(_SpentLine line) async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => line.receipt = file);
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    if (_total <= 0) {
      setState(() => _error = 'Enter the cash returned or add an expense.');
      return;
    }
    if (_remaining < -1e-6) {
      setState(() => _error = 'Cannot settle more than the outstanding '
          '${_fmt(_advance.outstanding)} ${_advance.currency}.');
      return;
    }
    final fin = context.read<FinanceProvider>();
    final receiptAbove = fin.policy.receiptRequiredAbove;
    if (_lines.any((l) => l.value >= receiptAbove && l.receipt == null)) {
      setState(() => _error = 'Attach a receipt for every expense of '
          '${_fmt(receiptAbove)} SAR or more.');
      return;
    }

    final user = context.read<AuthProvider>().user;
    final advProv = context.read<CashAdvanceProvider>();
    final fundProv = context.read<FundAccountProvider>();
    final employee = context
        .read<EmployeeProvider>()
        .employees
        .where((e) => e.id == _advance.employeeId)
        .firstOrNull;
    final role = (employee?.position.isNotEmpty ?? false)
        ? employee!.position.toUpperCase()
        : 'EMPLOYEE';

    setState(() => _isSettling = true);
    try {
      // Receipts go up first so the only step left that can fail is the
      // settlement itself.
      final spent = <ExpenseEntity>[];
      for (final line in _lines) {
        final id = const Uuid().v4();
        final description = line.description.text.trim();
        spent.add(
          ExpenseEntity(
            id: id,
            referenceNumber: '',
            date: line.date,
            createdAt: DateTime.now(),
            submittedBy: _advance.employeeName,
            submittedByRole: role,
            submittedByEmployeeId: _advance.employeeId,
            expenseCategory: line.category!,
            expenseType: line.type!,
            description: description.isEmpty ? null : description,
            amount: line.value,
            currency: _advance.currency,
            fundAccountId: _advance.fundAccountId,
            receiptUrls: [
              if (line.receipt != null)
                await fin.uploadReceipt(line.receipt!, id),
            ],
            notes: 'Paid from cash advance: ${_advance.purpose}',
          ),
        );
      }

      await advProv.settle(
        advanceId: _advance.id,
        amount: _returnedValue,
        actorName: user?.actorLabel ?? 'Admin',
        actorUserId: user?.id ?? '',
        returnToFund: true,
        spentExpenses: spent,
      );
      await fundProv.fetchAllAccounts();
      if (spent.isNotEmpty) fin.fetchAllExpenses();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      finSafePop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Settled ${_fmt(_total)} ${_advance.currency} for '
            '${_advance.employeeName}',
          ),
          backgroundColor: FinDT.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSettling = false;
        _error = 'Failed to settle advance: $e';
      });
    }
  }
}
