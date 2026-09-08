import 'package:equatable/equatable.dart';
import 'employee_contact.dart';
import 'employee_documents.dart';
import 'external_vehicle_info.dart';

/// Employment types. Internal = on the company payroll, External = contracted
/// third party (freelance driver, agency staff) for whom we keep a minimal
/// record only.
class EmploymentType {
  static const String internal = 'Internal';
  static const String external = 'External';

  static const List<String> values = [internal, external];

  const EmploymentType._();
}

class EmployeeEntity extends Equatable {
  final String id;
  final String fullName;
  final String position;
  final String email;
  final String phoneNumber;
  final String? countryCode;
  final String nationality;
  final String idType;
  final String idNumber;
  final DateTime? joinDate;
  final DateTime? birthDate;
  final String gender;

  /// [EmploymentType.internal] or [EmploymentType.external]. Applies to every
  /// position, not just drivers.
  final String employmentType;

  /// Car details for an external driver. Always null for internal staff, who
  /// drive fleet vehicles tracked separately.
  final ExternalVehicleInfo? externalVehicle;
  final bool isActive;
  final String? imageUrl;
  final String? assignedVehicleId;
  final IqamaDocument? iqama;
  final BahrainResidenceDocument? bahrainResidence;
  final HealthInsuranceDocument? healthInsurance;
  final DrivingLicenseDocument? drivingLicense;
  final PassportDocument? passport;
  final VisaDocument? saudiVisa;
  final VisaDocument? bahrainVisa;
  final VisaDocument? dubaiVisa;
  final VisaDocument? qatarVisa;
  final AuthorizationDocument? authorization;
  final List<EmployeeContact> contacts;

  const EmployeeEntity({
    required this.id,
    required this.fullName,
    required this.position,
    required this.email,
    required this.phoneNumber,
    this.countryCode,
    required this.nationality,
    required this.idType,
    required this.idNumber,
    this.joinDate,
    this.birthDate,
    required this.gender,
    this.employmentType = EmploymentType.internal,
    this.externalVehicle,
    this.isActive = true,
    this.imageUrl,
    this.assignedVehicleId,
    this.iqama,
    this.bahrainResidence,
    this.healthInsurance,
    this.drivingLicense,
    this.passport,
    this.saudiVisa,
    this.bahrainVisa,
    this.dubaiVisa,
    this.qatarVisa,
    this.authorization,
    this.contacts = const [],
  });

  /// True when this person is a driver, whatever their exact position label
  /// ('Driver', 'External Driver', 'Senior Driver', …).
  bool get isDriver => position.toLowerCase().contains('driver');

  bool get isExternal => employmentType == EmploymentType.external;

  bool get isInternal => !isExternal;

  bool get isExternalDriver => isDriver && isExternal;

  /// External staff are contracted third parties: no company documents, no
  /// fleet authorisation, no app login and no company money custody.
  bool get canHoldCompanyRecords => isInternal;

  factory EmployeeEntity.empty() {
    return const EmployeeEntity(
      id: '',
      fullName: '',
      position: '',
      email: '',
      phoneNumber: '',
      nationality: '',
      idType: '',
      idNumber: '',
      gender: '',
    );
  }

  EmployeeEntity copyWith({
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
    String? employmentType,
    ExternalVehicleInfo? externalVehicle,
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
    bool clearExternalVehicle = false,
  }) {
    return EmployeeEntity(
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
      employmentType: employmentType ?? this.employmentType,
      externalVehicle: clearExternalVehicle
          ? null
          : (externalVehicle ?? this.externalVehicle),
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

  @override
  List<Object?> get props => [
    id,
    fullName,
    position,
    email,
    phoneNumber,
    countryCode,
    nationality,
    idType,
    idNumber,
    joinDate,
    birthDate,
    gender,
    employmentType,
    externalVehicle,
    isActive,
    imageUrl,
    assignedVehicleId,
    iqama,
    bahrainResidence,
    healthInsurance,
    drivingLicense,
    passport,
    saudiVisa,
    bahrainVisa,
    dubaiVisa,
    qatarVisa,
    authorization,
    contacts,
  ];
}
