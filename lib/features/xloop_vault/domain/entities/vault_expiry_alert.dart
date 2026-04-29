import 'package:equatable/equatable.dart';

class VaultExpiryAlert extends Equatable {
  final String documentType;
  final DateTime expiryDate;
  final int daysUntilExpiry;

  const VaultExpiryAlert({
    required this.documentType,
    required this.expiryDate,
    required this.daysUntilExpiry,
  });

  @override
  List<Object?> get props => [
    documentType,
    expiryDate,
    daysUntilExpiry,
  ];
}
