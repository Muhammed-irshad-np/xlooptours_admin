import 'package:equatable/equatable.dart';

class VehicleSettingsEntity extends Equatable {
  final int isthimaraAlertDays;
  final int fahasAlertDays;
  final int insuranceAlertDays;
  final int bahrainInsuranceAlertDays;
  final int tafweedAlertDays;

  const VehicleSettingsEntity({
    this.isthimaraAlertDays = 30,
    this.fahasAlertDays = 30,
    this.insuranceAlertDays = 30,
    this.bahrainInsuranceAlertDays = 30,
    this.tafweedAlertDays = 30,
  });

  @override
  List<Object?> get props => [
        isthimaraAlertDays,
        fahasAlertDays,
        insuranceAlertDays,
        bahrainInsuranceAlertDays,
        tafweedAlertDays,
      ];

  VehicleSettingsEntity copyWith({
    int? isthimaraAlertDays,
    int? fahasAlertDays,
    int? insuranceAlertDays,
    int? bahrainInsuranceAlertDays,
    int? tafweedAlertDays,
  }) {
    return VehicleSettingsEntity(
      isthimaraAlertDays: isthimaraAlertDays ?? this.isthimaraAlertDays,
      fahasAlertDays: fahasAlertDays ?? this.fahasAlertDays,
      insuranceAlertDays: insuranceAlertDays ?? this.insuranceAlertDays,
      bahrainInsuranceAlertDays:
          bahrainInsuranceAlertDays ?? this.bahrainInsuranceAlertDays,
      tafweedAlertDays: tafweedAlertDays ?? this.tafweedAlertDays,
    );
  }
}
