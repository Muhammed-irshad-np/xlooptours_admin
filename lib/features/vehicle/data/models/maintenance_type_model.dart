import '../../domain/entities/maintenance_type_entity.dart';

class MaintenanceTypeModel extends MaintenanceTypeEntity {
  const MaintenanceTypeModel({
    required super.id,
    required super.name,
    required super.defaultIntervalKm,
  });

  factory MaintenanceTypeModel.fromJson(Map<String, dynamic> json) {
    return MaintenanceTypeModel(
      id: json['id'] as String? ?? json['documentId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      defaultIntervalKm:
          json['defaultIntervalKm'] as int? ??
          5000, // provide a fallback interval
    );
  }

  factory MaintenanceTypeModel.fromEntity(MaintenanceTypeEntity entity) {
    return MaintenanceTypeModel(
      id: entity.id,
      name: entity.name,
      defaultIntervalKm: entity.defaultIntervalKm,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'defaultIntervalKm': defaultIntervalKm};
  }

  MaintenanceTypeModel copyWith({
    String? id,
    String? name,
    int? defaultIntervalKm,
  }) {
    return MaintenanceTypeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      defaultIntervalKm: defaultIntervalKm ?? this.defaultIntervalKm,
    );
  }
}
