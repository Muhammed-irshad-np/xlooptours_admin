import 'package:equatable/equatable.dart';

class VaultData extends Equatable {
  final CommercialLicense license;
  final VatCertificate vatCertificate;

  const VaultData({required this.license, required this.vatCertificate});

  @override
  List<Object?> get props => [license, vatCertificate];
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
}

class VatCertificate extends Equatable {
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final String vatAccountNo;
  final int alertDays;

  const VatCertificate({
    this.issueDate,
    this.expiryDate,
    this.vatAccountNo = '',
    this.alertDays = 30,
  });

  @override
  List<Object?> get props => [issueDate, expiryDate, vatAccountNo, alertDays];
}

class VatFiling extends Equatable {
  final String id;
  final DateTime date;
  final double amount;
  final DateTime fromDate;
  final DateTime toDate;
  final List<String> documentUrls;

  const VatFiling({
    required this.id,
    required this.date,
    required this.amount,
    required this.fromDate,
    required this.toDate,
    required this.documentUrls,
  });

  @override
  List<Object?> get props => [id, date, amount, fromDate, toDate, documentUrls];
}
