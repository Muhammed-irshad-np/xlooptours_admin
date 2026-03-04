import 'package:equatable/equatable.dart';

class EmployeeExpiryAlert extends Equatable {
  final String employeeId;
  final String employeeName;
  final String documentType;
  final DateTime expiryDate;
  final int daysUntilExpiry;

  const EmployeeExpiryAlert({
    required this.employeeId,
    required this.employeeName,
    required this.documentType,
    required this.expiryDate,
    required this.daysUntilExpiry,
  });

  @override
  List<Object?> get props => [
    employeeId,
    employeeName,
    documentType,
    expiryDate,
    daysUntilExpiry,
  ];
}
