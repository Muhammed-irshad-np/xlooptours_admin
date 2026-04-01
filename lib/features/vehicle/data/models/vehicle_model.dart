import '../../domain/entities/vehicle_documents.dart';
import '../../domain/entities/vehicle_entity.dart';

class VehicleModel extends VehicleEntity {
  const VehicleModel({
    required super.id,
    required super.make,
    required super.model,
    required super.year,
    required super.color,
    required super.plateNumber,
    required super.type,
    super.assignedDriverId,
    super.imageUrl,
    super.isActive = true,
    super.insurance,
    super.registration,
    super.fahas,
    super.maintenance,
    super.vinNumber,
    super.engineNumber,
    super.fuelType,
    super.transmission,
    super.purchaseDate,
    super.purchasePrice,
    super.currentOdometer,
    super.lastOdometerUpdateDate,
    super.gvwr,
    super.tireSize,
    super.department,
    super.status,
    super.maintenanceIntervals,
    super.maintenanceHistory,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'make': make,
      'model': model,
      'year': year,
      'color': color,
      'plateNumber': plateNumber,
      'type': type,
      'assignedDriverId': assignedDriverId,
      'imageUrl': imageUrl,
      'isActive': isActive,
      'insurance': insurance != null ? _documentToJson(insurance!) : null,
      'registration':
          registration != null ? _documentToJson(registration!) : null,
      'fahas': fahas != null ? _documentToJson(fahas!) : null,
      'maintenance':
          maintenance != null ? _maintenanceToJson(maintenance!) : null,
      'vinNumber': vinNumber,
      'engineNumber': engineNumber,
      'fuelType': fuelType,
      'transmission': transmission,
      'purchaseDate': purchaseDate?.toIso8601String(),
      'purchasePrice': purchasePrice,
      'currentOdometer': currentOdometer,
      'lastOdometerUpdateDate': lastOdometerUpdateDate?.toIso8601String(),
      'gvwr': gvwr,
      'tireSize': tireSize,
      'department': department,
      'status': status,
      'maintenanceIntervals': maintenanceIntervals,
      'maintenanceHistory':
          maintenanceHistory?.map((e) => _recordToJson(e)).toList(),
    };
  }

  static Map<String, dynamic> _documentToJson(VehicleDocument doc) {
    return {
      'expiryDate': doc.expiryDate.toIso8601String(),
      'attachmentUrl': doc.attachmentUrl,
      'notificationDays': doc.notificationDays,
    };
  }

  static Map<String, dynamic> _maintenanceToJson(VehicleMaintenance maint) {
    return {
      'engineOil':
          maint.engineOil != null ? _recordToJson(maint.engineOil!) : null,
      'gearOil': maint.gearOil != null ? _recordToJson(maint.gearOil!) : null,
      'housingOil':
          maint.housingOil != null ? _recordToJson(maint.housingOil!) : null,
      'tyreChange':
          maint.tyreChange != null ? _recordToJson(maint.tyreChange!) : null,
      'batteryChange': maint.batteryChange != null
          ? _recordToJson(maint.batteryChange!)
          : null,
      'brakePads':
          maint.brakePads != null ? _recordToJson(maint.brakePads!) : null,
      'airFilter':
          maint.airFilter != null ? _recordToJson(maint.airFilter!) : null,
      'acService':
          maint.acService != null ? _recordToJson(maint.acService!) : null,
      'wheelAlignment': maint.wheelAlignment != null
          ? _recordToJson(maint.wheelAlignment!)
          : null,
      'sparkPlugs':
          maint.sparkPlugs != null ? _recordToJson(maint.sparkPlugs!) : null,
      'coolantFlush':
          maint.coolantFlush != null ? _recordToJson(maint.coolantFlush!) : null,
      'wiperBlades':
          maint.wiperBlades != null ? _recordToJson(maint.wiperBlades!) : null,
      'timingBelt':
          maint.timingBelt != null ? _recordToJson(maint.timingBelt!) : null,
      'transmissionFluid': maint.transmissionFluid != null
          ? _recordToJson(maint.transmissionFluid!)
          : null,
      'brakeFluid':
          maint.brakeFluid != null ? _recordToJson(maint.brakeFluid!) : null,
      'fuelFilter':
          maint.fuelFilter != null ? _recordToJson(maint.fuelFilter!) : null,
    };
  }

