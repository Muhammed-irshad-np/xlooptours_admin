import 'package:equatable/equatable.dart';

class VehicleDocument extends Equatable {
  final DateTime expiryDate;
  final String? attachmentUrl;
  final int? notificationDays;

  const VehicleDocument({
    required this.expiryDate,
    this.attachmentUrl,
    this.notificationDays,
  });

  @override
  List<Object?> get props => [expiryDate, attachmentUrl, notificationDays];
}

class MaintenanceRecord extends Equatable {
  final DateTime date;
  final int mileage; // in KM
  final String? attachmentUrl;
  final int? notificationDays;

  const MaintenanceRecord({
    required this.date,
    required this.mileage,
    this.attachmentUrl,
    this.notificationDays,
  });

  @override
  List<Object?> get props => [date, mileage, attachmentUrl, notificationDays];
}

class VehicleMaintenance extends Equatable {
  final MaintenanceRecord? engineOil;
  final MaintenanceRecord? gearOil;
  final MaintenanceRecord? housingOil; // Differential oil
  final MaintenanceRecord? tyreChange;
  final MaintenanceRecord? batteryChange;

  const VehicleMaintenance({
    this.engineOil,
    this.gearOil,
    this.housingOil,
    this.tyreChange,
    this.batteryChange,
  });

  @override
  List<Object?> get props => [
    engineOil,
    gearOil,
    housingOil,
    tyreChange,
    batteryChange,
  ];
}
