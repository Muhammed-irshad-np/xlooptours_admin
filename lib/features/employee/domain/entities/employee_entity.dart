import 'package:equatable/equatable.dart';

class EmployeeEntity extends Equatable {
  final String id;
  final String fullName;
  final String position;
  final String email;
  final String phoneNumber;
  final String nationality;
  final String idType;
  final String idNumber;
  final DateTime? joinDate;
  final DateTime? birthDate;
  final String gender;
  final String? driverType; // Internal or External (only for Drivers)
  final bool isActive;
  final String? imageUrl;

  const EmployeeEntity({
    required this.id,
    required this.fullName,
    required this.position,
    required this.email,
    required this.phoneNumber,
    required this.nationality,
    required this.idType,
    required this.idNumber,
    this.joinDate,
    this.birthDate,
    required this.gender,
    this.driverType,
    this.isActive = true,
    this.imageUrl,
  });

  EmployeeEntity copyWith({
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
    return EmployeeEntity(
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

  @override
  List<Object?> get props => [
    id,
    fullName,
    position,
    email,
    phoneNumber,
    nationality,
    idType,
    idNumber,
    joinDate,
    birthDate,
    gender,
    driverType,
    isActive,
    imageUrl,
  ];
}
