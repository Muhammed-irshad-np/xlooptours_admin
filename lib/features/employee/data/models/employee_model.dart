import '../../domain/entities/employee_entity.dart';
import '../../domain/entities/employee_documents.dart';
import 'employee_document_models.dart';

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
    super.assignedVehicleId,
    super.iqama,
    super.drivingLicense,
    super.passport,
    super.saudiVisa,
    super.bahrainVisa,
    super.authorization,
    super.phoneRechargeDate,
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
      'assignedVehicleId': assignedVehicleId,
      'iqama': iqama != null
          ? IqamaModel(
              number: iqama!.number,
              expiryDate: iqama!.expiryDate,
              insuranceExpiryDate: iqama!.insuranceExpiryDate,
            ).toJson()
          : null,
      'drivingLicense': drivingLicense != null
          ? DrivingLicenseModel(
              countryOfOrigin: drivingLicense!.countryOfOrigin,
              number: drivingLicense!.number,
              expiryDate: drivingLicense!.expiryDate,
              type: drivingLicense!.type,
            ).toJson()
          : null,
      'passport': passport != null
          ? PassportModel(
              nameOnPassport: passport!.nameOnPassport,
              number: passport!.number,
              expiryDate: passport!.expiryDate,
            ).toJson()
          : null,
      'saudiVisa': saudiVisa != null
          ? VisaModel(
              number: saudiVisa!.number,
              expiryDate: saudiVisa!.expiryDate,
              type: saudiVisa!.type,
              attachmentUrl: saudiVisa!.attachmentUrl,
            ).toJson()
          : null,
      'bahrainVisa': bahrainVisa != null
          ? VisaModel(
              number: bahrainVisa!.number,
              expiryDate: bahrainVisa!.expiryDate,
              type: bahrainVisa!.type,
              attachmentUrl: bahrainVisa!.attachmentUrl,
            ).toJson()
          : null,
      'authorization': authorization != null
          ? AuthorizationModel(expiryDate: authorization!.expiryDate).toJson()
          : null,
      'phoneRechargeDate': phoneRechargeDate?.toIso8601String(),
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
      assignedVehicleId: json['assignedVehicleId'] as String?,
      iqama: json['iqama'] != null
          ? IqamaModel.fromJson(json['iqama'] as Map<String, dynamic>)
          : null,
      drivingLicense: json['drivingLicense'] != null
          ? DrivingLicenseModel.fromJson(
              json['drivingLicense'] as Map<String, dynamic>,
            )
          : null,
      passport: json['passport'] != null
          ? PassportModel.fromJson(json['passport'] as Map<String, dynamic>)
          : null,
      saudiVisa: json['saudiVisa'] != null
          ? VisaModel.fromJson(json['saudiVisa'] as Map<String, dynamic>)
          : null,
      bahrainVisa: json['bahrainVisa'] != null
          ? VisaModel.fromJson(json['bahrainVisa'] as Map<String, dynamic>)
          : null,
      authorization: json['authorization'] != null
          ? AuthorizationModel.fromJson(
              json['authorization'] as Map<String, dynamic>,
            )
          : null,
      phoneRechargeDate: json['phoneRechargeDate'] != null
          ? DateTime.tryParse(json['phoneRechargeDate'] as String)
          : null,
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
      assignedVehicleId: entity.assignedVehicleId,
      iqama: entity.iqama,
      drivingLicense: entity.drivingLicense,
      passport: entity.passport,
      saudiVisa: entity.saudiVisa,
      bahrainVisa: entity.bahrainVisa,
      authorization: entity.authorization,
      phoneRechargeDate: entity.phoneRechargeDate,
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
    String? assignedVehicleId,
    IqamaDocument? iqama,
    DrivingLicenseDocument? drivingLicense,
    PassportDocument? passport,
    VisaDocument? saudiVisa,
    VisaDocument? bahrainVisa,
    AuthorizationDocument? authorization,
    DateTime? phoneRechargeDate,
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
      assignedVehicleId: assignedVehicleId ?? this.assignedVehicleId,
      iqama: iqama ?? this.iqama as IqamaModel?,
      drivingLicense:
          drivingLicense ?? this.drivingLicense as DrivingLicenseModel?,
      passport: passport ?? this.passport as PassportModel?,
      saudiVisa: saudiVisa ?? this.saudiVisa as VisaModel?,
      bahrainVisa: bahrainVisa ?? this.bahrainVisa as VisaModel?,
      authorization: authorization ?? this.authorization as AuthorizationModel?,
      phoneRechargeDate: phoneRechargeDate ?? this.phoneRechargeDate,
    );
  }
}
