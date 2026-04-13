import 'package:equatable/equatable.dart';

class VehicleExpiryAlert extends Equatable {
  final String vehicleId;
  final String plateNumber;
  final String documentType; // 'Isthimara', 'Fahas', 'Insurance'
  final DateTime expiryDate;
  final int daysUntilExpiry;

  const VehicleExpiryAlert({
    required this.vehicleId,
    required this.plateNumber,
    required this.documentType,
    required this.expiryDate,
    required this.daysUntilExpiry,
  });

  @override
  List<Object?> get props => [
        vehicleId,
        plateNumber,
        documentType,
        expiryDate,
        daysUntilExpiry,
      ];
}
