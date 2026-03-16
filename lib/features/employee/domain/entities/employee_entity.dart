import 'package:equatable/equatable.dart';
import 'employee_documents.dart';

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
  final String? assignedVehicleId;
  final IqamaDocument? iqama;
  final DrivingLicenseDocument? drivingLicense;
  final PassportDocument? passport;
  final VisaDocument? saudiVisa;
  final VisaDocument? bahrainVisa;
  final VisaDocument? dubaiVisa;
  final VisaDocument? qatarVisa;
  final AuthorizationDocument? authorization;
  final DateTime? phoneRechargeDate;
  final int? phoneRechargeNotificationDays;

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
    this.assignedVehicleId,
    this.iqama,
    this.drivingLicense,
    this.passport,
    this.saudiVisa,
    this.bahrainVisa,
    this.dubaiVisa,
    this.qatarVisa,
    this.authorization,
    this.phoneRechargeDate,
    this.phoneRechargeNotificationDays,
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
    String? assignedVehicleId,
    IqamaDocument? iqama,
    DrivingLicenseDocument? drivingLicense,
    PassportDocument? passport,
    VisaDocument? saudiVisa,
    VisaDocument? bahrainVisa,
    VisaDocument? dubaiVisa,
    VisaDocument? qatarVisa,
    AuthorizationDocument? authorization,
    DateTime? phoneRechargeDate,
    int? phoneRechargeNotificationDays,
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
      assignedVehicleId: assignedVehicleId ?? this.assignedVehicleId,
      iqama: iqama ?? this.iqama,
      drivingLicense: drivingLicense ?? this.drivingLicense,
      passport: passport ?? this.passport,
      saudiVisa: saudiVisa ?? this.saudiVisa,
      bahrainVisa: bahrainVisa ?? this.bahrainVisa,
      dubaiVisa: dubaiVisa ?? this.dubaiVisa,
      qatarVisa: qatarVisa ?? this.qatarVisa,
      authorization: authorization ?? this.authorization,
      phoneRechargeDate: phoneRechargeDate ?? this.phoneRechargeDate,
      phoneRechargeNotificationDays:
          phoneRechargeNotificationDays ?? this.phoneRechargeNotificationDays,
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
    assignedVehicleId,
    iqama,
    drivingLicense,
    passport,
    saudiVisa,
    bahrainVisa,
    dubaiVisa,
    qatarVisa,
    authorization,
    phoneRechargeDate,
    phoneRechargeNotificationDays,
  ];
}
