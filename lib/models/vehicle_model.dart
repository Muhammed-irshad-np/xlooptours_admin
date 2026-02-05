class VehicleModel {
  final String id;
  final String make;
  final String model;
  final int year;
  final String color;
  final String plateNumber;
  final String type; // e.g., SUV, Sedan
  final String? assignedDriverId; // Reference to Employee ID
  final String? contactCardReference;
  final String? imageUrl;
  final bool isActive;

  VehicleModel({
    required this.id,
    required this.make,
    required this.model,
    required this.year,
    required this.color,
    required this.plateNumber,
    required this.type,
    this.assignedDriverId,
    this.contactCardReference,
    this.imageUrl,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'make': make,
      'model': model,
      'year': year,
      'color': color,
      'plateNumber': plateNumber,
      'type': type,
      'assignedDriverId': assignedDriverId,
      'contactCardReference': contactCardReference,
      'imageUrl': imageUrl,
      'isActive': isActive,
    };
  }

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'] as String,
      make: json['make'] as String,
      model: json['model'] as String,
      year: json['year'] as int,
      color: json['color'] as String,
      plateNumber: json['plateNumber'] as String,
      type: json['type'] as String,
      assignedDriverId: json['assignedDriverId'] as String?,
      contactCardReference: json['contactCardReference'] as String?,
      imageUrl: json['imageUrl'] as String?,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  VehicleModel copyWith({
    String? id,
    String? make,
    String? model,
    int? year,
    String? color,
    String? plateNumber,
    String? type,
    String? assignedDriverId,
    String? contactCardReference,
    String? imageUrl,
    bool? isActive,
  }) {
    return VehicleModel(
      id: id ?? this.id,
      make: make ?? this.make,
      model: model ?? this.model,
      year: year ?? this.year,
      color: color ?? this.color,
      plateNumber: plateNumber ?? this.plateNumber,
      type: type ?? this.type,
      assignedDriverId: assignedDriverId ?? this.assignedDriverId,
      contactCardReference: contactCardReference ?? this.contactCardReference,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
    );
  }
}
