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
  String? get currentDriverId {
    if (tafweeds != null && tafweeds!.isNotEmpty) {
      return tafweeds!.last.driverId;
    }
    return null;
  }
  
  final String? imageUrl;
  final bool isActive;
  final VehicleDocument? insurance;
  final VehicleDocument? bahrainInsurance;
  final VehicleDocument? registration;
  final VehicleDocument? fahas;
  final VehicleMaintenance? maintenance;
  final List<TafweedRecord>? tafweeds;
  /// Archived tafweed records — moved here when a driver is swapped off
  /// a vehicle, preserving the full assignment history for auditing.
  final List<TafweedRecord>? tafweedHistory;
  final String? vinNumber;
  final String? engineNumber;
  final String? fuelType;
  final String? transmission;
  final DateTime? purchaseDate;
  final double? purchasePrice;
  final int? purchaseOdometer;
  final int? currentOdometer;
  final DateTime? lastOdometerUpdateDate;
  final String? gvwr;
  final String? tireSize;
  final String? department;
  final String? status;
  final List<MaintenanceRecord>? maintenanceHistory;

  const VehicleEntity({
    required this.id,
    required this.make,
    required this.model,
    required this.year,
    required this.color,
    required this.plateNumber,
    required this.type,
    this.imageUrl,
    this.isActive = true,
    this.insurance,
    this.bahrainInsurance,
    this.registration,
    this.fahas,
    this.maintenance,
    this.tafweeds,
    this.tafweedHistory,
    this.vinNumber,
    this.engineNumber,
    this.fuelType,
    this.transmission,
    this.purchaseDate,
    this.purchasePrice,
    this.purchaseOdometer,
    this.currentOdometer,
    this.lastOdometerUpdateDate,
    this.gvwr,
    this.tireSize,
    this.department,
    this.status,
    this.maintenanceHistory,
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
    imageUrl,
    isActive,
    insurance,
    bahrainInsurance,
    registration,
    fahas,
    maintenance,
    tafweeds,
    tafweedHistory,
    vinNumber,
    engineNumber,
    fuelType,
    transmission,
    purchaseDate,
    purchasePrice,
    purchaseOdometer,
    currentOdometer,
    lastOdometerUpdateDate,
    gvwr,
    tireSize,
    department,
    status,
    maintenanceHistory,
  ];

  VehicleEntity copyWith({
    String? id,
    String? make,
    String? model,
    int? year,
    String? color,
    String? plateNumber,
    String? type,
    String? imageUrl,
    bool? isActive,
    VehicleDocument? insurance,
    VehicleDocument? bahrainInsurance,
    VehicleDocument? registration,
    VehicleDocument? fahas,
    VehicleMaintenance? maintenance,
    List<TafweedRecord>? tafweeds,
    List<TafweedRecord>? tafweedHistory,
    String? vinNumber,
    String? engineNumber,
    String? fuelType,
    String? transmission,
    DateTime? purchaseDate,
    double? purchasePrice,
    int? purchaseOdometer,
    int? currentOdometer,
    DateTime? lastOdometerUpdateDate,
    String? gvwr,
    String? tireSize,
    String? department,
    String? status,
    List<MaintenanceRecord>? maintenanceHistory,
    bool clearInsurance = false,
    bool clearBahrainInsurance = false,
    bool clearRegistration = false,
    bool clearFahas = false,
  }) {
    return VehicleEntity(
      id: id ?? this.id,
      make: make ?? this.make,
      model: model ?? this.model,
      year: year ?? this.year,
      color: color ?? this.color,
      plateNumber: plateNumber ?? this.plateNumber,
      type: type ?? this.type,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      insurance: clearInsurance ? null : (insurance ?? this.insurance),
      bahrainInsurance: clearBahrainInsurance
          ? null
          : (bahrainInsurance ?? this.bahrainInsurance),
      registration: clearRegistration
          ? null
          : (registration ?? this.registration),
      fahas: clearFahas ? null : (fahas ?? this.fahas),
      maintenance: maintenance ?? this.maintenance,
      tafweeds: tafweeds ?? this.tafweeds,
      tafweedHistory: tafweedHistory ?? this.tafweedHistory,
      vinNumber: vinNumber ?? this.vinNumber,
      engineNumber: engineNumber ?? this.engineNumber,
      fuelType: fuelType ?? this.fuelType,
      transmission: transmission ?? this.transmission,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      purchaseOdometer: purchaseOdometer ?? this.purchaseOdometer,
      currentOdometer: currentOdometer ?? this.currentOdometer,
      lastOdometerUpdateDate:
          lastOdometerUpdateDate ?? this.lastOdometerUpdateDate,
      gvwr: gvwr ?? this.gvwr,
      tireSize: tireSize ?? this.tireSize,
      department: department ?? this.department,
      status: status ?? this.status,
      maintenanceHistory: maintenanceHistory ?? this.maintenanceHistory,
    );
  }
}
