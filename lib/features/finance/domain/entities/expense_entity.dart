import 'package:equatable/equatable.dart';

/// Represents the status of an expense in the approval workflow.
enum ExpenseStatus {
  pending,
  approved,
  rejected,
  closed;

  String get displayName {
    switch (this) {
      case ExpenseStatus.pending:
        return 'Pending';
      case ExpenseStatus.approved:
        return 'Approved';
      case ExpenseStatus.rejected:
        return 'Rejected';
      case ExpenseStatus.closed:
        return 'Closed';
    }
  }
}

/// Represents a single expense record in the system.
///
/// Each expense is linked to a fund account, optionally to a vehicle
/// and/or employee, and goes through an approval workflow.
class ExpenseEntity extends Equatable {
  final String id;
  final String referenceNumber;
  final DateTime date;
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// The user who submitted the expense (e.g., "NITHIN", "SHAMNAD").
  final String submittedBy;

  /// The role of the submitter (e.g., "ADMIN", "COORDINATOR", "DRIVER").
  final String submittedByRole;

  /// Top-level category (e.g., "COMPANY", "EMPLOYEES", "VEHICLES").
  final String expenseCategory;

  /// Specific type within the category (e.g., "FUEL", "CAR_WASH", "SALARY").
  final String expenseType;

  final String? description;
  final String? paymentDetails;
  
  /// Payment method used: 'cash' or 'stcPay' (or other digital method).
  final String paymentMethod;

  final double amount;
  final String currency;

  /// The virtual fund account this expense is charged to.
  final String fundAccountId;
  final String? fundAccountName;

  final ExpenseStatus status;

  /// Optional link to an employee record.
  final String? employeeId;
  final String? employeeName;

  /// Optional link to a vehicle record.
  final String? vehicleId;
  final String? vehicleName;

  final double? mileageKm;

  /// Receipt/document URLs attached to this expense.
  final List<String> receiptUrls;

  final String? srvNumber;
  final int? numberOfTrips;
  final String? simOperator;
  final String? country;

  /// Approval workflow fields.
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;

  final String? notes;

  const ExpenseEntity({
    required this.id,
    required this.referenceNumber,
    required this.date,
    required this.createdAt,
    this.updatedAt,
    required this.submittedBy,
    required this.submittedByRole,
    required this.expenseCategory,
    required this.expenseType,
    this.description,
    this.paymentDetails,
    this.paymentMethod = 'cash',
    required this.amount,
    required this.currency,
    required this.fundAccountId,
    this.fundAccountName,
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
    this.approvedAt,
    this.rejectionReason,
    this.notes,
  });

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
    String? expenseCategory,
    String? expenseType,
    String? description,
    String? paymentDetails,
    String? paymentMethod,
    double? amount,
    String? currency,
    String? fundAccountId,
    String? fundAccountName,
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
    DateTime? approvedAt,
    String? rejectionReason,
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
      expenseCategory: expenseCategory ?? this.expenseCategory,
      expenseType: expenseType ?? this.expenseType,
      description:
          clearDescription ? null : (description ?? this.description),
      paymentDetails:
          clearPaymentDetails ? null : (paymentDetails ?? this.paymentDetails),
      paymentMethod: paymentMethod ?? this.paymentMethod,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      fundAccountId: fundAccountId ?? this.fundAccountId,
      fundAccountName: clearFundAccountName
          ? null
          : (fundAccountName ?? this.fundAccountName),
      status: status ?? this.status,
      employeeId:
          clearEmployeeId ? null : (employeeId ?? this.employeeId),
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
      approvedBy:
          clearApprovedBy ? null : (approvedBy ?? this.approvedBy),
      approvedAt:
          clearApprovedAt ? null : (approvedAt ?? this.approvedAt),
      rejectionReason: clearRejectionReason
          ? null
          : (rejectionReason ?? this.rejectionReason),
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
        expenseCategory,
        expenseType,
        description,
        paymentDetails,
        paymentMethod,
        amount,
        currency,
        fundAccountId,
        fundAccountName,
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
        approvedAt,
        rejectionReason,
        notes,
      ];
}
