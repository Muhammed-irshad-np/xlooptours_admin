class VehicleModelDetail {
  final String name;
  final String type;

  VehicleModelDetail({required this.name, required this.type});

  Map<String, dynamic> toJson() => {'name': name, 'type': type};

  factory VehicleModelDetail.fromJson(Map<String, dynamic> json) {
    return VehicleModelDetail(
      name: json['name'] as String,
      type: json['type'] as String? ?? 'Sedan', // Default fallback
    );
  }
}

class VehicleMakeModel {
  final String id;
  final String name;
  final String? logoUrl;
  final List<VehicleModelDetail> models;
  final List<int> years;
  final List<String> colors;

  VehicleMakeModel({
    required this.id,
    required this.name,
    this.logoUrl,
    this.models = const [],
    this.years = const [],
    this.colors = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'logoUrl': logoUrl,
      'models': models.map((e) => e.toJson()).toList(),
      'years': years,
      'colors': colors,
    };
  }

  factory VehicleMakeModel.fromJson(Map<String, dynamic> json) {
    var rawModels = json['models'];
    List<VehicleModelDetail> parsedModels = [];

    if (rawModels != null) {
      if (rawModels is List) {
        for (var item in rawModels) {
          if (item is String) {
            // Backward compatibility for old string-only models
            parsedModels.add(VehicleModelDetail(name: item, type: 'Sedan'));
          } else if (item is Map<String, dynamic>) {
            parsedModels.add(VehicleModelDetail.fromJson(item));
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

  VehicleMakeModel copyWith({
    String? id,
    String? name,
    String? logoUrl,
    List<VehicleModelDetail>? models,
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
