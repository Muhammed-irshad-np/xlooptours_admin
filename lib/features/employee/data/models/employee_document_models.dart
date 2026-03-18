import '../../domain/entities/employee_documents.dart';

class IqamaModel extends IqamaDocument {
  const IqamaModel({
    required super.number,
    required super.expiryDate,
    super.insuranceExpiryDate,
    super.attachmentUrl,
    super.notificationDays,
  });

  factory IqamaModel.fromJson(Map<String, dynamic> json) {
    return IqamaModel(
      number: json['number'] as String? ?? '',
      expiryDate: DateTime.parse(json['expiryDate'] as String),
      insuranceExpiryDate: json['insuranceExpiryDate'] != null
          ? DateTime.parse(json['insuranceExpiryDate'] as String)
          : null,
      attachmentUrl: json['attachmentUrl'] as String?,
      notificationDays: json['notificationDays'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'expiryDate': expiryDate.toIso8601String(),
      if (insuranceExpiryDate != null)
        'insuranceExpiryDate': insuranceExpiryDate!.toIso8601String(),
      if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
      if (notificationDays != null) 'notificationDays': notificationDays,
    };
  }
}

class BahrainResidenceModel extends BahrainResidenceDocument {
  const BahrainResidenceModel({
    required super.number,
    required super.expiryDate,
    super.insuranceExpiryDate,
    super.attachmentUrl,
    super.notificationDays,
  });

  factory BahrainResidenceModel.fromJson(Map<String, dynamic> json) {
    return BahrainResidenceModel(
      number: json['number'] as String? ?? '',
      expiryDate: DateTime.parse(json['expiryDate'] as String),
      insuranceExpiryDate: json['insuranceExpiryDate'] != null
          ? DateTime.parse(json['insuranceExpiryDate'] as String)
          : null,
      attachmentUrl: json['attachmentUrl'] as String?,
      notificationDays: json['notificationDays'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'expiryDate': expiryDate.toIso8601String(),
      if (insuranceExpiryDate != null)
        'insuranceExpiryDate': insuranceExpiryDate!.toIso8601String(),
      if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
      if (notificationDays != null) 'notificationDays': notificationDays,
    };
  }
}

class DrivingLicenseModel extends DrivingLicenseDocument {
  const DrivingLicenseModel({
    required super.countryOfOrigin,
    required super.number,
    required super.expiryDate,
    required super.type,
    super.attachmentUrl,
    super.notificationDays,
  });

  factory DrivingLicenseModel.fromJson(Map<String, dynamic> json) {
    return DrivingLicenseModel(
      countryOfOrigin: json['countryOfOrigin'] as String? ?? '',
      number: json['number'] as String? ?? '',
      expiryDate: DateTime.parse(json['expiryDate'] as String),
      type: DrivingLicenseType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => DrivingLicenseType.private,
      ),
      attachmentUrl: json['attachmentUrl'] as String?,
      notificationDays: json['notificationDays'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'countryOfOrigin': countryOfOrigin,
      'number': number,
      'expiryDate': expiryDate.toIso8601String(),
      'type': type.name,
      if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
      if (notificationDays != null) 'notificationDays': notificationDays,
    };
  }
}

class PassportModel extends PassportDocument {
  const PassportModel({
    required super.nameOnPassport,
    required super.number,
    required super.expiryDate,
    super.attachmentUrl,
    super.notificationDays,
  });

  factory PassportModel.fromJson(Map<String, dynamic> json) {
    return PassportModel(
      nameOnPassport: json['nameOnPassport'] as String? ?? '',
      number: json['number'] as String? ?? '',
      expiryDate: DateTime.parse(json['expiryDate'] as String),
      attachmentUrl: json['attachmentUrl'] as String?,
      notificationDays: json['notificationDays'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nameOnPassport': nameOnPassport,
      'number': number,
      'expiryDate': expiryDate.toIso8601String(),
      if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
      if (notificationDays != null) 'notificationDays': notificationDays,
    };
  }
}

class VisaModel extends VisaDocument {
  const VisaModel({
    required super.number,
    required super.expiryDate,
    super.type,
    super.attachmentUrl,
    super.notificationDays,
  });

  factory VisaModel.fromJson(Map<String, dynamic> json) {
    return VisaModel(
      number: json['number'] as String? ?? '',
      expiryDate: DateTime.parse(json['expiryDate'] as String),
      type: json['type'] != null
          ? VisaType.values.firstWhere(
              (e) => e.name == json['type'],
              orElse: () => VisaType.singleEntry,
            )
          : null,
      attachmentUrl: json['attachmentUrl'] as String?,
      notificationDays: json['notificationDays'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'expiryDate': expiryDate.toIso8601String(),
      if (type != null) 'type': type!.name,
      if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
      if (notificationDays != null) 'notificationDays': notificationDays,
    };
  }
}

class AuthorizationModel extends AuthorizationDocument {
  const AuthorizationModel({
    required super.expiryDate,
    super.attachmentUrl,
    super.notificationDays,
  });

  factory AuthorizationModel.fromJson(Map<String, dynamic> json) {
    return AuthorizationModel(
      expiryDate: DateTime.parse(json['expiryDate'] as String),
      attachmentUrl: json['attachmentUrl'] as String?,
      notificationDays: json['notificationDays'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'expiryDate': expiryDate.toIso8601String(),
      if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
      if (notificationDays != null) 'notificationDays': notificationDays,
    };
  }
}
