import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../features/employee/domain/entities/employee_entity.dart';
import '../../features/finance/domain/entities/expense_entity.dart';
import '../../features/finance/domain/entities/finance_policy_entity.dart';
import '../../features/finance/domain/entities/fund_account_entity.dart';
import '../../widgets/custom_date_picker.dart';

/// What a cost is tracked against — an employee, a vehicle, or both.
///
/// An iqama renewal attributes to an employee; an istimara renewal to a
/// vehicle; a driver's traffic fine could carry both.
class ExpenseAttribution {
  /// Shown on the "Expense For" row, e.g. "Ahmed Khan" or "ABC-1234 · Hiace".
  final String label;

  final String? employeeId;
  final String? employeeName;
  final String? vehicleId;
  final String? vehicleName;

  /// Odometer at the time of the spend, where the host dialog knows it.
  final double? mileageKm;

  const ExpenseAttribution({
    required this.label,
    this.employeeId,
    this.employeeName,
    this.vehicleId,
    this.vehicleName,
    this.mileageKm,
  });
}

/// Mutable answers for the inline "log this cost to Finance" section.
///
/// A host dialog owns one of these, renders an [InlineExpenseSection] with it,
/// and on save calls [validate] then [buildDraft]. Keeping the state here
/// rather than inside the widget lets the host read the answers back without
/// reaching into another widget's State.
class InlineExpenseController {
  InlineExpenseController({
    required this.category,
    required String defaultType,
    TextEditingController? amountSource,
  }) : expenseType = defaultType,
       _externalAmount = amountSource;

  /// Expense category these rows land under, e.g. 'EMPLOYEES' or 'VEHICLES'.
  final String category;

  /// Set when the host dialog already asks for the amount for its own reasons
  /// (a recharge cost, a service cost), so the section does not ask twice.
  final TextEditingController? _externalAmount;

  bool enabled = false;
  bool showMore = false;

  String expenseType;
  String currency = 'SAR';
  String paymentMethod = 'cash';
  String? accountId;

  /// null means the signed-in user submitted it.
  String? submitterEmployeeId;

  XFile? receipt;
  DateTime date = DateTime.now();

  final TextEditingController ownAmount = TextEditingController();
  final TextEditingController notes = TextEditingController();

  bool get usesExternalAmount => _externalAmount != null;
  TextEditingController get amountField => _externalAmount ?? ownAmount;

  double get amount => double.tryParse(amountField.text.trim()) ?? 0.0;

  bool receiptRequired(FinancePolicyEntity policy) =>
      amount >= policy.receiptRequiredAbove;

  /// Returns the reason this cannot be saved, or null when it is good to go.
  /// Always null while the section is switched off.
  String? validate(FinancePolicyEntity policy) {
    if (!enabled) return null;
    if (amount <= 0) {
      return 'Enter the amount spent, or untick "Log cost to Finance".';
    }
    if (accountId == null || accountId!.isEmpty) {
      return 'Select which account this was paid from.';
    }
    if (receiptRequired(policy) && receipt == null) {
      return 'A receipt is required for amounts of '
          '${policy.receiptRequiredAbove.toStringAsFixed(2)} SAR or more.';
    }
    return null;
  }

