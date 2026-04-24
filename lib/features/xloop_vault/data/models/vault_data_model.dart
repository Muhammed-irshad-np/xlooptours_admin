import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/vault_data.dart';

class VaultDataModel extends VaultData {
  const VaultDataModel({
    required CommercialLicenseModel license,
    required VatCertificateModel vatCertificate,
  }) : super(license: license, vatCertificate: vatCertificate);

  factory VaultDataModel.fromJson(Map<String, dynamic> json) {
    return VaultDataModel(
      license: CommercialLicenseModel.fromJson(json['license'] ?? {}),
      vatCertificate: VatCertificateModel.fromJson(json['vatCertificate'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'license': (license as CommercialLicenseModel).toJson(),
      'vatCertificate': (vatCertificate as VatCertificateModel).toJson(),
    };
  }
}

class CommercialLicenseModel extends CommercialLicense {
  const CommercialLicenseModel({
    super.issueDate,
    super.expiryDate,
    super.registrationNo,
    super.documentUrl,
    super.alertDays,
  });

  factory CommercialLicenseModel.fromJson(Map<String, dynamic> json) {
    return CommercialLicenseModel(
      issueDate: json['issueDate'] != null ? (json['issueDate'] as Timestamp).toDate() : null,
      expiryDate: json['expiryDate'] != null ? (json['expiryDate'] as Timestamp).toDate() : null,
      registrationNo: json['registrationNo'] ?? '',
      documentUrl: json['documentUrl'],
      alertDays: json['alertDays'] ?? 30,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'issueDate': issueDate != null ? Timestamp.fromDate(issueDate!) : null,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'registrationNo': registrationNo,
      'documentUrl': documentUrl,
      'alertDays': alertDays,
    };
  }
}

class VatCertificateModel extends VatCertificate {
  const VatCertificateModel({
    super.issueDate,
    super.expiryDate,
    super.vatAccountNo,
    super.alertDays,
  });

  factory VatCertificateModel.fromJson(Map<String, dynamic> json) {
    return VatCertificateModel(
      issueDate: json['issueDate'] != null ? (json['issueDate'] as Timestamp).toDate() : null,
      expiryDate: json['expiryDate'] != null ? (json['expiryDate'] as Timestamp).toDate() : null,
      vatAccountNo: json['vatAccountNo'] ?? '',
      alertDays: json['alertDays'] ?? 30,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'issueDate': issueDate != null ? Timestamp.fromDate(issueDate!) : null,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'vatAccountNo': vatAccountNo,
      'alertDays': alertDays,
    };
  }
}

class VatFilingModel extends VatFiling {
  const VatFilingModel({
    required super.id,
    required super.date,
    required super.amount,
    required super.fromDate,
    required super.toDate,
    required super.documentUrls,
  });

  factory VatFilingModel.fromJson(Map<String, dynamic> json, String id) {
    return VatFilingModel(
      id: id,
      date: (json['date'] as Timestamp).toDate(),
      amount: (json['amount'] ?? 0).toDouble(),
      fromDate: (json['fromDate'] as Timestamp).toDate(),
      toDate: (json['toDate'] as Timestamp).toDate(),
      documentUrls: List<String>.from(json['documentUrls'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': Timestamp.fromDate(date),
      'amount': amount,
      'fromDate': Timestamp.fromDate(fromDate),
      'toDate': Timestamp.fromDate(toDate),
      'documentUrls': documentUrls,
    };
  }
}
