import 'package:equatable/equatable.dart';

class VehicleSettingsEntity extends Equatable {
  final int isthimaraAlertDays;
  final int fahasAlertDays;
  final int insuranceAlertDays;  final int tafweedAlertDays;

  const VehicleSettingsEntity({
    this.isthimaraAlertDays = 30,
    this.fahasAlertDays = 30,
    this.insuranceAlertDays = 30,
    this.tafweedAlertDays = 30,
  });

  @override
  List<Object?> get props => [
        isthimaraAlertDays,
        fahasAlertDays,
        insuranceAlertDays,
        tafweedAlertDays,
      ];

  VehicleSettingsEntity copyWith({
    int? isthimaraAlertDays,
    int? fahasAlertDays,
    int? insuranceAlertDays,
    int? tafweedAlertDays,
  }) {
    return VehicleSettingsEntity(
      isthimaraAlertDays: isthimaraAlertDays ?? this.isthimaraAlertDays,
      fahasAlertDays: fahasAlertDays ?? this.fahasAlertDays,
      insuranceAlertDays: insuranceAlertDays ?? this.insuranceAlertDays,
      tafweedAlertDays: tafweedAlertDays ?? this.tafweedAlertDays,
    );
  }
}
