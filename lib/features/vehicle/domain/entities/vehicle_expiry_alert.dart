import 'package:equatable/equatable.dart';

class VehicleExpiryAlert extends Equatable {
  final String vehicleId;
  final String plateNumber;
  final String documentType; // 'Isthimara', 'Fahas', 'Insurance', 'Tafweed'
  final DateTime expiryDate;
  final int daysUntilExpiry;
  final String? documentId;

  const VehicleExpiryAlert({
    required this.vehicleId,
    required this.plateNumber,
    required this.documentType,
    required this.expiryDate,
    required this.daysUntilExpiry,
    this.documentId,
  });

  @override
  List<Object?> get props => [
    vehicleId,
    plateNumber,
    documentType,
    expiryDate,
    daysUntilExpiry,
    documentId,
  ];
}
