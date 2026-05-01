import 'package:equatable/equatable.dart';

class VaultDocument extends Equatable {
  final String url;
  final String name;

  const VaultDocument({
    required this.url,
    required this.name,
  });

  @override
  List<Object?> get props => [url, name];

  Map<String, dynamic> toJson() => {
        'url': url,
        'name': name,
      };

  factory VaultDocument.fromJson(Map<String, dynamic> json) => VaultDocument(
        url: json['url'] as String,
        name: json['name'] as String,
      );
}

class VaultData extends Equatable {
  final CommercialLicense license;
  final VatCertificate vatCertificate;

  const VaultData({required this.license, required this.vatCertificate});

  @override
  List<Object?> get props => [license, vatCertificate];

  VaultData copyWith({
    CommercialLicense? license,
    VatCertificate? vatCertificate,
  }) {
    return VaultData(
      license: license ?? this.license,
      vatCertificate: vatCertificate ?? this.vatCertificate,
    );
  }
}

class CommercialLicense extends Equatable {
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final String registrationNo;
  final VaultDocument? document;
  final int alertDays;

  const CommercialLicense({
    this.issueDate,
    this.expiryDate,
    this.registrationNo = '',
    this.document,
    this.alertDays = 30,
  });

  @override
  List<Object?> get props =>
      [issueDate, expiryDate, registrationNo, document, alertDays];

  CommercialLicense copyWith({
    DateTime? issueDate,
    DateTime? expiryDate,
    String? registrationNo,
    VaultDocument? document,
    int? alertDays,
  }) {
    return CommercialLicense(
      issueDate: issueDate ?? this.issueDate,
      expiryDate: expiryDate ?? this.expiryDate,
      registrationNo: registrationNo ?? this.registrationNo,
      document: document ?? this.document,
      alertDays: alertDays ?? this.alertDays,
    );
  }
}

class VatCertificate extends Equatable {
  final DateTime? issueDate;
  final String vatAccountNo;
  final VaultDocument? document;
  final int alertDays;

  const VatCertificate({
    this.issueDate,
    this.vatAccountNo = '',
    this.document,
    this.alertDays = 30,
  });

  @override
  List<Object?> get props => [issueDate, vatAccountNo, document, alertDays];

  VatCertificate copyWith({
    DateTime? issueDate,
    String? vatAccountNo,
    VaultDocument? document,
    int? alertDays,
  }) {
    return VatCertificate(
      issueDate: issueDate ?? this.issueDate,
      vatAccountNo: vatAccountNo ?? this.vatAccountNo,
      document: document ?? this.document,
      alertDays: alertDays ?? this.alertDays,
    );
  }
}

class VatFiling extends Equatable {
  final String id;
  final DateTime date;
  final double amount;
  final String currency;
  final String billNumber;
  final DateTime fromDate;
  final DateTime toDate;
  final List<VaultDocument> documents;

  const VatFiling({
    required this.id,
    required this.date,
    required this.amount,
    this.currency = 'SAR',
    this.billNumber = '',
    required this.fromDate,
    required this.toDate,
    required this.documents,
  });

  @override
  List<Object?> get props =>
      [id, date, amount, currency, billNumber, fromDate, toDate, documents];
}