  /// The expense as the dialog currently describes it, minus what is only
  /// known at save time (id, reference number, uploaded receipt url).
  ExpenseEntity buildDraft({
    required ExpenseAttribution attribution,
    required String description,
    required List<FundAccountEntity> accounts,
    required List<EmployeeEntity> employees,
    required String fallbackSubmitterName,
    required String fallbackSubmitterRole,
    String? fallbackSubmitterUserId,
  }) {
    final account = accounts.where((a) => a.id == accountId);
    final submitter = submitterEmployeeId == null
        ? null
        : employees.where((e) => e.id == submitterEmployeeId).firstOrNull;

    return ExpenseEntity(
      id: '',
      referenceNumber: '',
      date: date,
      createdAt: DateTime.now(),
      submittedBy: submitter?.fullName ?? fallbackSubmitterName,
      submittedByRole: submitter != null
          ? (submitter.position.isNotEmpty
                ? submitter.position.toUpperCase()
                : 'EMPLOYEE')
          : fallbackSubmitterRole,
      submittedByUserId: submitter == null ? fallbackSubmitterUserId : null,
      expenseCategory: category,
      expenseType: expenseType,
      description: description,
      paymentMethod: paymentMethod,
      amount: amount,
      currency: currency,
      fundAccountId: accountId ?? '',
      fundAccountName: account.isEmpty ? null : account.first.name,
      status: ExpenseStatus.pending,
      employeeId: attribution.employeeId,
      employeeName: attribution.employeeName,
      submittedByEmployeeId: submitterEmployeeId,
      vehicleId: attribution.vehicleId,
      vehicleName: attribution.vehicleName,
      mileageKm: attribution.mileageKm,
      notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
    );
  }

  void dispose() {
    ownAmount.dispose();
    notes.dispose();
  }
}

/// Inline "log this cost to Finance" block for a dialog that is already
/// updating something else — a renewed document, a completed service.
///
/// Everything derivable is shown rather than asked: who it is for comes from
/// what the host dialog is editing, and who is filing it is the signed-in
/// user unless they say otherwise under "More options".
class InlineExpenseSection extends StatelessWidget {
  final InlineExpenseController controller;
  final ExpenseAttribution attribution;

  /// Label for the checkbox, e.g. 'Log renewal cost to Finance'.
  final String enableLabel;

  /// How the signed-in user is shown on the "Submitted By" row.
  final String submitterLabel;

  /// Replaces the checkbox subtitle where "spent on <label>" reads oddly — a
  /// company-level document is not spent *on* anyone in particular.
  final String? subtitle;

  final List<FundAccountEntity> accounts;
  final List<EmployeeEntity> employees;
  final List<String> typeOptions;
  final FinancePolicyEntity policy;

  final bool isSaving;

  /// Host's setState, so the dialog rebuilds when an answer changes.
  final VoidCallback onChanged;

  const InlineExpenseSection({
    super.key,
    required this.controller,
    required this.attribution,
    required this.enableLabel,
    required this.submitterLabel,
    required this.accounts,
    required this.employees,
    required this.typeOptions,
    required this.policy,
    required this.onChanged,
    this.subtitle,
    this.isSaving = false,
  });