  static Map<String, dynamic> _recordToJson(MaintenanceRecord record) {
    return {
      'date': record.date.toIso8601String(),
      'mileage': record.mileage,
      'attachmentUrl': record.attachmentUrl,
      'notificationDays': record.notificationDays,
      'cost': record.cost,
      'partsCost': record.partsCost,
      'laborCost': record.laborCost,
      'serviceProvider': record.serviceProvider,
      'workOrderNumber': record.workOrderNumber,
      'serviceType': record.serviceType,
      'partsReplaced': record.partsReplaced,
      'notes': record.notes,
      'nextServiceMileage': record.nextServiceMileage,
      'nextServiceDate': record.nextServiceDate?.toIso8601String(),
    };
  }

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'] as String,
      make: json['make'] as String,
      model: json['model'] as String,
      year: json['year'] as int,
      color: json['color'] as String,
      plateNumber: json['plateNumber'] as String,
      type: json['type'] as String,
      assignedDriverId: json['assignedDriverId'] as String?,
      imageUrl: json['imageUrl'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      insurance: json['insurance'] != null
          ? _documentFromJson(json['insurance'] as Map<String, dynamic>)
          : null,
      registration: json['registration'] != null
          ? _documentFromJson(json['registration'] as Map<String, dynamic>)
          : null,
      fahas: json['fahas'] != null
          ? _documentFromJson(json['fahas'] as Map<String, dynamic>)
          : null,
      maintenance: json['maintenance'] != null
          ? _maintenanceFromJson(json['maintenance'] as Map<String, dynamic>)
          : null,
      vinNumber: json['vinNumber'] as String?,
      engineNumber: json['engineNumber'] as String?,
      fuelType: json['fuelType'] as String?,
      transmission: json['transmission'] as String?,
      purchaseDate: json['purchaseDate'] != null
          ? DateTime.parse(json['purchaseDate'] as String)
          : null,
      purchasePrice: (json['purchasePrice'] as num?)?.toDouble(),
      currentOdometer: json['currentOdometer'] as int?,
      lastOdometerUpdateDate: json['lastOdometerUpdateDate'] != null
          ? DateTime.parse(json['lastOdometerUpdateDate'] as String)
          : null,
      gvwr: json['gvwr'] as String?,
      tireSize: json['tireSize'] as String?,
      department: json['department'] as String?,
      status: json['status'] as String?,
      maintenanceIntervals: json['maintenanceIntervals'] != null
          ? Map<String, int>.from(json['maintenanceIntervals'] as Map)
          : null,
      maintenanceHistory: json['maintenanceHistory'] != null
          ? (json['maintenanceHistory'] as List)
              .map((e) => _recordFromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  static VehicleDocument _documentFromJson(Map<String, dynamic> json) {
    return VehicleDocument(
      expiryDate: DateTime.parse(json['expiryDate'] as String),
      attachmentUrl: json['attachmentUrl'] as String?,
      notificationDays: json['notificationDays'] as int?,
    );
  }

  static VehicleMaintenance _maintenanceFromJson(Map<String, dynamic> json) {
    return VehicleMaintenance(
      engineOil: json['engineOil'] != null
          ? _recordFromJson(json['engineOil'] as Map<String, dynamic>)
          : null,
      gearOil: json['gearOil'] != null
          ? _recordFromJson(json['gearOil'] as Map<String, dynamic>)
          : null,
      housingOil: json['housingOil'] != null
          ? _recordFromJson(json['housingOil'] as Map<String, dynamic>)
          : null,
      tyreChange: json['tyreChange'] != null
          ? _recordFromJson(json['tyreChange'] as Map<String, dynamic>)
          : null,
      batteryChange: json['batteryChange'] != null
          ? _recordFromJson(json['batteryChange'] as Map<String, dynamic>)
          : null,
      brakePads: json['brakePads'] != null
          ? _recordFromJson(json['brakePads'] as Map<String, dynamic>)
          : null,
      airFilter: json['airFilter'] != null
          ? _recordFromJson(json['airFilter'] as Map<String, dynamic>)
          : null,
      acService: json['acService'] != null
          ? _recordFromJson(json['acService'] as Map<String, dynamic>)
          : null,
      wheelAlignment: json['wheelAlignment'] != null
          ? _recordFromJson(json['wheelAlignment'] as Map<String, dynamic>)
          : null,
      sparkPlugs: json['sparkPlugs'] != null
          ? _recordFromJson(json['sparkPlugs'] as Map<String, dynamic>)
          : null,
      coolantFlush: json['coolantFlush'] != null
          ? _recordFromJson(json['coolantFlush'] as Map<String, dynamic>)
          : null,
      wiperBlades: json['wiperBlades'] != null
          ? _recordFromJson(json['wiperBlades'] as Map<String, dynamic>)
          : null,
      timingBelt: json['timingBelt'] != null
          ? _recordFromJson(json['timingBelt'] as Map<String, dynamic>)
          : null,
      transmissionFluid: json['transmissionFluid'] != null
          ? _recordFromJson(json['transmissionFluid'] as Map<String, dynamic>)
          : null,
      brakeFluid: json['brakeFluid'] != null
          ? _recordFromJson(json['brakeFluid'] as Map<String, dynamic>)
          : null,
      fuelFilter: json['fuelFilter'] != null
          ? _recordFromJson(json['fuelFilter'] as Map<String, dynamic>)
          : null,
    );
  }

  static MaintenanceRecord _recordFromJson(Map<String, dynamic> json) {
    return MaintenanceRecord(
      date: DateTime.parse(json['date'] as String),
      mileage: json['mileage'] as int,
      attachmentUrl: json['attachmentUrl'] as String?,
      notificationDays: json['notificationDays'] as int?,
      cost: (json['cost'] as num?)?.toDouble(),
      partsCost: (json['partsCost'] as num?)?.toDouble(),
      laborCost: (json['laborCost'] as num?)?.toDouble(),
      serviceProvider: json['serviceProvider'] as String?,
      workOrderNumber: json['workOrderNumber'] as String?,
      serviceType: json['serviceType'] as String?,
      partsReplaced: json['partsReplaced'] as String?,
      notes: json['notes'] as String?,
      nextServiceMileage: json['nextServiceMileage'] as int?,
      nextServiceDate: json['nextServiceDate'] != null
          ? DateTime.parse(json['nextServiceDate'] as String)
          : null,
    );
  }

  factory VehicleModel.fromEntity(VehicleEntity entity) {
    return VehicleModel(
      id: entity.id,
      make: entity.make,
      model: entity.model,
      year: entity.year,
      color: entity.color,
      plateNumber: entity.plateNumber,
      type: entity.type,
      assignedDriverId: entity.assignedDriverId,
      imageUrl: entity.imageUrl,
      isActive: entity.isActive,
      insurance: entity.insurance,
      registration: entity.registration,
      fahas: entity.fahas,
      maintenance: entity.maintenance,
      vinNumber: entity.vinNumber,
      engineNumber: entity.engineNumber,
      fuelType: entity.fuelType,
      transmission: entity.transmission,
      purchaseDate: entity.purchaseDate,
      purchasePrice: entity.purchasePrice,
      currentOdometer: entity.currentOdometer,
      lastOdometerUpdateDate: entity.lastOdometerUpdateDate,
      gvwr: entity.gvwr,
      tireSize: entity.tireSize,
      department: entity.department,
      status: entity.status,
      maintenanceIntervals: entity.maintenanceIntervals,
      maintenanceHistory: entity.maintenanceHistory,
    );
  }

  @override
  VehicleModel copyWith({
    String? id,
    String? make,
    String? model,
    int? year,
    String? color,
    String? plateNumber,
    String? type,
    String? assignedDriverId,
    String? imageUrl,
    bool? isActive,
    VehicleDocument? insurance,
    VehicleDocument? registration,
    VehicleDocument? fahas,
    VehicleMaintenance? maintenance,
    String? vinNumber,
    String? engineNumber,
    String? fuelType,
    String? transmission,
    DateTime? purchaseDate,
    double? purchasePrice,
    int? currentOdometer,
    DateTime? lastOdometerUpdateDate,
    String? gvwr,
    String? tireSize,
    String? department,
    String? status,
    Map<String, int>? maintenanceIntervals,
    List<MaintenanceRecord>? maintenanceHistory,
  }) {
    return VehicleModel(
      id: id ?? this.id,
      make: make ?? this.make,
      model: model ?? this.model,
      year: year ?? this.year,
      color: color ?? this.color,
      plateNumber: plateNumber ?? this.plateNumber,
      type: type ?? this.type,
      assignedDriverId: assignedDriverId ?? this.assignedDriverId,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      insurance: insurance ?? this.insurance,
      registration: registration ?? this.registration,
      fahas: fahas ?? this.fahas,
      maintenance: maintenance ?? this.maintenance,
      vinNumber: vinNumber ?? this.vinNumber,
      engineNumber: engineNumber ?? this.engineNumber,
      fuelType: fuelType ?? this.fuelType,
      transmission: transmission ?? this.transmission,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      currentOdometer: currentOdometer ?? this.currentOdometer,
      lastOdometerUpdateDate:
          lastOdometerUpdateDate ?? this.lastOdometerUpdateDate,
      gvwr: gvwr ?? this.gvwr,
      tireSize: tireSize ?? this.tireSize,
      department: department ?? this.department,
      status: status ?? this.status,
      maintenanceIntervals: maintenanceIntervals ?? this.maintenanceIntervals,
      maintenanceHistory: maintenanceHistory ?? this.maintenanceHistory,
    );
  }
}
