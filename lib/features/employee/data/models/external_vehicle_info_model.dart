import '../../domain/entities/external_vehicle_info.dart';

class ExternalVehicleInfoModel extends ExternalVehicleInfo {
  const ExternalVehicleInfoModel({
    required super.make,
    required super.model,
    super.year,
    required super.vehicleColor,
    required super.plateNumber,
  });

  Map<String, dynamic> toJson() {
    return {
      'make': make,
      'model': model,
      'year': year,
      'vehicleColor': vehicleColor,
      'plateNumber': plateNumber,
    };
  }

  factory ExternalVehicleInfoModel.fromJson(Map<String, dynamic> json) {
    return ExternalVehicleInfoModel(
      make: json['make'] as String? ?? '',
      model: json['model'] as String? ?? '',
      year: json['year'] as int?,
      vehicleColor: json['vehicleColor'] as String? ?? '',
      plateNumber: json['plateNumber'] as String? ?? '',
    );
  }

  factory ExternalVehicleInfoModel.fromEntity(ExternalVehicleInfo entity) {
    return ExternalVehicleInfoModel(
      make: entity.make,
      model: entity.model,
      year: entity.year,
      vehicleColor: entity.vehicleColor,
      plateNumber: entity.plateNumber,
    );
  }
}