  String _fileName(XFile f) {
    final base = p.basename(f.path);
    return base.length > 30 ? '...${base.substring(base.length - 27)}' : base;
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        const Divider(),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
          value: c.enabled,
          onChanged: isSaving
              ? null
              : (v) {
                  c.enabled = v ?? false;
                  onChanged();
                },
          title: Text(
            enableLabel,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            subtitle ??
                'Tracks what the company spent on ${attribution.label}.',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ),

        if (c.enabled) ...[
          const SizedBox(height: 4),
          _FactRow(label: 'Expense For', value: attribution.label),
          const SizedBox(height: 6),
          _FactRow(
            label: 'Submitted By',
            value: c.submitterEmployeeId == null
                ? submitterLabel
                : (employees
                          .where((e) => e.id == c.submitterEmployeeId)
                          .firstOrNull
                          ?.fullName ??
                      submitterLabel),
          ),
          const SizedBox(height: 14),

          if (c.usesExternalAmount)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Amount uses the cost entered above.',
                style: TextStyle(fontSize: 11, color: Colors.blue[800]),
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: c.ownAmount,
                    enabled: !isSaving,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: c.currency,
                    decoration: const InputDecoration(
                      labelText: 'Currency',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const ['SAR', 'BHD', 'AED', 'QAR', 'USD']
                        .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                        .toList(),
                    onChanged: isSaving
                        ? null
                        : (v) {
                            c.currency = v ?? 'SAR';
                            onChanged();
                          },
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            initialValue: c.accountId,
            decoration: const InputDecoration(
              labelText: 'Paid From',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            isExpanded: true,
            items: accounts
                .map(
                  (a) => DropdownMenuItem(
                    value: a.id,
                    child: Text(
                      '${a.name} · ${a.currentBalance.toStringAsFixed(2)} ${a.currency}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: isSaving
                ? null
                : (v) {
                    c.accountId = v;
                    final match = accounts.where((a) => a.id == v);
                    if (match.isNotEmpty) c.currency = match.first.currency;
                    onChanged();
                  },
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: c.paymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Method',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'stcPay', child: Text('STC Pay')),
                    DropdownMenuItem(value: 'bank', child: Text('Bank')),
                  ],
                  onChanged: isSaving
                      ? null
                      : (v) {
                          c.paymentMethod = v ?? 'cash';
                          onChanged();
                        },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: c.expenseType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  isExpanded: true,
                  items: typeOptions
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(t, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: isSaving
                      ? null
                      : (v) {
                          c.expenseType = v ?? c.expenseType;
                          onChanged();
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          OutlinedButton.icon(
            icon: Icon(
              c.receipt != null
                  ? Icons.check_circle
                  : Icons.receipt_long_outlined,
              size: 18,
              color: c.receipt != null ? Colors.green : Colors.blue[700],
            ),
            label: Text(
              c.receipt != null ? _fileName(c.receipt!) : 'Attach Receipt',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.receipt != null ? Colors.green[800] : Colors.blue[700],
              ),
            ),
            onPressed: isSaving
                ? null
                : () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.any,
                      allowMultiple: false,
                    );
                    if (result != null && result.files.isNotEmpty) {
                      c.receipt = XFile(result.files.first.path ?? '');
                      onChanged();
                    }
                  },
          ),
          if (c.receiptRequired(policy) && c.receipt == null) ...[
            const SizedBox(height: 6),
            Text(
              'A receipt is required for amounts of '
              '${policy.receiptRequiredAbove.toStringAsFixed(2)} SAR or more.',
              style: TextStyle(fontSize: 11, color: Colors.orange[800]),
            ),
          ],

          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: isSaving
                  ? null
                  : () {
                      c.showMore = !c.showMore;
                      onChanged();
                    },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: Icon(
                c.showMore ? Icons.expand_less : Icons.expand_more,
                size: 18,
              ),
              label: Text(c.showMore ? 'Fewer options' : 'More options'),
            ),
          ),

          // Only needed when the spend was not today, by the signed-in user,
          // for the self-evident reason.
          if (c.showMore) ...[
            const SizedBox(height: 4),
            CustomDatePicker(
              label: 'Expense Date',
              date: c.date,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: c.date,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  c.date = picked;
                  onChanged();
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: c.submitterEmployeeId,
              decoration: const InputDecoration(
                labelText: 'Submitted By',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              isExpanded: true,
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    '$submitterLabel (you)',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ...employees.map(
                  (e) => DropdownMenuItem<String?>(
                    value: e.id,
                    child: Text(e.fullName, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: isSaving
                  ? null
                  : (v) {
                      c.submitterEmployeeId = v;
                      onChanged();
                    },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: c.notes,
              enabled: !isSaving,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Anything the approver should know',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Will be created as PENDING · ${c.category} / ${c.expenseType}'
              '${c.date.difference(DateTime.now()).inDays <= -1 ? " · dated ${DateFormat('dd MMM yyyy').format(c.date)}" : ""}',
              style: TextStyle(fontSize: 11, color: Colors.grey[700]),
            ),
          ),
        ],
      ],
    );
  }
}

/// A known value the section shows rather than asks for.
class _FactRow extends StatelessWidget {
  final String label;
  final String value;

  const _FactRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
