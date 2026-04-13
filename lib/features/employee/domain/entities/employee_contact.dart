import 'package:equatable/equatable.dart';

/// Represents a single SIM/phone contact for an employee.
///
/// Each contact tracks its own recharge expiry, cost, and which employee
/// currently holds the physical SIM (to support SIM swaps).
class EmployeeContact extends Equatable {
  final String id;
  final String phoneNumber;
  final String countryCode; // e.g., "+966", "+973"
  final String label; // e.g., "Saudi SIM", "Bahrain SIM"
  final DateTime? rechargeExpiryDate;
  final double? rechargeCost;
  final int? notificationDays; // defaults to 30
  final String? currentHolderId; // employee ID currently using this SIM
  final String? currentHolderName; // denormalized for display

  const EmployeeContact({
    required this.id,
    required this.phoneNumber,
    required this.countryCode,
    this.label = '',
    this.rechargeExpiryDate,
    this.rechargeCost,
    this.notificationDays,
    this.currentHolderId,
    this.currentHolderName,
  });

  EmployeeContact copyWith({
    String? id,
    String? phoneNumber,
    String? countryCode,
    String? label,
    DateTime? rechargeExpiryDate,
    double? rechargeCost,
    int? notificationDays,
    String? currentHolderId,
    String? currentHolderName,
  }) {
    return EmployeeContact(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      countryCode: countryCode ?? this.countryCode,
      label: label ?? this.label,
      rechargeExpiryDate: rechargeExpiryDate ?? this.rechargeExpiryDate,
      rechargeCost: rechargeCost ?? this.rechargeCost,
      notificationDays: notificationDays ?? this.notificationDays,
      currentHolderId: currentHolderId ?? this.currentHolderId,
      currentHolderName: currentHolderName ?? this.currentHolderName,
    );
  }

  @override
  List<Object?> get props => [
    id,
    phoneNumber,
    countryCode,
    label,
    rechargeExpiryDate,
    rechargeCost,
    notificationDays,
    currentHolderId,
    currentHolderName,
  ];
}
