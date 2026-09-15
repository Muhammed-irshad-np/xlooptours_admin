import 'package:equatable/equatable.dart';

/// Monthly salary setup for one employee ("who is on the payroll").
///
/// One document per employee. The amounts here are the *template* used when a
/// payroll month is generated; each [SalaryPaymentEntity] keeps its own copy so
/// history is never rewritten by a later raise.
class SalaryStructureEntity extends Equatable {
  final String employeeId;
  final String employeeName;
  final String position;

  /// Fixed monthly basic pay (major units).
  final double basicSalary;

  /// Housing / transport / any other fixed monthly allowance (major units).
  final double allowances;

  final String currency;

  /// Default fund account the salary is paid from. Can be overridden at pay time.
  final String? defaultFundAccountId;

  final bool isActive;
  final String? notes;
  final DateTime updatedAt;
  final String? updatedBy;

  const SalaryStructureEntity({
    required this.employeeId,
    required this.employeeName,
    this.position = '',
    required this.basicSalary,
    this.allowances = 0,
    this.currency = 'SAR',
    this.defaultFundAccountId,
    this.isActive = true,
    this.notes,
    required this.updatedAt,
    this.updatedBy,
  });

  /// Gross monthly pay before deductions.
  double get grossSalary => basicSalary + allowances;

  SalaryStructureEntity copyWith({
    String? employeeName,
    String? position,
    double? basicSalary,
    double? allowances,
    String? currency,
    String? defaultFundAccountId,
    bool? isActive,
    String? notes,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return SalaryStructureEntity(
      employeeId: employeeId,
      employeeName: employeeName ?? this.employeeName,
      position: position ?? this.position,
      basicSalary: basicSalary ?? this.basicSalary,
      allowances: allowances ?? this.allowances,
      currency: currency ?? this.currency,
      defaultFundAccountId: defaultFundAccountId ?? this.defaultFundAccountId,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  @override
  List<Object?> get props => [
        employeeId,
        employeeName,
        basicSalary,
        allowances,
        currency,
        defaultFundAccountId,
        isActive,
      ];
}

/// Lifecycle of a single month's salary for one employee.
///
/// pending → paid → (optional voided)
enum SalaryPaymentStatus {
  /// Generated for the month but money has not left a fund account yet.
  pending,

  /// Money posted to the ledger and deducted from a fund account.
  paid,

  /// A paid salary that was reversed; the fund account was credited back.
  voided;

  String get displayName {
    switch (this) {
      case SalaryPaymentStatus.pending:
        return 'Pending';
      case SalaryPaymentStatus.paid:
        return 'Paid';
      case SalaryPaymentStatus.voided:
        return 'Voided';
    }
  }

  bool get isPosted => this == SalaryPaymentStatus.paid;
  bool get canPay => this == SalaryPaymentStatus.pending;
  bool get canDelete => this == SalaryPaymentStatus.pending;
  bool get canVoid => this == SalaryPaymentStatus.paid;
}

/// One employee's salary for one month.
class SalaryPaymentEntity extends Equatable {
  final String id;

  /// Payroll month in `yyyy-MM` form (e.g. `2026-09`).
  final String period;

  final String employeeId;
  final String employeeName;
  final String position;

  final double basicSalary;
  final double allowances;

  /// Absences, loan instalments, advance recovery, etc. (major units).
  final double deductions;
  final String? deductionNote;

  /// basic + allowances − deductions, never below zero.
  final double netAmount;
  final int? netAmountMinor;
  final String currency;

  final String? fundAccountId;
  final String? fundAccountName;

  final SalaryPaymentStatus status;

  final DateTime? paidAt;
  final String? paidBy;
  final String? paidByUserId;

  /// `fund_transactions` id created when the salary was paid.
  final String? ledgerEntryId;

  final DateTime? voidedAt;
  final String? voidedBy;
  final String? voidReason;
  final String? reverseLedgerEntryId;

  final String? notes;
  final DateTime createdAt;
  final String? createdBy;

  const SalaryPaymentEntity({
    required this.id,
    required this.period,
    required this.employeeId,
    required this.employeeName,
    this.position = '',
    required this.basicSalary,
    this.allowances = 0,
    this.deductions = 0,
    this.deductionNote,
    required this.netAmount,
    this.netAmountMinor,
    this.currency = 'SAR',
    this.fundAccountId,
    this.fundAccountName,
    this.status = SalaryPaymentStatus.pending,
    this.paidAt,
    this.paidBy,
    this.paidByUserId,
    this.ledgerEntryId,
    this.voidedAt,
    this.voidedBy,
    this.voidReason,
    this.reverseLedgerEntryId,
    this.notes,
    required this.createdAt,
    this.createdBy,
  });

  double get grossSalary => basicSalary + allowances;

  int get resolvedNetMinor => netAmountMinor ?? (netAmount * 100).round();

  /// Deterministic document id so generating a payroll month twice can never
  /// create a duplicate salary for the same employee.
  static String buildId(String period, String employeeId) =>
      '${period}_$employeeId';

  /// `yyyy-MM` key for [date].
  static String periodOf(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}';

  /// Net pay derived from components, floored at zero.
  static double computeNet({
    required double basicSalary,
    double allowances = 0,
    double deductions = 0,
  }) {
    final net = basicSalary + allowances - deductions;
    return net < 0 ? 0 : net;
  }

  SalaryPaymentEntity copyWith({
    double? basicSalary,
    double? allowances,
    double? deductions,
    String? deductionNote,
    double? netAmount,
    int? netAmountMinor,
    String? fundAccountId,
    String? fundAccountName,
    SalaryPaymentStatus? status,
    DateTime? paidAt,
    String? paidBy,
    String? paidByUserId,
    String? ledgerEntryId,
    DateTime? voidedAt,
    String? voidedBy,
    String? voidReason,
    String? reverseLedgerEntryId,
    String? notes,
  }) {
    return SalaryPaymentEntity(
      id: id,
      period: period,
      employeeId: employeeId,
      employeeName: employeeName,
      position: position,
      basicSalary: basicSalary ?? this.basicSalary,
      allowances: allowances ?? this.allowances,
      deductions: deductions ?? this.deductions,
      deductionNote: deductionNote ?? this.deductionNote,
      netAmount: netAmount ?? this.netAmount,
      netAmountMinor: netAmountMinor ?? this.netAmountMinor,
      currency: currency,
      fundAccountId: fundAccountId ?? this.fundAccountId,
      fundAccountName: fundAccountName ?? this.fundAccountName,
      status: status ?? this.status,
      paidAt: paidAt ?? this.paidAt,
      paidBy: paidBy ?? this.paidBy,
      paidByUserId: paidByUserId ?? this.paidByUserId,
      ledgerEntryId: ledgerEntryId ?? this.ledgerEntryId,
      voidedAt: voidedAt ?? this.voidedAt,
      voidedBy: voidedBy ?? this.voidedBy,
      voidReason: voidReason ?? this.voidReason,
      reverseLedgerEntryId: reverseLedgerEntryId ?? this.reverseLedgerEntryId,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      createdBy: createdBy,
    );
  }

  @override
  List<Object?> get props => [
        id,
        period,
        employeeId,
        netAmount,
        status,
        fundAccountId,
        ledgerEntryId,
      ];
}
