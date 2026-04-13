import 'package:equatable/equatable.dart';

class VehicleSettingsEntity extends Equatable {
  final int isthimaraAlertDays;
  final int fahasAlertDays;
  final int insuranceAlertDays;

  const VehicleSettingsEntity({
    this.isthimaraAlertDays = 30,
    this.fahasAlertDays = 30,
    this.insuranceAlertDays = 30,
  });

  @override
  List<Object?> get props => [
        isthimaraAlertDays,
        fahasAlertDays,
        insuranceAlertDays,
      ];

  VehicleSettingsEntity copyWith({
    int? isthimaraAlertDays,
    int? fahasAlertDays,
    int? insuranceAlertDays,
  }) {
    return VehicleSettingsEntity(
      isthimaraAlertDays: isthimaraAlertDays ?? this.isthimaraAlertDays,
      fahasAlertDays: fahasAlertDays ?? this.fahasAlertDays,
      insuranceAlertDays: insuranceAlertDays ?? this.insuranceAlertDays,
    );
  }
}
