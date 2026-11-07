import '../../domain/entities/document_renewal_entity.dart';

/// Stored at `employees/{employeeId}/document_renewals/{id}`.
class DocumentRenewalModel extends DocumentRenewalEntity {
  const DocumentRenewalModel({
    required super.id,
    required super.employeeId,
    required super.documentType,
    super.previousNumber,
    super.newNumber,
    required super.previousExpiryDate,
    required super.newExpiryDate,
    super.previousAttachmentUrl,
    super.newAttachmentUrl,
    required super.renewedAt,
    super.renewedBy,
    super.source,
    super.voided,
  });

  factory DocumentRenewalModel.fromEntity(DocumentRenewalEntity e) {
    return DocumentRenewalModel(
      id: e.id,
      employeeId: e.employeeId,
      documentType: e.documentType,
      previousNumber: e.previousNumber,
      newNumber: e.newNumber,
      previousExpiryDate: e.previousExpiryDate,
      newExpiryDate: e.newExpiryDate,
      previousAttachmentUrl: e.previousAttachmentUrl,
      newAttachmentUrl: e.newAttachmentUrl,
      renewedAt: e.renewedAt,
      renewedBy: e.renewedBy,
      source: e.source,
      voided: e.voided,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'documentType': documentType,
      'previousNumber': previousNumber,
      'newNumber': newNumber,
      'previousExpiryDate': previousExpiryDate.toIso8601String(),
      'newExpiryDate': newExpiryDate.toIso8601String(),
      'previousAttachmentUrl': previousAttachmentUrl,
      'newAttachmentUrl': newAttachmentUrl,
      'renewedAt': renewedAt.toIso8601String(),
      'renewedBy': renewedBy,
      'source': source,
      'voided': voided,
    };
  }

  factory DocumentRenewalModel.fromJson(Map<String, dynamic> json) {
    return DocumentRenewalModel(
      id: json['id'] as String,
      employeeId: json['employeeId'] as String,
      documentType: json['documentType'] as String,
      previousNumber: json['previousNumber'] as String?,
      newNumber: json['newNumber'] as String?,
      previousExpiryDate: DateTime.parse(json['previousExpiryDate'] as String),
      newExpiryDate: DateTime.parse(json['newExpiryDate'] as String),
      previousAttachmentUrl: json['previousAttachmentUrl'] as String?,
      newAttachmentUrl: json['newAttachmentUrl'] as String?,
      renewedAt: DateTime.parse(json['renewedAt'] as String),
      renewedBy: json['renewedBy'] as String?,
      source: json['source'] as String?,
      voided: json['voided'] as bool? ?? false,
    );
  }
}
