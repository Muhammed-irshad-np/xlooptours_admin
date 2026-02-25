import '../../domain/entities/employee_entity.dart';

class EmployeeModel extends EmployeeEntity {
  const EmployeeModel({
    required super.id,
    required super.fullName,
    required super.position,
    required super.email,
    required super.phoneNumber,
    required super.nationality,
    required super.idType,
    required super.idNumber,
    super.joinDate,
    super.birthDate,
    required super.gender,
    super.driverType,
    super.isActive = true,
    super.imageUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'position': position,
      'email': email,
      'phoneNumber': phoneNumber,
      'nationality': nationality,
      'idType': idType,
      'idNumber': idNumber,
      'joinDate': joinDate?.toIso8601String(),
      'birthDate': birthDate?.toIso8601String(),
      'gender': gender,
      'driverType': driverType,
      'isActive': isActive,
      'imageUrl': imageUrl,
    };
  }

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      position: json['position'] as String,
      email: json['email'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      nationality: json['nationality'] as String? ?? '',
      idType: json['idType'] as String? ?? '',
      idNumber: json['idNumber'] as String? ?? '',
      joinDate: json['joinDate'] != null
          ? DateTime.tryParse(json['joinDate'] as String)
          : null,
      birthDate: json['birthDate'] != null
          ? DateTime.tryParse(json['birthDate'] as String)
          : null,
      gender: json['gender'] as String? ?? '',
      driverType: json['driverType'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  factory EmployeeModel.fromEntity(EmployeeEntity entity) {
    return EmployeeModel(
      id: entity.id,
      fullName: entity.fullName,
      position: entity.position,
      email: entity.email,
      phoneNumber: entity.phoneNumber,
      nationality: entity.nationality,
      idType: entity.idType,
      idNumber: entity.idNumber,
      joinDate: entity.joinDate,
      birthDate: entity.birthDate,
      gender: entity.gender,
      driverType: entity.driverType,
      isActive: entity.isActive,
      imageUrl: entity.imageUrl,
    );
  }

  @override
  EmployeeModel copyWith({
    String? id,
    String? fullName,
    String? position,
    String? email,
    String? phoneNumber,
    String? nationality,
    String? idType,
    String? idNumber,
    DateTime? joinDate,
    DateTime? birthDate,
    String? gender,
    String? driverType,
    bool? isActive,
    String? imageUrl,
  }) {
    return EmployeeModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      position: position ?? this.position,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      nationality: nationality ?? this.nationality,
      idType: idType ?? this.idType,
      idNumber: idNumber ?? this.idNumber,
      joinDate: joinDate ?? this.joinDate,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      driverType: driverType ?? this.driverType,
      isActive: isActive ?? this.isActive,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
