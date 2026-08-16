import 'package:equatable/equatable.dart';

/// Expense lifecycle for controlled money.
///
/// draft → pending → approved → paid → (optional void)
///                  ↘ rejected
///
/// Legacy docs may only have pending/approved/rejected/closed.
enum ExpenseStatus {
  draft,
  pending,
  approved,
  rejected,
  /// Money has been posted to a fund account.
  paid,
  /// Payment reversed; money returned to fund.
  voided,
  /// Legacy alias kept for old data / UI.
  closed;

  String get displayName {
    switch (this) {
      case ExpenseStatus.draft:
        return 'Draft';
      case ExpenseStatus.pending:
        return 'Pending';
      case ExpenseStatus.approved:
        return 'Approved';
      case ExpenseStatus.rejected:
        return 'Rejected';
      case ExpenseStatus.paid:
        return 'Paid';
      case ExpenseStatus.voided:
        return 'Voided';
      case ExpenseStatus.closed:
        return 'Closed';
    }
  }

  bool get isPosted => this == ExpenseStatus.paid;
  bool get canEdit =>
      this == ExpenseStatus.draft || this == ExpenseStatus.pending;
  bool get canHardDelete =>
      this == ExpenseStatus.draft || this == ExpenseStatus.pending;
  bool get canApprove => this == ExpenseStatus.pending;
  bool get canReject => this == ExpenseStatus.pending;
  bool get canVoid => this == ExpenseStatus.paid;
}

/// Single expense record.
class ExpenseEntity extends Equatable {
  final String id;
  final String referenceNumber;
  final DateTime date;
  final DateTime createdAt;
  final DateTime? updatedAt;

  final String submittedBy;
  final String submittedByRole;

  /// Firebase uid of submitter when available.
  final String? submittedByUserId;

  final String expenseCategory;
  final String expenseType;

  final String? description;
  final String? paymentDetails;

  /// Payment method: 'cash', 'stcPay', etc.
  final String paymentMethod;

  final double amount;
  final String currency;

  /// Amount in minor units (halalas). Preferred for new writes.
  final int? amountMinor;

  final String fundAccountId;
  final String? fundAccountName;

  /// When true, expense is tracking-only and never hits a wallet.
  final bool isNonWallet;

  final ExpenseStatus status;

  final String? employeeId;
  final String? employeeName;
  final String? vehicleId;
  final String? vehicleName;
  final double? mileageKm;
  final List<String> receiptUrls;
  final String? srvNumber;
  final int? numberOfTrips;
  final String? simOperator;
  final String? country;

  final String? approvedBy;
  final String? approvedByUserId;
  final DateTime? approvedAt;
  final String? rejectionReason;

  /// Ledger / fund_transaction id created when paid.
  final String? ledgerEntryId;
  final String? paidBy;
  final String? paidByUserId;
  final DateTime? paidAt;

  final String? voidedBy;
  final String? voidedByUserId;
  final DateTime? voidedAt;
  final String? voidReason;
  final String? reverseLedgerEntryId;

  final String? notes;

  const ExpenseEntity({
    required this.id,
    required this.referenceNumber,
    required this.date,
    required this.createdAt,
    this.updatedAt,
    required this.submittedBy,
    required this.submittedByRole,
    this.submittedByUserId,
    required this.expenseCategory,
    required this.expenseType,
    this.description,
    this.paymentDetails,
    this.paymentMethod = 'cash',
    required this.amount,
    required this.currency,
    this.amountMinor,
    required this.fundAccountId,
    this.fundAccountName,
    this.isNonWallet = false,
    this.status = ExpenseStatus.pending,
    this.employeeId,
    this.employeeName,
    this.vehicleId,
    this.vehicleName,
    this.mileageKm,
    this.receiptUrls = const [],
    this.srvNumber,
    this.numberOfTrips,
    this.simOperator,
    this.country,
    this.approvedBy,
    this.approvedByUserId,
    this.approvedAt,
    this.rejectionReason,
    this.ledgerEntryId,
    this.paidBy,
    this.paidByUserId,
    this.paidAt,
    this.voidedBy,
    this.voidedByUserId,
    this.voidedAt,
    this.voidReason,
    this.reverseLedgerEntryId,
    this.notes,
  });

  int get resolvedAmountMinor =>
      amountMinor ?? (amount * 100).round();

  factory ExpenseEntity.empty() {
    return ExpenseEntity(
      id: '',
      referenceNumber: '',
      date: DateTime.now(),
      createdAt: DateTime.now(),
      submittedBy: '',
      submittedByRole: '',
      expenseCategory: '',
      expenseType: '',
      amount: 0,
      currency: 'SAR',
      fundAccountId: '',
    );
  }

