import 'package:equatable/equatable.dart';

class CompanyEntity extends Equatable {
  final String id;
  final String companyName;
  final String? email;
  final String? country;
  final bool vatRegisteredInKSA;
  final String? taxRegistrationNumber;
  final String? city;
  final String? streetAddress;
  final String? buildingNumber;
  final String? district;
  final String? addressAdditionalNumber;
  final String? postalCode;

  // New Case Code Logic
  final bool usesCaseCode;
  final String? caseCodeLabel;
  final List<String> caseCodes;
  final String status;
  final DateTime createdAt;

  const CompanyEntity({
    required this.id,
    required this.companyName,
    this.email,
    this.country,
    this.vatRegisteredInKSA = false,
    this.taxRegistrationNumber,
    this.city,
    this.streetAddress,
    this.buildingNumber,
    this.district,
    this.addressAdditionalNumber,
    this.postalCode,
    this.usesCaseCode = false,
    this.caseCodeLabel,
    this.caseCodes = const [],
    this.status = 'ACTIVE',
    required this.createdAt,
  });

  CompanyEntity copyWith({
    String? id,
    String? companyName,
    String? email,
    String? country,
    bool? vatRegisteredInKSA,
    String? taxRegistrationNumber,
    String? city,
    String? streetAddress,
    String? buildingNumber,
    String? district,
    String? addressAdditionalNumber,
    String? postalCode,
    bool? usesCaseCode,
    String? caseCodeLabel,
    List<String>? caseCodes,
    String? status,
    DateTime? createdAt,
  }) {
    return CompanyEntity(
      id: id ?? this.id,
      companyName: companyName ?? this.companyName,
      email: email ?? this.email,
      country: country ?? this.country,
      vatRegisteredInKSA: vatRegisteredInKSA ?? this.vatRegisteredInKSA,
      taxRegistrationNumber:
          taxRegistrationNumber ?? this.taxRegistrationNumber,
      city: city ?? this.city,
      streetAddress: streetAddress ?? this.streetAddress,
      buildingNumber: buildingNumber ?? this.buildingNumber,
      district: district ?? this.district,
      addressAdditionalNumber:
          addressAdditionalNumber ?? this.addressAdditionalNumber,
      postalCode: postalCode ?? this.postalCode,
      usesCaseCode: usesCaseCode ?? this.usesCaseCode,
      caseCodeLabel: caseCodeLabel ?? this.caseCodeLabel,
      caseCodes: caseCodes ?? this.caseCodes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    companyName,
    email,
    country,
    vatRegisteredInKSA,
    taxRegistrationNumber,
    city,
    streetAddress,
    buildingNumber,
    district,
    addressAdditionalNumber,
    postalCode,
    usesCaseCode,
    caseCodeLabel,
    caseCodes,
    status,
    createdAt,
  ];
}
