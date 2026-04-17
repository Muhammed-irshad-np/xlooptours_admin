import 'package:equatable/equatable.dart';

class EmployeeSettingsEntity extends Equatable {
  final int iqamaAlertDays;
  final int drivingLicenseAlertDays;
  final int passportAlertDays;
  final int saudiVisaAlertDays;
  final int bahrainVisaAlertDays;
  final int dubaiVisaAlertDays;
  final int qatarVisaAlertDays;
  final int phoneRechargeAlertDays;

  const EmployeeSettingsEntity({
    this.iqamaAlertDays = 30,
    this.drivingLicenseAlertDays = 30,
    this.passportAlertDays = 30,
    this.saudiVisaAlertDays = 30,
    this.bahrainVisaAlertDays = 30,
    this.dubaiVisaAlertDays = 30,
    this.qatarVisaAlertDays = 30,
    this.phoneRechargeAlertDays = 30,
  });

  @override
  List<Object?> get props => [
        iqamaAlertDays,
        drivingLicenseAlertDays,
        passportAlertDays,
        saudiVisaAlertDays,
        bahrainVisaAlertDays,
        dubaiVisaAlertDays,
        qatarVisaAlertDays,
        phoneRechargeAlertDays,
      ];

  EmployeeSettingsEntity copyWith({
    int? iqamaAlertDays,
    int? drivingLicenseAlertDays,
    int? passportAlertDays,
    int? saudiVisaAlertDays,
    int? bahrainVisaAlertDays,
    int? dubaiVisaAlertDays,
    int? qatarVisaAlertDays,
    int? phoneRechargeAlertDays,
  }) {
    return EmployeeSettingsEntity(
      iqamaAlertDays: iqamaAlertDays ?? this.iqamaAlertDays,
      drivingLicenseAlertDays: drivingLicenseAlertDays ?? this.drivingLicenseAlertDays,
      passportAlertDays: passportAlertDays ?? this.passportAlertDays,
      saudiVisaAlertDays: saudiVisaAlertDays ?? this.saudiVisaAlertDays,
      bahrainVisaAlertDays: bahrainVisaAlertDays ?? this.bahrainVisaAlertDays,
      dubaiVisaAlertDays: dubaiVisaAlertDays ?? this.dubaiVisaAlertDays,
      qatarVisaAlertDays: qatarVisaAlertDays ?? this.qatarVisaAlertDays,
      phoneRechargeAlertDays: phoneRechargeAlertDays ?? this.phoneRechargeAlertDays,
    );
  }
}
