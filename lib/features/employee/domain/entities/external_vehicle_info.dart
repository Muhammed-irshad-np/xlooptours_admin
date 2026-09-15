import 'package:equatable/equatable.dart';

/// Vehicle owned/driven by an *external* driver.
///
/// External drivers are not part of the company fleet, so their car is not a
/// [VehicleEntity] record — but make/model/color are still picked from the
/// same Vehicle Master (`VehicleMakeEntity`) used for fleet vehicles, rather
/// than typed freely, to keep the data consistent and easy to search.
class ExternalVehicleInfo extends Equatable {
  final String make;
  final String model;
  final int? year;
  final String vehicleColor;
  final String plateNumber;

  const ExternalVehicleInfo({
    required this.make,
    required this.model,
    this.year,
    required this.vehicleColor,
    required this.plateNumber,
  });

  bool get isEmpty =>
      make.isEmpty && model.isEmpty && vehicleColor.isEmpty && plateNumber.isEmpty;

  /// e.g. `GMC Yukon 2018`.
  String get vehicleDescription => [
        make,
        model,
        if (year != null) year.toString(),
      ].where((p) => p.isNotEmpty).join(' ');

  /// Single-line summary, e.g. `GMC Yukon 2018 · Gold · 3360 GLJ`.
  String get summary => [
        vehicleDescription,
        vehicleColor,
        plateNumber,
      ].where((p) => p.isNotEmpty).join(' · ');

  ExternalVehicleInfo copyWith({
    String? make,
    String? model,
    int? year,
    String? vehicleColor,
    String? plateNumber,
    bool clearYear = false,
  }) {
    return ExternalVehicleInfo(
      make: make ?? this.make,
      model: model ?? this.model,
      year: clearYear ? null : (year ?? this.year),
      vehicleColor: vehicleColor ?? this.vehicleColor,
      plateNumber: plateNumber ?? this.plateNumber,
    );
  }

  @override
  List<Object?> get props => [make, model, year, vehicleColor, plateNumber];
}
