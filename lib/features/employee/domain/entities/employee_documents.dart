import 'package:equatable/equatable.dart';

class IqamaDocument extends Equatable {
  final String number;
  final DateTime expiryDate;
  final DateTime? insuranceExpiryDate;
  final String? attachmentUrl;

  const IqamaDocument({
    required this.number,
    required this.expiryDate,
    this.insuranceExpiryDate,
    this.attachmentUrl,
  });

  @override
  List<Object?> get props => [
    number,
    expiryDate,
    insuranceExpiryDate,
    attachmentUrl,
  ];
}

enum DrivingLicenseType { private, heavy }

class DrivingLicenseDocument extends Equatable {
  final String countryOfOrigin;
  final String number;
  final DateTime expiryDate;
  final DrivingLicenseType type;
  final String? attachmentUrl;

  const DrivingLicenseDocument({
    required this.countryOfOrigin,
    required this.number,
    required this.expiryDate,
    required this.type,
    this.attachmentUrl,
  });

  @override
  List<Object?> get props => [
    countryOfOrigin,
    number,
    expiryDate,
    type,
    attachmentUrl,
  ];
}

class PassportDocument extends Equatable {
  final String nameOnPassport;
  final String number;
  final DateTime expiryDate;
  final String? attachmentUrl;

  const PassportDocument({
    required this.nameOnPassport,
    required this.number,
    required this.expiryDate,
    this.attachmentUrl,
  });

  @override
  List<Object?> get props => [
    nameOnPassport,
    number,
    expiryDate,
    attachmentUrl,
  ];
}

enum VisaType { singleEntry, multipleEntry }

class VisaDocument extends Equatable {
  final String number;
  final DateTime expiryDate;
  final VisaType? type;
  final String? attachmentUrl;

  const VisaDocument({
    required this.number,
    required this.expiryDate,
    this.type,
    this.attachmentUrl,
  });

  @override
  List<Object?> get props => [number, expiryDate, type, attachmentUrl];
}

class AuthorizationDocument extends Equatable {
  final DateTime expiryDate;
  final String? attachmentUrl;

  const AuthorizationDocument({required this.expiryDate, this.attachmentUrl});

  @override
  List<Object?> get props => [expiryDate, attachmentUrl];
}
