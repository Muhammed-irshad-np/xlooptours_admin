import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:xloop_invoice/features/driver_evaluation/domain/entities/evaluation_entity.dart';

class EvaluationModel extends EvaluationEntity {
  const EvaluationModel({
    required super.id,
    required super.driverId,
    required super.driverName,
    super.vehicleId,
    required super.status,
    required super.createdAt,
    super.submittedAt,
    super.evaluatedAt,
    required super.media,
    super.scores,
  });

  factory EvaluationModel.fromJson(Map<String, dynamic> json, String documentId) {
    return EvaluationModel(
      id: documentId,
      driverId: json['driverId'] as String,
      driverName: json['driverName'] as String,
      vehicleId: json['vehicleId'] as String?,
      status: json['status'] as String,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      submittedAt: json['submittedAt'] != null ? (json['submittedAt'] as Timestamp).toDate() : null,
      evaluatedAt: json['evaluatedAt'] != null ? (json['evaluatedAt'] as Timestamp).toDate() : null,
      media: json['media'] != null ? Map<String, dynamic>.from(json['media'] as Map) : {},
      scores: json['scores'] != null ? Map<String, dynamic>.from(json['scores'] as Map) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'driverId': driverId,
      'driverName': driverName,
      'vehicleId': vehicleId,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'submittedAt': submittedAt != null ? Timestamp.fromDate(submittedAt!) : null,
      'evaluatedAt': evaluatedAt != null ? Timestamp.fromDate(evaluatedAt!) : null,
      'media': media,
      'scores': scores,
    };
  }
}
