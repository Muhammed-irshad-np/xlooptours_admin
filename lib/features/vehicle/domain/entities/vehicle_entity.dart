import 'package:equatable/equatable.dart';

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
    );
  }
}