  ExpenseEntity copyWith({
    String? id,
    String? referenceNumber,
    DateTime? date,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? submittedBy,
    String? submittedByRole,
    String? submittedByUserId,
    String? expenseCategory,
    String? expenseType,
    String? description,
    String? paymentDetails,
    String? paymentMethod,
    double? amount,
    String? currency,
    int? amountMinor,
    String? fundAccountId,
    String? fundAccountName,
    bool? isNonWallet,
    ExpenseStatus? status,
    String? employeeId,
    String? employeeName,
    String? vehicleId,
    String? vehicleName,
    double? mileageKm,
    List<String>? receiptUrls,
    String? srvNumber,
    int? numberOfTrips,
    String? simOperator,
    String? country,
    String? approvedBy,
    String? approvedByUserId,
    DateTime? approvedAt,
    String? rejectionReason,
    String? ledgerEntryId,
    String? paidBy,
    String? paidByUserId,
    DateTime? paidAt,
    String? voidedBy,
    String? voidedByUserId,
    DateTime? voidedAt,
    String? voidReason,
    String? reverseLedgerEntryId,
    String? notes,
    bool clearDescription = false,
    bool clearPaymentDetails = false,
    bool clearEmployeeId = false,
    bool clearEmployeeName = false,
    bool clearVehicleId = false,
    bool clearVehicleName = false,
    bool clearMileageKm = false,
    bool clearSrvNumber = false,
    bool clearNumberOfTrips = false,
    bool clearSimOperator = false,
    bool clearCountry = false,
    bool clearApprovedBy = false,
    bool clearApprovedAt = false,
    bool clearRejectionReason = false,
    bool clearNotes = false,
    bool clearFundAccountName = false,
  }) {
    return ExpenseEntity(
      id: id ?? this.id,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      submittedBy: submittedBy ?? this.submittedBy,
      submittedByRole: submittedByRole ?? this.submittedByRole,
      submittedByUserId: submittedByUserId ?? this.submittedByUserId,
      expenseCategory: expenseCategory ?? this.expenseCategory,
      expenseType: expenseType ?? this.expenseType,
      description:
          clearDescription ? null : (description ?? this.description),
      paymentDetails:
          clearPaymentDetails ? null : (paymentDetails ?? this.paymentDetails),
      paymentMethod: paymentMethod ?? this.paymentMethod,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      amountMinor: amountMinor ?? this.amountMinor,
      fundAccountId: fundAccountId ?? this.fundAccountId,
      fundAccountName: clearFundAccountName
          ? null
          : (fundAccountName ?? this.fundAccountName),
      isNonWallet: isNonWallet ?? this.isNonWallet,
      status: status ?? this.status,
      employeeId: clearEmployeeId ? null : (employeeId ?? this.employeeId),
      employeeName:
          clearEmployeeName ? null : (employeeName ?? this.employeeName),
      vehicleId: clearVehicleId ? null : (vehicleId ?? this.vehicleId),
      vehicleName:
          clearVehicleName ? null : (vehicleName ?? this.vehicleName),
      mileageKm: clearMileageKm ? null : (mileageKm ?? this.mileageKm),
      receiptUrls: receiptUrls ?? this.receiptUrls,
      srvNumber: clearSrvNumber ? null : (srvNumber ?? this.srvNumber),
      numberOfTrips:
          clearNumberOfTrips ? null : (numberOfTrips ?? this.numberOfTrips),
      simOperator:
          clearSimOperator ? null : (simOperator ?? this.simOperator),
      country: clearCountry ? null : (country ?? this.country),
      approvedBy: clearApprovedBy ? null : (approvedBy ?? this.approvedBy),
      approvedByUserId: approvedByUserId ?? this.approvedByUserId,
      approvedAt: clearApprovedAt ? null : (approvedAt ?? this.approvedAt),
      rejectionReason: clearRejectionReason
          ? null
          : (rejectionReason ?? this.rejectionReason),
      ledgerEntryId: ledgerEntryId ?? this.ledgerEntryId,
      paidBy: paidBy ?? this.paidBy,
      paidByUserId: paidByUserId ?? this.paidByUserId,
      paidAt: paidAt ?? this.paidAt,
      voidedBy: voidedBy ?? this.voidedBy,
      voidedByUserId: voidedByUserId ?? this.voidedByUserId,
      voidedAt: voidedAt ?? this.voidedAt,
      voidReason: voidReason ?? this.voidReason,
      reverseLedgerEntryId: reverseLedgerEntryId ?? this.reverseLedgerEntryId,
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }

  @override
  List<Object?> get props => [
        id,
        referenceNumber,
        date,
        createdAt,
        updatedAt,
        submittedBy,
        submittedByRole,
        submittedByUserId,
        expenseCategory,
        expenseType,
        description,
        paymentDetails,
        paymentMethod,
        amount,
        currency,
        amountMinor,
        fundAccountId,
        fundAccountName,
        isNonWallet,
        status,
        employeeId,
        employeeName,
        vehicleId,
        vehicleName,
        mileageKm,
        receiptUrls,
        srvNumber,
        numberOfTrips,
        simOperator,
        country,
        approvedBy,
        approvedByUserId,
        approvedAt,
        rejectionReason,
        ledgerEntryId,
        paidBy,
        paidByUserId,
        paidAt,
        voidedBy,
        voidedByUserId,
        voidedAt,
        voidReason,
        reverseLedgerEntryId,
        notes,
      ];
}
