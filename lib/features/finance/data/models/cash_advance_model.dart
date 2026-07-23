import '../../domain/entities/cash_advance_entity.dart';

class CashAdvanceModel extends CashAdvanceEntity {
  const CashAdvanceModel({
    required super.id,
    required super.fundAccountId,
    super.fundAccountName,
    required super.employeeId,
    required super.employeeName,
    required super.amount,
    super.amountMinor,
    super.settledAmount = 0,
    required super.currency,
    required super.purpose,
    super.status = CashAdvanceStatus.open,
    required super.issuedBy,
    super.issuedByUserId,
    required super.issuedAt,
    super.issueLedgerEntryId,
    super.settledAt,
    super.notes,
    required super.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fundAccountId': fundAccountId,
        'fundAccountName': fundAccountName,
        'employeeId': employeeId,
        'employeeName': employeeName,
        'amount': amount,
        'amountMinor': amountMinor ?? (amount * 100).round(),
        'settledAmount': settledAmount,
        'currency': currency,
        'purpose': purpose,
        'status': status.name,
        'issuedBy': issuedBy,
        'issuedByUserId': issuedByUserId,
        'issuedAt': issuedAt.toIso8601String(),
        'issueLedgerEntryId': issueLedgerEntryId,
        'settledAt': settledAt?.toIso8601String(),
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CashAdvanceModel.fromJson(Map<String, dynamic> json) {
    final amount = (json['amount'] as num?)?.toDouble() ?? 0;
    return CashAdvanceModel(
      id: json['id'] as String,
      fundAccountId: json['fundAccountId'] as String? ?? '',
      fundAccountName: json['fundAccountName'] as String?,
      employeeId: json['employeeId'] as String? ?? '',
      employeeName: json['employeeName'] as String? ?? '',
      amount: amount,
      amountMinor:
          (json['amountMinor'] as num?)?.toInt() ?? (amount * 100).round(),
      settledAmount: (json['settledAmount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'SAR',
      purpose: json['purpose'] as String? ?? '',
      status: CashAdvanceStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => CashAdvanceStatus.open,
      ),
      issuedBy: json['issuedBy'] as String? ?? '',
      issuedByUserId: json['issuedByUserId'] as String?,
      issuedAt: json['issuedAt'] != null
          ? DateTime.parse(json['issuedAt'] as String)
          : DateTime.now(),
      issueLedgerEntryId: json['issueLedgerEntryId'] as String?,
      settledAt: json['settledAt'] != null
          ? DateTime.parse(json['settledAt'] as String)
          : null,
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  factory CashAdvanceModel.fromEntity(CashAdvanceEntity e) => CashAdvanceModel(
        id: e.id,
        fundAccountId: e.fundAccountId,
        fundAccountName: e.fundAccountName,
        employeeId: e.employeeId,
        employeeName: e.employeeName,
        amount: e.amount,
        amountMinor: e.amountMinor,
        settledAmount: e.settledAmount,
        currency: e.currency,
        purpose: e.purpose,
        status: e.status,
        issuedBy: e.issuedBy,
        issuedByUserId: e.issuedByUserId,
        issuedAt: e.issuedAt,
        issueLedgerEntryId: e.issueLedgerEntryId,
        settledAt: e.settledAt,
        notes: e.notes,
        createdAt: e.createdAt,
      );
}
