import '../../domain/entities/vehicle_settings_entity.dart';

class VehicleSettingsModel extends VehicleSettingsEntity {
  const VehicleSettingsModel({
    super.isthimaraAlertDays = 30,
    super.fahasAlertDays = 30,
    super.insuranceAlertDays = 30,
    super.tafweedAlertDays = 30,
  });

  Map<String, dynamic> toJson() {
    return {
      'isthimaraAlertDays': isthimaraAlertDays,
      'fahasAlertDays': fahasAlertDays,
      'insuranceAlertDays': insuranceAlertDays,
      'tafweedAlertDays': tafweedAlertDays,
    };
  }

  factory VehicleSettingsModel.fromJson(Map<String, dynamic> json) {
    return VehicleSettingsModel(
      isthimaraAlertDays: json['isthimaraAlertDays'] as int? ?? 30,
      fahasAlertDays: json['fahasAlertDays'] as int? ?? 30,
      insuranceAlertDays: json['insuranceAlertDays'] as int? ?? 30,
      tafweedAlertDays: json['tafweedAlertDays'] as int? ?? 30,
    );
  }

  factory VehicleSettingsModel.fromEntity(VehicleSettingsEntity entity) {
    return VehicleSettingsModel(
      isthimaraAlertDays: entity.isthimaraAlertDays,
      fahasAlertDays: entity.fahasAlertDays,
      insuranceAlertDays: entity.insuranceAlertDays,
      tafweedAlertDays: entity.tafweedAlertDays,
    );
  }
}
