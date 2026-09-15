import '../../domain/entities/salary_entity.dart';

class SalaryStructureModel extends SalaryStructureEntity {
  const SalaryStructureModel({
    required super.employeeId,
    required super.employeeName,
    super.position,
    required super.basicSalary,
    super.allowances,
    super.currency,
    super.defaultFundAccountId,
    super.isActive,
    super.notes,
    required super.updatedAt,
    super.updatedBy,
  });

  Map<String, dynamic> toJson() => {
        'employeeId': employeeId,
        'employeeName': employeeName,
        'position': position,
        'basicSalary': basicSalary,
        'allowances': allowances,
        'currency': currency,
        'defaultFundAccountId': defaultFundAccountId,
        'isActive': isActive,
        'notes': notes,
        'updatedAt': updatedAt.toIso8601String(),
        'updatedBy': updatedBy,
      };

  factory SalaryStructureModel.fromJson(Map<String, dynamic> json) {
    return SalaryStructureModel(
      employeeId: json['employeeId'] as String? ?? '',
      employeeName: json['employeeName'] as String? ?? '',
      position: json['position'] as String? ?? '',
      basicSalary: (json['basicSalary'] as num?)?.toDouble() ?? 0,
      allowances: (json['allowances'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'SAR',
      defaultFundAccountId: json['defaultFundAccountId'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      notes: json['notes'] as String?,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      updatedBy: json['updatedBy'] as String?,
    );
  }

  factory SalaryStructureModel.fromEntity(SalaryStructureEntity e) =>
      SalaryStructureModel(
        employeeId: e.employeeId,
        employeeName: e.employeeName,
        position: e.position,
        basicSalary: e.basicSalary,
        allowances: e.allowances,
        currency: e.currency,
        defaultFundAccountId: e.defaultFundAccountId,
        isActive: e.isActive,
        notes: e.notes,
        updatedAt: e.updatedAt,
        updatedBy: e.updatedBy,
      );
}

/// Firestore hands maps back as `Map<String, dynamic>`; normalise to doubles.
Map<String, double> _recoveriesFromJson(dynamic raw) {
  if (raw is! Map) return const {};
  final out = <String, double>{};
  raw.forEach((key, value) {
    final amount = (value as num?)?.toDouble();
    if (amount != null && amount > 0) out[key.toString()] = amount;
  });
  return out;
}

class SalaryPaymentModel extends SalaryPaymentEntity {
  const SalaryPaymentModel({
    required super.id,
    required super.period,
    required super.employeeId,
    required super.employeeName,
    super.position,
    required super.basicSalary,
    super.allowances,
    super.deductions,
    super.deductionNote,
    super.advanceRecovery,
    super.advanceRecoveries,
    required super.netAmount,
    super.netAmountMinor,
    super.currency,
    super.fundAccountId,
    super.fundAccountName,
    super.paymentMethod,
    super.expenseId,
    super.status,
    super.paidAt,
    super.paidBy,
    super.paidByUserId,
    super.ledgerEntryId,
    super.voidedAt,
    super.voidedBy,
    super.voidReason,
    super.reverseLedgerEntryId,
    super.notes,
    required super.createdAt,
    super.createdBy,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'period': period,
        'employeeId': employeeId,
        'employeeName': employeeName,
        'position': position,
        'basicSalary': basicSalary,
        'allowances': allowances,
        'deductions': deductions,
        'deductionNote': deductionNote,
        'advanceRecovery': advanceRecovery,
        'advanceRecoveries': advanceRecoveries,
        'netAmount': netAmount,
        'netAmountMinor': resolvedNetMinor,
        'currency': currency,
        'fundAccountId': fundAccountId,
        'fundAccountName': fundAccountName,
        'paymentMethod': paymentMethod,
        'expenseId': expenseId,
        'status': status.name,
        'paidAt': paidAt?.toIso8601String(),
        'paidBy': paidBy,
        'paidByUserId': paidByUserId,
        'ledgerEntryId': ledgerEntryId,
        'voidedAt': voidedAt?.toIso8601String(),
        'voidedBy': voidedBy,
        'voidReason': voidReason,
        'reverseLedgerEntryId': reverseLedgerEntryId,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'createdBy': createdBy,
      };

  factory SalaryPaymentModel.fromJson(Map<String, dynamic> json) {
    final net = (json['netAmount'] as num?)?.toDouble() ?? 0;
    return SalaryPaymentModel(
      id: json['id'] as String? ?? '',
      period: json['period'] as String? ?? '',
      employeeId: json['employeeId'] as String? ?? '',
      employeeName: json['employeeName'] as String? ?? '',
      position: json['position'] as String? ?? '',
      basicSalary: (json['basicSalary'] as num?)?.toDouble() ?? 0,
      allowances: (json['allowances'] as num?)?.toDouble() ?? 0,
      deductions: (json['deductions'] as num?)?.toDouble() ?? 0,
      deductionNote: json['deductionNote'] as String?,
      advanceRecovery: (json['advanceRecovery'] as num?)?.toDouble() ?? 0,
      advanceRecoveries: _recoveriesFromJson(json['advanceRecoveries']),
      netAmount: net,
      netAmountMinor:
          (json['netAmountMinor'] as num?)?.toInt() ?? (net * 100).round(),
      currency: json['currency'] as String? ?? 'SAR',
      fundAccountId: json['fundAccountId'] as String?,
      fundAccountName: json['fundAccountName'] as String?,
      paymentMethod: json['paymentMethod'] as String? ?? 'cash',
      expenseId: json['expenseId'] as String?,
      status: SalaryPaymentStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => SalaryPaymentStatus.pending,
      ),
      paidAt: json['paidAt'] != null
          ? DateTime.parse(json['paidAt'] as String)
          : null,
      paidBy: json['paidBy'] as String?,
      paidByUserId: json['paidByUserId'] as String?,
      ledgerEntryId: json['ledgerEntryId'] as String?,
      voidedAt: json['voidedAt'] != null
          ? DateTime.parse(json['voidedAt'] as String)
          : null,
      voidedBy: json['voidedBy'] as String?,
      voidReason: json['voidReason'] as String?,
      reverseLedgerEntryId: json['reverseLedgerEntryId'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      createdBy: json['createdBy'] as String?,
    );
  }

  factory SalaryPaymentModel.fromEntity(SalaryPaymentEntity e) =>
      SalaryPaymentModel(
        id: e.id,
        period: e.period,
        employeeId: e.employeeId,
        employeeName: e.employeeName,
        position: e.position,
        basicSalary: e.basicSalary,
        allowances: e.allowances,
        deductions: e.deductions,
        deductionNote: e.deductionNote,
        advanceRecovery: e.advanceRecovery,
        advanceRecoveries: e.advanceRecoveries,
        netAmount: e.netAmount,
        netAmountMinor: e.netAmountMinor,
        currency: e.currency,
        fundAccountId: e.fundAccountId,
        fundAccountName: e.fundAccountName,
        paymentMethod: e.paymentMethod,
        expenseId: e.expenseId,
        status: e.status,
        paidAt: e.paidAt,
        paidBy: e.paidBy,
        paidByUserId: e.paidByUserId,
        ledgerEntryId: e.ledgerEntryId,
        voidedAt: e.voidedAt,
        voidedBy: e.voidedBy,
        voidReason: e.voidReason,
        reverseLedgerEntryId: e.reverseLedgerEntryId,
        notes: e.notes,
        createdAt: e.createdAt,
        createdBy: e.createdBy,
      );
}
