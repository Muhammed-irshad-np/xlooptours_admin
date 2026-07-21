import '../../domain/entities/expense_entity.dart';

/// Data model for [ExpenseEntity] with Firestore serialization.
class ExpenseModel extends ExpenseEntity {
  const ExpenseModel({
    required super.id,
    required super.referenceNumber,
    required super.date,
    required super.createdAt,
    super.updatedAt,
    required super.submittedBy,
    required super.submittedByRole,
    required super.expenseCategory,
    required super.expenseType,
    super.description,
    super.paymentDetails,
    super.paymentMethod = 'cash',
    required super.amount,
    required super.currency,
    required super.fundAccountId,
    super.fundAccountName,
    super.status = ExpenseStatus.pending,
    super.employeeId,
    super.employeeName,
    super.vehicleId,
    super.vehicleName,
    super.mileageKm,
    super.receiptUrls = const [],
    super.srvNumber,
    super.numberOfTrips,
    super.simOperator,
    super.country,
    super.approvedBy,
    super.approvedAt,
    super.rejectionReason,
    super.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'referenceNumber': referenceNumber,
      'date': date.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'submittedBy': submittedBy,
      'submittedByRole': submittedByRole,
      'expenseCategory': expenseCategory,
      'expenseType': expenseType,
      'description': description,
      'paymentDetails': paymentDetails,
      'paymentMethod': paymentMethod,
      'amount': amount,
      'currency': currency,
      'fundAccountId': fundAccountId,
      'fundAccountName': fundAccountName,
      'status': status.name,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'vehicleId': vehicleId,
      'vehicleName': vehicleName,
      'mileageKm': mileageKm,
      'receiptUrls': receiptUrls,
      'srvNumber': srvNumber,
      'numberOfTrips': numberOfTrips,
      'simOperator': simOperator,
      'country': country,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt?.toIso8601String(),
      'rejectionReason': rejectionReason,
      'notes': notes,
    };
  }

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'] as String,
      referenceNumber: json['referenceNumber'] as String? ?? '',
      date: DateTime.parse(json['date'] as String),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      submittedBy: json['submittedBy'] as String? ?? '',
      submittedByRole: json['submittedByRole'] as String? ?? '',
      expenseCategory: json['expenseCategory'] as String? ?? '',
      expenseType: json['expenseType'] as String? ?? '',
      description: json['description'] as String?,
      paymentDetails: json['paymentDetails'] as String?,
      paymentMethod: json['paymentMethod'] as String? ?? 'cash',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'SAR',
      fundAccountId: json['fundAccountId'] as String? ?? '',
      fundAccountName: json['fundAccountName'] as String?,
      status: _parseStatus(json['status'] as String?),
      employeeId: json['employeeId'] as String?,
      employeeName: json['employeeName'] as String?,
      vehicleId: json['vehicleId'] as String?,
      vehicleName: json['vehicleName'] as String?,
      mileageKm: (json['mileageKm'] as num?)?.toDouble(),
      receiptUrls: (json['receiptUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      srvNumber: json['srvNumber'] as String?,
      numberOfTrips: json['numberOfTrips'] as int?,
      simOperator: json['simOperator'] as String?,
      country: json['country'] as String?,
      approvedBy: json['approvedBy'] as String?,
      approvedAt: json['approvedAt'] != null
          ? DateTime.parse(json['approvedAt'] as String)
          : null,
      rejectionReason: json['rejectionReason'] as String?,
      notes: json['notes'] as String?,
    );
  }

  factory ExpenseModel.fromEntity(ExpenseEntity entity) {
    return ExpenseModel(
      id: entity.id,
      referenceNumber: entity.referenceNumber,
      date: entity.date,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      submittedBy: entity.submittedBy,
      submittedByRole: entity.submittedByRole,
      expenseCategory: entity.expenseCategory,
      expenseType: entity.expenseType,
      description: entity.description,
      paymentDetails: entity.paymentDetails,
      paymentMethod: entity.paymentMethod,
      amount: entity.amount,
      currency: entity.currency,
      fundAccountId: entity.fundAccountId,
      fundAccountName: entity.fundAccountName,
      status: entity.status,
      employeeId: entity.employeeId,
      employeeName: entity.employeeName,
      vehicleId: entity.vehicleId,
      vehicleName: entity.vehicleName,
      mileageKm: entity.mileageKm,
      receiptUrls: entity.receiptUrls,
      srvNumber: entity.srvNumber,
      numberOfTrips: entity.numberOfTrips,
      simOperator: entity.simOperator,
      country: entity.country,
      approvedBy: entity.approvedBy,
      approvedAt: entity.approvedAt,
      rejectionReason: entity.rejectionReason,
      notes: entity.notes,
    );
  }

  static ExpenseStatus _parseStatus(String? status) {
    if (status == null) return ExpenseStatus.pending;
    return ExpenseStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => ExpenseStatus.pending,
    );
  }
}
