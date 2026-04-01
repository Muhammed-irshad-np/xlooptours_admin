import 'package:equatable/equatable.dart';
import 'vehicle_documents.dart';

class VehicleEntity extends Equatable {
  final String id;
  final String make;
  final String model;
  final int year;
  final String color;
  final String plateNumber;
  final String type; // e.g., SUV, Sedan
  final String? assignedDriverId; // Reference to Employee ID
  final String? imageUrl;
  final bool isActive;
  final VehicleDocument? insurance;
  final VehicleDocument? registration;
  final VehicleDocument? fahas;
  final VehicleMaintenance? maintenance;
  final String? vinNumber;
  final String? engineNumber;
  final String? fuelType;
  final String? transmission;
  final DateTime? purchaseDate;
  final double? purchasePrice;
  final int? currentOdometer;
  final DateTime? lastOdometerUpdateDate;
  final String? gvwr;
  final String? tireSize;
  final String? department;
  final String? status;

  const VehicleEntity({
    required this.id,
    required this.make,
    required this.model,
    required this.year,
    required this.color,
    required this.plateNumber,
    required this.type,
    this.assignedDriverId,
    this.imageUrl,
    this.isActive = true,
    this.insurance,
    this.registration,
    this.fahas,
    this.maintenance,
    this.vinNumber,
    this.engineNumber,
    this.fuelType,
    this.transmission,
    this.purchaseDate,
    this.purchasePrice,
    this.currentOdometer,
    this.lastOdometerUpdateDate,
    this.gvwr,
    this.tireSize,
    this.department,
    this.status,
  });

  @override
  List<Object?> get props => [
        id,
        make,
        model,
        year,
        color,
        plateNumber,
        type,
        assignedDriverId,
        imageUrl,
        isActive,
        insurance,
        registration,
        fahas,
        maintenance,
        vinNumber,
        engineNumber,
        fuelType,
        transmission,
        purchaseDate,
        purchasePrice,
        currentOdometer,
        lastOdometerUpdateDate,
        gvwr,
        tireSize,
        department,
        status,
      ];

  VehicleEntity copyWith({
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
  }) {
    return VehicleEntity(
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
    );
  }
}
