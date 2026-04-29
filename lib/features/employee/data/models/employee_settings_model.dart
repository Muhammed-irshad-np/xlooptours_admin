import '../../domain/entities/employee_settings_entity.dart';

class EmployeeSettingsModel extends EmployeeSettingsEntity {
  const EmployeeSettingsModel({
    super.iqamaAlertDays = 30,
    super.drivingLicenseAlertDays = 30,
    super.passportAlertDays = 30,
    super.saudiVisaAlertDays = 30,
    super.bahrainVisaAlertDays = 30,
    super.dubaiVisaAlertDays = 30,
    super.qatarVisaAlertDays = 30,
    super.phoneRechargeAlertDays = 30,
    super.healthInsuranceAlertDays = 30,
    super.tafweedAlertDays = 30,
  });

  Map<String, dynamic> toJson() {
    return {
      'iqamaAlertDays': iqamaAlertDays,
      'drivingLicenseAlertDays': drivingLicenseAlertDays,
      'passportAlertDays': passportAlertDays,
      'saudiVisaAlertDays': saudiVisaAlertDays,
      'bahrainVisaAlertDays': bahrainVisaAlertDays,
      'dubaiVisaAlertDays': dubaiVisaAlertDays,
      'qatarVisaAlertDays': qatarVisaAlertDays,
      'phoneRechargeAlertDays': phoneRechargeAlertDays,
      'healthInsuranceAlertDays': healthInsuranceAlertDays,
      'tafweedAlertDays': tafweedAlertDays,
    };
  }

  factory EmployeeSettingsModel.fromJson(Map<String, dynamic> json) {
    return EmployeeSettingsModel(
      iqamaAlertDays: json['iqamaAlertDays'] as int? ?? 30,
      drivingLicenseAlertDays: json['drivingLicenseAlertDays'] as int? ?? 30,
      passportAlertDays: json['passportAlertDays'] as int? ?? 30,
      saudiVisaAlertDays: json['saudiVisaAlertDays'] as int? ?? 30,
      bahrainVisaAlertDays: json['bahrainVisaAlertDays'] as int? ?? 30,
      dubaiVisaAlertDays: json['dubaiVisaAlertDays'] as int? ?? 30,
      qatarVisaAlertDays: json['qatarVisaAlertDays'] as int? ?? 30,
      phoneRechargeAlertDays: json['phoneRechargeAlertDays'] as int? ?? 30,
      healthInsuranceAlertDays: json['healthInsuranceAlertDays'] as int? ?? 30,
      tafweedAlertDays: json['tafweedAlertDays'] as int? ?? 30,
    );
  }

  factory EmployeeSettingsModel.fromEntity(EmployeeSettingsEntity entity) {
    return EmployeeSettingsModel(
      iqamaAlertDays: entity.iqamaAlertDays,
      drivingLicenseAlertDays: entity.drivingLicenseAlertDays,
      passportAlertDays: entity.passportAlertDays,
      saudiVisaAlertDays: entity.saudiVisaAlertDays,
      bahrainVisaAlertDays: entity.bahrainVisaAlertDays,
      dubaiVisaAlertDays: entity.dubaiVisaAlertDays,
      qatarVisaAlertDays: entity.qatarVisaAlertDays,
      phoneRechargeAlertDays: entity.phoneRechargeAlertDays,
      healthInsuranceAlertDays: entity.healthInsuranceAlertDays,
      tafweedAlertDays: entity.tafweedAlertDays,
    );
  }

}
