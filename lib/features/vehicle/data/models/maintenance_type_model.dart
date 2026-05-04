import '../../domain/entities/maintenance_type_entity.dart';

class MaintenanceTypeModel extends MaintenanceTypeEntity {
  const MaintenanceTypeModel({
    required super.id,
    required super.name,
    required super.suvIntervalKm,
    required super.sedanIntervalKm,
  });

  factory MaintenanceTypeModel.fromJson(Map<String, dynamic> json) {
    final defaultInterval = json['defaultIntervalKm'] as int? ?? 5000;
    return MaintenanceTypeModel(
      id: json['id'] as String? ?? json['documentId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      suvIntervalKm: json['suvIntervalKm'] as int? ?? defaultInterval,
      sedanIntervalKm: json['sedanIntervalKm'] as int? ?? defaultInterval,
    );
  }

  factory MaintenanceTypeModel.fromEntity(MaintenanceTypeEntity entity) {
    return MaintenanceTypeModel(
      id: entity.id,
      name: entity.name,
      suvIntervalKm: entity.suvIntervalKm,
      sedanIntervalKm: entity.sedanIntervalKm,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'suvIntervalKm': suvIntervalKm,
      'sedanIntervalKm': sedanIntervalKm,
      'defaultIntervalKm': defaultIntervalKm, // keep writing for legacy clients if any
    };
  }

  MaintenanceTypeModel copyWith({
    String? id,
    String? name,
    int? suvIntervalKm,
    int? sedanIntervalKm,
  }) {
    return MaintenanceTypeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      suvIntervalKm: suvIntervalKm ?? this.suvIntervalKm,
      sedanIntervalKm: sedanIntervalKm ?? this.sedanIntervalKm,
    );
  }
}
