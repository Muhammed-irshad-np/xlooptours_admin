import '../../domain/entities/employee_contact.dart';

/// Data model for [EmployeeContact] with JSON serialization.
class EmployeeContactModel extends EmployeeContact {
  const EmployeeContactModel({
    required super.id,
    required super.phoneNumber,
    required super.countryCode,
    super.label,
    super.rechargeExpiryDate,
    super.rechargeCost,
    super.notificationDays,
    super.currentHolderId,
    super.currentHolderName,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phoneNumber': phoneNumber,
      'countryCode': countryCode,
      'label': label,
      'rechargeExpiryDate': rechargeExpiryDate?.toIso8601String(),
      'rechargeCost': rechargeCost,
      'notificationDays': notificationDays,
      'currentHolderId': currentHolderId,
      'currentHolderName': currentHolderName,
    };
  }

  factory EmployeeContactModel.fromJson(Map<String, dynamic> json) {
    return EmployeeContactModel(
      id: json['id'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      countryCode: json['countryCode'] as String? ?? '+966',
      label: json['label'] as String? ?? '',
      rechargeExpiryDate: json['rechargeExpiryDate'] != null
          ? DateTime.tryParse(json['rechargeExpiryDate'] as String)
          : null,
      rechargeCost: (json['rechargeCost'] as num?)?.toDouble(),
      notificationDays: json['notificationDays'] as int?,
      currentHolderId: json['currentHolderId'] as String?,
      currentHolderName: json['currentHolderName'] as String?,
    );
  }

  factory EmployeeContactModel.fromEntity(EmployeeContact entity) {
    return EmployeeContactModel(
      id: entity.id,
      phoneNumber: entity.phoneNumber,
      countryCode: entity.countryCode,
      label: entity.label,
      rechargeExpiryDate: entity.rechargeExpiryDate,
      rechargeCost: entity.rechargeCost,
      notificationDays: entity.notificationDays,
      currentHolderId: entity.currentHolderId,
      currentHolderName: entity.currentHolderName,
    );
  }
}
