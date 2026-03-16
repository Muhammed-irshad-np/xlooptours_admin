import 'package:equatable/equatable.dart';

class IqamaDocument extends Equatable {
  final String number;
  final DateTime expiryDate;
  final DateTime? insuranceExpiryDate;
  final String? attachmentUrl;
  final int? notificationDays;

  const IqamaDocument({
    required this.number,
    required this.expiryDate,
    this.insuranceExpiryDate,
    this.attachmentUrl,
    this.notificationDays,
  });

  @override
  List<Object?> get props => [
    number,
    expiryDate,
    insuranceExpiryDate,
    attachmentUrl,
    notificationDays,
  ];
}

enum DrivingLicenseType { private, heavy }

class DrivingLicenseDocument extends Equatable {
  final String countryOfOrigin;
  final String number;
  final DateTime expiryDate;
  final DrivingLicenseType type;
  final String? attachmentUrl;
  final int? notificationDays;

  const DrivingLicenseDocument({
    required this.countryOfOrigin,
    required this.number,
    required this.expiryDate,
    required this.type,
    this.attachmentUrl,
    this.notificationDays,
  });

  @override
  List<Object?> get props => [
    countryOfOrigin,
    number,
    expiryDate,
    type,
    attachmentUrl,
    notificationDays,
  ];
}

class PassportDocument extends Equatable {
  final String nameOnPassport;
  final String number;
  final DateTime expiryDate;
  final String? attachmentUrl;
  final int? notificationDays;

  const PassportDocument({
    required this.nameOnPassport,
    required this.number,
    required this.expiryDate,
    this.attachmentUrl,
    this.notificationDays,
  });

  @override
  List<Object?> get props => [
    nameOnPassport,
    number,
    expiryDate,
    attachmentUrl,
    notificationDays,
  ];
}

enum VisaType { singleEntry, multipleEntry }

class VisaDocument extends Equatable {
  final String number;
  final DateTime expiryDate;
  final VisaType? type;
  final String? attachmentUrl;
  final int? notificationDays;

  const VisaDocument({
    required this.number,
    required this.expiryDate,
    this.type,
    this.attachmentUrl,
    this.notificationDays,
  });

  @override
  List<Object?> get props => [
    number,
    expiryDate,
    type,
    attachmentUrl,
    notificationDays,
  ];
}

class AuthorizationDocument extends Equatable {
  final DateTime expiryDate;
  final String? attachmentUrl;
  final int? notificationDays;

  const AuthorizationDocument({
    required this.expiryDate,
    this.attachmentUrl,
    this.notificationDays,
  });

  @override
  List<Object?> get props => [expiryDate, attachmentUrl, notificationDays];
}
