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
      'batteryChange':
          maint.batteryChange != null ? _recordToJson(maint.batteryChange!) : null,
    };
  }

  static Map<String, dynamic> _recordToJson(MaintenanceRecord record) {
    return {
      'date': record.date.toIso8601String(),
      'mileage': record.mileage,
      'attachmentUrl': record.attachmentUrl,
      'notificationDays': record.notificationDays,
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
    );
  }

  static MaintenanceRecord _recordFromJson(Map<String, dynamic> json) {
    return MaintenanceRecord(
      date: DateTime.parse(json['date'] as String),
      mileage: json['mileage'] as int,
      attachmentUrl: json['attachmentUrl'] as String?,
      notificationDays: json['notificationDays'] as int?,
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
    );
  }
}
