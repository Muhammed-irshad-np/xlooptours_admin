import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/vault_data.dart';

class VaultDocumentModel extends VaultDocument {
  const VaultDocumentModel({
    required super.url,
    required super.name,
  });

  factory VaultDocumentModel.fromJson(dynamic json) {
    if (json is String) {
      return VaultDocumentModel(url: json, name: 'Document');
    }
    return VaultDocumentModel(
      url: json['url'] ?? '',
      name: json['name'] ?? 'Document',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'name': name,
    };
  }
}

class VaultDataModel extends VaultData {
  const VaultDataModel({
    required CommercialLicenseModel license,
    required VatCertificateModel vatCertificate,
  }) : super(license: license, vatCertificate: vatCertificate);

  factory VaultDataModel.fromJson(Map<String, dynamic> json) {
    return VaultDataModel(
      license: CommercialLicenseModel.fromJson(json['license'] ?? {}),
      vatCertificate:
          VatCertificateModel.fromJson(json['vatCertificate'] ?? {}),
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
    VaultDocumentModel? super.document,
    super.alertDays,
  });

  factory CommercialLicenseModel.fromJson(Map<String, dynamic> json) {
    return CommercialLicenseModel(
      issueDate: json['issueDate'] != null
          ? (json['issueDate'] as Timestamp).toDate()
          : null,
      expiryDate: json['expiryDate'] != null
          ? (json['expiryDate'] as Timestamp).toDate()
          : null,
      registrationNo: json['registrationNo'] ?? '',
      document: json['document'] != null
          ? VaultDocumentModel.fromJson(json['document'])
          : (json['documentUrl'] != null
              ? VaultDocumentModel.fromJson(json['documentUrl'])
              : null),
      alertDays: json['alertDays'] ?? 30,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'issueDate': issueDate != null ? Timestamp.fromDate(issueDate!) : null,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'registrationNo': registrationNo,
      'document': (document as VaultDocumentModel?)?.toJson(),
      'alertDays': alertDays,
    };
  }
}

class VatCertificateModel extends VatCertificate {
  const VatCertificateModel({
    super.issueDate,
    super.vatAccountNo,
    VaultDocumentModel? super.document,
    super.alertDays,
  });

  factory VatCertificateModel.fromJson(Map<String, dynamic> json) {
    return VatCertificateModel(
      issueDate: json['issueDate'] != null
          ? (json['issueDate'] as Timestamp).toDate()
          : null,
      vatAccountNo: json['vatAccountNo'] ?? '',
      document: json['document'] != null
          ? VaultDocumentModel.fromJson(json['document'])
          : (json['documentUrl'] != null
              ? VaultDocumentModel.fromJson(json['documentUrl'])
              : null),
      alertDays: json['alertDays'] ?? 30,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'issueDate': issueDate != null ? Timestamp.fromDate(issueDate!) : null,
      'vatAccountNo': vatAccountNo,
      'document': (document as VaultDocumentModel?)?.toJson(),
      'alertDays': alertDays,
    };
  }
}

class VatFilingModel extends VatFiling {
  const VatFilingModel({
    required super.id,
    required super.date,
    required super.amount,
    super.currency,
    super.billNumber,
    required super.fromDate,
    required super.toDate,
    required List<VaultDocumentModel> super.documents,
  });

  factory VatFilingModel.fromJson(Map<String, dynamic> json, String id) {
    return VatFilingModel(
      id: id,
      date: (json['date'] as Timestamp).toDate(),
      amount: (json['amount'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'SAR',
      billNumber: json['billNumber'] ?? '',
      fromDate: (json['fromDate'] as Timestamp).toDate(),
      toDate: (json['toDate'] as Timestamp).toDate(),
      documents: (json['documents'] as List? ??
              json['documentUrls'] as List? ??
              [])
          .map((d) => VaultDocumentModel.fromJson(d))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': Timestamp.fromDate(date),
      'amount': amount,
      'currency': currency,
      'billNumber': billNumber,
      'fromDate': Timestamp.fromDate(fromDate),
      'toDate': Timestamp.fromDate(toDate),
      'documents': documents.map((d) => (d as VaultDocumentModel).toJson()).toList(),
    };
  }
}

