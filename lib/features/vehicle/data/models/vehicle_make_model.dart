import '../../domain/entities/vehicle_make_entity.dart';

class VehicleModelDetailModel extends VehicleModelDetailEntity {
  const VehicleModelDetailModel({required super.name, required super.type});

  Map<String, dynamic> toJson() => {'name': name, 'type': type};

  factory VehicleModelDetailModel.fromJson(Map<String, dynamic> json) {
    return VehicleModelDetailModel(
      name: json['name'] as String,
      type: json['type'] as String? ?? 'Sedan', // Default fallback
    );
  }

  factory VehicleModelDetailModel.fromEntity(VehicleModelDetailEntity entity) {
    return VehicleModelDetailModel(name: entity.name, type: entity.type);
  }
}

class VehicleMakeModel extends VehicleMakeEntity {
  const VehicleMakeModel({
    required super.id,
    required super.name,
    super.logoUrl,
    super.models = const [],
    super.years = const [],
    super.colors = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'logoUrl': logoUrl,
      'models': models
          .map((e) => VehicleModelDetailModel.fromEntity(e).toJson())
          .toList(),
      'years': years,
      'colors': colors,
    };
  }

  factory VehicleMakeModel.fromJson(Map<String, dynamic> json) {
    var rawModels = json['models'];
    List<VehicleModelDetailModel> parsedModels = [];

    if (rawModels != null) {
      if (rawModels is List) {
        for (var item in rawModels) {
          if (item is String) {
            // Backward compatibility for old string-only models
            parsedModels.add(
              VehicleModelDetailModel(name: item, type: 'Sedan'),
            );
          } else if (item is Map<String, dynamic>) {
            parsedModels.add(VehicleModelDetailModel.fromJson(item));
          }
        }
      }
    }

    return VehicleMakeModel(
      id: json['id'] as String,
      name: json['name'] as String,
      logoUrl: json['logoUrl'] as String?,
      models: parsedModels,
      years:
          (json['years'] as List<dynamic>?)?.map((e) => e as int).toList() ??
          [],
      colors:
          (json['colors'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  factory VehicleMakeModel.fromEntity(VehicleMakeEntity entity) {
    return VehicleMakeModel(
      id: entity.id,
      name: entity.name,
      logoUrl: entity.logoUrl,
      models: entity.models
          .map((e) => VehicleModelDetailModel.fromEntity(e))
          .toList(),
      years: entity.years,
      colors: entity.colors,
    );
  }

  @override
  VehicleMakeModel copyWith({
    String? id,
    String? name,
    String? logoUrl,
    List<VehicleModelDetailEntity>? models,
    List<int>? years,
    List<String>? colors,
  }) {
    return VehicleMakeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      models: models ?? this.models,
      years: years ?? this.years,
      colors: colors ?? this.colors,
    );
  }
}
