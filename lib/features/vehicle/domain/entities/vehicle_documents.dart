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

  VehicleDocument copyWith({
    DateTime? expiryDate,
    String? attachmentUrl,
    bool clearAttachment = false,
    int? notificationDays,
  }) {
    return VehicleDocument(
      expiryDate: expiryDate ?? this.expiryDate,
      attachmentUrl:
          clearAttachment ? null : (attachmentUrl ?? this.attachmentUrl),
      notificationDays: notificationDays ?? this.notificationDays,
    );
  }

  @override
  List<Object?> get props => [expiryDate, attachmentUrl, notificationDays];
}

class TafweedRecord extends Equatable {
  final String driverId;

  /// The date the tafweed was issued / assignment started.
  /// Used together with [expiryDate] to form a date range for
  /// fine-responsibility cross-referencing.
  final DateTime issuedDate;
  final DateTime expiryDate;
  final String? attachmentUrl;
  final int? notificationDays;

  const TafweedRecord({
    required this.driverId,
    required this.issuedDate,
    required this.expiryDate,
    this.attachmentUrl,
    this.notificationDays,
  });

  TafweedRecord copyWith({
    String? driverId,
    DateTime? issuedDate,
    DateTime? expiryDate,
    String? attachmentUrl,
    bool clearAttachment = false,
    int? notificationDays,
  }) {
    return TafweedRecord(
      driverId: driverId ?? this.driverId,
      issuedDate: issuedDate ?? this.issuedDate,
      expiryDate: expiryDate ?? this.expiryDate,
      attachmentUrl:
          clearAttachment ? null : (attachmentUrl ?? this.attachmentUrl),
      notificationDays: notificationDays ?? this.notificationDays,
    );
  }

  @override
  List<Object?> get props => [driverId, issuedDate, expiryDate, attachmentUrl, notificationDays];
}

class MaintenanceRecord extends Equatable {
  final DateTime date;
  final int mileage; // in KM
  final String? attachmentUrl;
  final List<String>? attachmentUrls;
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
  final bool? isFollowUpRequired;
  final String? followUpReason;
  final bool? isFollowUpCompleted;
  
  // Extension fields
  final int? extendedMileage;
  final DateTime? extendedDate;
  final String? extensionReason;
  final bool? isExtended;

  const MaintenanceRecord({
    required this.date,
    required this.mileage,
    this.attachmentUrl,
    this.attachmentUrls,
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
    this.isFollowUpRequired,
    this.followUpReason,
    this.isFollowUpCompleted,
    this.extendedMileage,
    this.extendedDate,
    this.extensionReason,
    this.isExtended,
  });

  MaintenanceRecord copyWith({
    DateTime? date,
    int? mileage,
    String? attachmentUrl,
    List<String>? attachmentUrls,
    int? notificationDays,
    double? cost,
    double? partsCost,
    double? laborCost,
    String? serviceProvider,
    String? workOrderNumber,
    String? serviceType,
    String? partsReplaced,
    String? notes,
    int? nextServiceMileage,
    DateTime? nextServiceDate,
    bool? isFollowUpRequired,
    String? followUpReason,
    bool? isFollowUpCompleted,
    int? extendedMileage,
    DateTime? extendedDate,
    String? extensionReason,
    bool? isExtended,
  }) {
    return MaintenanceRecord(
      date: date ?? this.date,
      mileage: mileage ?? this.mileage,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
      notificationDays: notificationDays ?? this.notificationDays,
      cost: cost ?? this.cost,
      partsCost: partsCost ?? this.partsCost,
      laborCost: laborCost ?? this.laborCost,
      serviceProvider: serviceProvider ?? this.serviceProvider,
      workOrderNumber: workOrderNumber ?? this.workOrderNumber,
      serviceType: serviceType ?? this.serviceType,
      partsReplaced: partsReplaced ?? this.partsReplaced,
      notes: notes ?? this.notes,
      nextServiceMileage: nextServiceMileage ?? this.nextServiceMileage,
      nextServiceDate: nextServiceDate ?? this.nextServiceDate,
      isFollowUpRequired: isFollowUpRequired ?? this.isFollowUpRequired,
      followUpReason: followUpReason ?? this.followUpReason,
      isFollowUpCompleted: isFollowUpCompleted ?? this.isFollowUpCompleted,
      extendedMileage: extendedMileage ?? this.extendedMileage,
      extendedDate: extendedDate ?? this.extendedDate,
      extensionReason: extensionReason ?? this.extensionReason,
      isExtended: isExtended ?? this.isExtended,
    );
  }

  @override
  List<Object?> get props => [
    date,
    mileage,
    attachmentUrl,
    attachmentUrls,
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
    isFollowUpRequired,
    followUpReason,
    isFollowUpCompleted,
    extendedMileage,
    extendedDate,
    extensionReason,
    isExtended,
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

  VehicleMaintenance copyWith({
    MaintenanceRecord? engineOil,
    MaintenanceRecord? gearOil,
    MaintenanceRecord? housingOil,
    MaintenanceRecord? tyreChange,
    MaintenanceRecord? batteryChange,
    MaintenanceRecord? brakePads,
    MaintenanceRecord? airFilter,
    MaintenanceRecord? acService,
    MaintenanceRecord? wheelAlignment,
    MaintenanceRecord? sparkPlugs,
    MaintenanceRecord? coolantFlush,
    MaintenanceRecord? wiperBlades,
    MaintenanceRecord? timingBelt,
    MaintenanceRecord? transmissionFluid,
    MaintenanceRecord? brakeFluid,
    MaintenanceRecord? fuelFilter,
  }) {
    return VehicleMaintenance(
      engineOil: engineOil ?? this.engineOil,
      gearOil: gearOil ?? this.gearOil,
      housingOil: housingOil ?? this.housingOil,
      tyreChange: tyreChange ?? this.tyreChange,
      batteryChange: batteryChange ?? this.batteryChange,
      brakePads: brakePads ?? this.brakePads,
      airFilter: airFilter ?? this.airFilter,
      acService: acService ?? this.acService,
      wheelAlignment: wheelAlignment ?? this.wheelAlignment,
      sparkPlugs: sparkPlugs ?? this.sparkPlugs,
      coolantFlush: coolantFlush ?? this.coolantFlush,
      wiperBlades: wiperBlades ?? this.wiperBlades,
      timingBelt: timingBelt ?? this.timingBelt,
      transmissionFluid: transmissionFluid ?? this.transmissionFluid,
      brakeFluid: brakeFluid ?? this.brakeFluid,
      fuelFilter: fuelFilter ?? this.fuelFilter,
    );
  }

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
