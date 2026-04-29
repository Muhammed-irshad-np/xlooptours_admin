import 'package:equatable/equatable.dart';

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
  final String? documentUrl;
  final int alertDays;

  const CommercialLicense({
    this.issueDate,
    this.expiryDate,
    this.registrationNo = '',
    this.documentUrl,
    this.alertDays = 30,
  });

  @override
  List<Object?> get props => [issueDate, expiryDate, registrationNo, documentUrl, alertDays];

  CommercialLicense copyWith({
    DateTime? issueDate,
    DateTime? expiryDate,
    String? registrationNo,
    String? documentUrl,
    int? alertDays,
  }) {
    return CommercialLicense(
      issueDate: issueDate ?? this.issueDate,
      expiryDate: expiryDate ?? this.expiryDate,
      registrationNo: registrationNo ?? this.registrationNo,
      documentUrl: documentUrl ?? this.documentUrl,
      alertDays: alertDays ?? this.alertDays,
    );
  }
}

class VatCertificate extends Equatable {
  final DateTime? issueDate;
  final String vatAccountNo;
  final String? documentUrl;
  final int alertDays;

  const VatCertificate({
    this.issueDate,
    this.vatAccountNo = '',
    this.documentUrl,
    this.alertDays = 30,
  });

  @override
  List<Object?> get props => [issueDate, vatAccountNo, documentUrl, alertDays];

  VatCertificate copyWith({
    DateTime? issueDate,
    String? vatAccountNo,
    String? documentUrl,
    int? alertDays,
  }) {
    return VatCertificate(
      issueDate: issueDate ?? this.issueDate,
      vatAccountNo: vatAccountNo ?? this.vatAccountNo,
      documentUrl: documentUrl ?? this.documentUrl,
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
  final List<String> documentUrls;

  const VatFiling({
    required this.id,
    required this.date,
    required this.amount,
    this.currency = 'SAR',
    this.billNumber = '',
    required this.fromDate,
    required this.toDate,
    required this.documentUrls,
  });

  @override
  List<Object?> get props => [id, date, amount, currency, billNumber, fromDate, toDate, documentUrls];
}
