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
  final double? cost;
  final double? partsCost;
  final double? laborCost;
  final String? serviceProvider;
  final String? workOrderNumber;
  final String? serviceType;
  final String? partsReplaced;
  final String? notes;
  final int? nextServiceMileage;
  final DateTime? nextServiceDate;

  const MaintenanceRecord({
    required this.date,
    required this.mileage,
    this.attachmentUrl,
    this.notificationDays,
    this.cost,
    this.partsCost,
    this.laborCost,
    this.serviceProvider,
    this.workOrderNumber,
    this.serviceType,
    this.partsReplaced,
    this.notes,
    this.nextServiceMileage,
    this.nextServiceDate,
  });

  @override
  List<Object?> get props => [
    date,
    mileage,
    attachmentUrl,
    notificationDays,
    cost,
    partsCost,
    laborCost,
    serviceProvider,
    workOrderNumber,
    serviceType,
    partsReplaced,
    notes,
    nextServiceMileage,
    nextServiceDate,
  ];
}

class VehicleMaintenance extends Equatable {
  final MaintenanceRecord? engineOil;
  final MaintenanceRecord? gearOil;
  final MaintenanceRecord? housingOil; // Differential oil
  final MaintenanceRecord? tyreChange;
  final MaintenanceRecord? batteryChange;
  final MaintenanceRecord? brakePads;
  final MaintenanceRecord? airFilter;
  final MaintenanceRecord? acService;
  final MaintenanceRecord? wheelAlignment;
  final MaintenanceRecord? sparkPlugs;
  final MaintenanceRecord? coolantFlush;
  final MaintenanceRecord? wiperBlades;
  final MaintenanceRecord? timingBelt;
  final MaintenanceRecord? transmissionFluid;
  final MaintenanceRecord? brakeFluid;
  final MaintenanceRecord? fuelFilter;

  const VehicleMaintenance({
    this.engineOil,
    this.gearOil,
    this.housingOil,
    this.tyreChange,
    this.batteryChange,
    this.brakePads,
    this.airFilter,
    this.acService,
    this.wheelAlignment,
    this.sparkPlugs,
    this.coolantFlush,
    this.wiperBlades,
    this.timingBelt,
    this.transmissionFluid,
    this.brakeFluid,
    this.fuelFilter,
  });

  @override
  List<Object?> get props => [
    engineOil,
    gearOil,
    housingOil,
    tyreChange,
    batteryChange,
    brakePads,
    airFilter,
    acService,
    wheelAlignment,
    sparkPlugs,
    coolantFlush,
    wiperBlades,
    timingBelt,
    transmissionFluid,
    brakeFluid,
    fuelFilter,
  ];
}
