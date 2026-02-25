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
    );
  }
}
