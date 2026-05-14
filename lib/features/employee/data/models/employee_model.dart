import '../../domain/entities/employee_contact.dart';
import '../../domain/entities/employee_entity.dart';
import '../../domain/entities/employee_documents.dart';
import 'employee_contact_model.dart';
import 'employee_document_models.dart';

class EmployeeModel extends EmployeeEntity {
  const EmployeeModel({
    required super.id,
    required super.fullName,
    required super.position,
    required super.email,
    required super.phoneNumber,
    super.countryCode,
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
    super.bahrainResidence,
    super.healthInsurance,
    super.drivingLicense,
    super.passport,
    super.saudiVisa,
    super.bahrainVisa,
    super.dubaiVisa,
    super.qatarVisa,
    super.authorization,
    super.contacts,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'position': position,
      'email': email,
      'phoneNumber': phoneNumber,
      'countryCode': countryCode,
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
              attachmentUrl: iqama!.attachmentUrl,
            ).toJson()
          : null,
      'bahrainResidence': bahrainResidence != null
          ? BahrainResidenceModel(
              number: bahrainResidence!.number,
              expiryDate: bahrainResidence!.expiryDate,
              attachmentUrl: bahrainResidence!.attachmentUrl,
            ).toJson()
          : null,
      'healthInsurance': healthInsurance != null
          ? HealthInsuranceModel(
              expiryDate: healthInsurance!.expiryDate,
              attachmentUrl: healthInsurance!.attachmentUrl,
            ).toJson()
          : null,
      'drivingLicense': drivingLicense != null
          ? DrivingLicenseModel(
              countryOfOrigin: drivingLicense!.countryOfOrigin,
              number: drivingLicense!.number,
              expiryDate: drivingLicense!.expiryDate,
              type: drivingLicense!.type,
              attachmentUrl: drivingLicense!.attachmentUrl,
            ).toJson()
          : null,
      'passport': passport != null
          ? PassportModel(
              nameOnPassport: passport!.nameOnPassport,
              number: passport!.number,
              expiryDate: passport!.expiryDate,
              attachmentUrl: passport!.attachmentUrl,
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
      'dubaiVisa': dubaiVisa != null
          ? VisaModel(
              number: dubaiVisa!.number,
              expiryDate: dubaiVisa!.expiryDate,
              type: dubaiVisa!.type,
              attachmentUrl: dubaiVisa!.attachmentUrl,
            ).toJson()
          : null,
      'qatarVisa': qatarVisa != null
          ? VisaModel(
              number: qatarVisa!.number,
              expiryDate: qatarVisa!.expiryDate,
              type: qatarVisa!.type,
              attachmentUrl: qatarVisa!.attachmentUrl,
            ).toJson()
          : null,
      'authorization': authorization != null
          ? AuthorizationModel(
              expiryDate: authorization!.expiryDate,
              attachmentUrl: authorization!.attachmentUrl,
            ).toJson()
          : null,
      'contacts': contacts
          .map((c) => EmployeeContactModel.fromEntity(c).toJson())
          .toList(),
    };
  }

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      position: json['position'] as String,
      email: json['email'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      countryCode: json['countryCode'] as String?,
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
      bahrainResidence: json['bahrainResidence'] != null
          ? BahrainResidenceModel.fromJson(
              json['bahrainResidence'] as Map<String, dynamic>,
            )
          : null,
      healthInsurance: json['healthInsurance'] != null
          ? HealthInsuranceModel.fromJson(
              json['healthInsurance'] as Map<String, dynamic>,
            )
          : (json['iqama'] != null &&
                  json['iqama']['insuranceExpiryDate'] != null)
              ? HealthInsuranceModel(
                  expiryDate: DateTime.parse(
                      json['iqama']['insuranceExpiryDate'] as String),
                )
              : (json['bahrainResidence'] != null &&
                      json['bahrainResidence']['insuranceExpiryDate'] != null)
                  ? HealthInsuranceModel(
                      expiryDate: DateTime.parse(json['bahrainResidence']
                          ['insuranceExpiryDate'] as String),
                    )
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
      dubaiVisa: json['dubaiVisa'] != null
          ? VisaModel.fromJson(json['dubaiVisa'] as Map<String, dynamic>)
          : null,
      qatarVisa: json['qatarVisa'] != null
          ? VisaModel.fromJson(json['qatarVisa'] as Map<String, dynamic>)
          : null,
      authorization: json['authorization'] != null
          ? AuthorizationModel.fromJson(
              json['authorization'] as Map<String, dynamic>,
            )
          : null,
      contacts: _parseContacts(json),
    );
  }

  /// Parses contacts from JSON, with backward compatibility for old
  /// `phoneRechargeDate` field.
  static List<EmployeeContact> _parseContacts(Map<String, dynamic> json) {
    if (json['contacts'] != null && json['contacts'] is List) {
      return (json['contacts'] as List)
          .map((c) => EmployeeContactModel.fromJson(c as Map<String, dynamic>))
          .toList();
    }
    // Backward compatibility: migrate old flat phoneRechargeDate
    if (json['phoneRechargeDate'] != null) {
      final legacyDate = DateTime.tryParse(json['phoneRechargeDate'] as String);
      if (legacyDate != null) {
        return [
          EmployeeContactModel(
            id: 'legacy_recharge',
            phoneNumber: json['phoneNumber'] as String? ?? '',
            countryCode: '+966',
            label: 'Primary',
            rechargeExpiryDate: legacyDate,
            notificationDays:
                json['phoneRechargeNotificationDays'] as int? ?? 30,
          ),
        ];
      }
    }
    return [];
  }

  factory EmployeeModel.fromEntity(EmployeeEntity entity) {
    return EmployeeModel(
      id: entity.id,
      fullName: entity.fullName,
      position: entity.position,
      email: entity.email,
      phoneNumber: entity.phoneNumber,
      countryCode: entity.countryCode,
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
      bahrainResidence: entity.bahrainResidence,
      healthInsurance: entity.healthInsurance,
      drivingLicense: entity.drivingLicense,
      passport: entity.passport,
      saudiVisa: entity.saudiVisa,
      bahrainVisa: entity.bahrainVisa,
      dubaiVisa: entity.dubaiVisa,
      qatarVisa: entity.qatarVisa,
      authorization: entity.authorization,
      contacts: entity.contacts,
    );
  }

  @override
  EmployeeModel copyWith({
    String? id,
    String? fullName,
    String? position,
    String? email,
    String? phoneNumber,
    String? countryCode,
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
    BahrainResidenceDocument? bahrainResidence,
    HealthInsuranceDocument? healthInsurance,
    DrivingLicenseDocument? drivingLicense,
    PassportDocument? passport,
    VisaDocument? saudiVisa,
    VisaDocument? bahrainVisa,
    VisaDocument? dubaiVisa,
    VisaDocument? qatarVisa,
    AuthorizationDocument? authorization,
    List<EmployeeContact>? contacts,
    // Clear flags — must match EmployeeEntity.copyWith signature
    bool clearIqama = false,
    bool clearBahrainResidence = false,
    bool clearHealthInsurance = false,
    bool clearDrivingLicense = false,
    bool clearPassport = false,
    bool clearSaudiVisa = false,
    bool clearBahrainVisa = false,
    bool clearDubaiVisa = false,
    bool clearQatarVisa = false,
    bool clearAuthorization = false,
  }) {
    return EmployeeModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      position: position ?? this.position,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      countryCode: countryCode ?? this.countryCode,
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
      iqama: clearIqama ? null : (iqama ?? this.iqama),
      bahrainResidence: clearBahrainResidence ? null : (bahrainResidence ?? this.bahrainResidence),
      healthInsurance: clearHealthInsurance ? null : (healthInsurance ?? this.healthInsurance),
      drivingLicense: clearDrivingLicense ? null : (drivingLicense ?? this.drivingLicense),
      passport: clearPassport ? null : (passport ?? this.passport),
      saudiVisa: clearSaudiVisa ? null : (saudiVisa ?? this.saudiVisa),
      bahrainVisa: clearBahrainVisa ? null : (bahrainVisa ?? this.bahrainVisa),
      dubaiVisa: clearDubaiVisa ? null : (dubaiVisa ?? this.dubaiVisa),
      qatarVisa: clearQatarVisa ? null : (qatarVisa ?? this.qatarVisa),
      authorization: clearAuthorization ? null : (authorization ?? this.authorization),
      contacts: contacts ?? this.contacts,
    );
  }

}
