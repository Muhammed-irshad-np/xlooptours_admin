import 'package:equatable/equatable.dart';

class VehicleModelDetailEntity extends Equatable {
  final String name;
  final String type;

  const VehicleModelDetailEntity({required this.name, required this.type});

  @override
  List<Object?> get props => [name, type];
}

class VehicleMakeEntity extends Equatable {
  final String id;
  final String name;
  final String? logoUrl;
  final List<VehicleModelDetailEntity> models;
  final List<int> years;
  final List<String> colors;

  const VehicleMakeEntity({
    required this.id,
    required this.name,
    this.logoUrl,
    this.models = const [],
    this.years = const [],
    this.colors = const [],
  });

  @override
  List<Object?> get props => [id, name, logoUrl, models, years, colors];

  VehicleMakeEntity copyWith({
    String? id,
    String? name,
    String? logoUrl,
    List<VehicleModelDetailEntity>? models,
    List<int>? years,
    List<String>? colors,
  }) {
    return VehicleMakeEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      models: models ?? this.models,
      years: years ?? this.years,
      colors: colors ?? this.colors,
    );
  }
}
