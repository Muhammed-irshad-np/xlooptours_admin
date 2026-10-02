import 'package:equatable/equatable.dart';

enum CashAdvanceStatus {
  open,
  partiallySettled,
  settled,
  writtenOff;

  String get displayName {
    switch (this) {
      case CashAdvanceStatus.open:
        return 'Open';
      case CashAdvanceStatus.partiallySettled:
        return 'Partially settled';
      case CashAdvanceStatus.settled:
        return 'Settled';
      case CashAdvanceStatus.writtenOff:
        return 'Written off';
    }
  }
}

/// Float / advance given to a staff member from a fund account.
class CashAdvanceEntity extends Equatable {
  final String id;
  final String fundAccountId;
  final String? fundAccountName;
  final String employeeId;
  final String employeeName;
  final double amount;
  final int? amountMinor;
  final double settledAmount;
  final String currency;
  final String purpose;
  final CashAdvanceStatus status;
  final String issuedBy;
  final String? issuedByUserId;
  final DateTime issuedAt;
  final String? issueLedgerEntryId;
  final DateTime? settledAt;
  final String? notes;
  final DateTime createdAt;

  const CashAdvanceEntity({
    required this.id,
    required this.fundAccountId,
    this.fundAccountName,
    required this.employeeId,
    required this.employeeName,
    required this.amount,
    this.amountMinor,
    this.settledAmount = 0,
    required this.currency,
    required this.purpose,
    this.status = CashAdvanceStatus.open,
    required this.issuedBy,
    this.issuedByUserId,
    required this.issuedAt,
    this.issueLedgerEntryId,
    this.settledAt,
    this.notes,
    required this.createdAt,
  });

  int get resolvedAmountMinor => amountMinor ?? (amount * 100).round();
  double get outstanding => amount - settledAmount;
  bool get isOpen =>
      status == CashAdvanceStatus.open ||
      status == CashAdvanceStatus.partiallySettled;

  CashAdvanceEntity copyWith({
    double? settledAmount,
    CashAdvanceStatus? status,
    DateTime? settledAt,
    String? notes,
  }) {
    return CashAdvanceEntity(
      id: id,
      fundAccountId: fundAccountId,
      fundAccountName: fundAccountName,
      employeeId: employeeId,
      employeeName: employeeName,
      amount: amount,
      amountMinor: amountMinor,
      settledAmount: settledAmount ?? this.settledAmount,
      currency: currency,
      purpose: purpose,
      status: status ?? this.status,
      issuedBy: issuedBy,
      issuedByUserId: issuedByUserId,
      issuedAt: issuedAt,
      issueLedgerEntryId: issueLedgerEntryId,
      settledAt: settledAt ?? this.settledAt,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        fundAccountId,
        employeeId,
        amount,
        settledAmount,
        status,
        issueLedgerEntryId,
      ];
}
