import '../../domain/entities/feedback_entity.dart';

class FeedbackModel extends FeedbackEntity {
  const FeedbackModel({
    required super.id,
    required super.dateOfTrip,
    required super.driverName,
    required super.safetyRating,
    required super.professionalismRating,
    required super.communicationRating,
    required super.punctualityRating,
    required super.vehicleConditionRating,
    super.areasOfExcellence,
    super.areasOfImprovement,
    required super.incidentReported,
    super.incidentDescription,
    required super.clientName,
    super.submitterName,
    required super.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dateOfTrip': dateOfTrip.toIso8601String(),
      'driverName': driverName,
      'safetyRating': safetyRating,
      'professionalismRating': professionalismRating,
      'communicationRating': communicationRating,
      'punctualityRating': punctualityRating,
      'vehicleConditionRating': vehicleConditionRating,
      'areasOfExcellence': areasOfExcellence,
      'areasOfImprovement': areasOfImprovement,
      'incidentReported': incidentReported,
      'incidentDescription': incidentDescription,
      'clientName': clientName,
      'submitterName': submitterName,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory FeedbackModel.fromJson(Map<String, dynamic> json) {
    return FeedbackModel(
      id: json['id'] as String,
      dateOfTrip: DateTime.parse(json['dateOfTrip'] as String),
      driverName: json['driverName'] as String,
      safetyRating: json['safetyRating'] as int,
      professionalismRating: json['professionalismRating'] as int,
      communicationRating: json['communicationRating'] as int,
      punctualityRating: json['punctualityRating'] as int,
      vehicleConditionRating: json['vehicleConditionRating'] as int,
      areasOfExcellence: json['areasOfExcellence'] as String?,
      areasOfImprovement: json['areasOfImprovement'] as String?,
      incidentReported: json['incidentReported'] as bool,
      incidentDescription: json['incidentDescription'] as String?,
      clientName: json['clientName'] as String,
      submitterName: json['submitterName'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  factory FeedbackModel.fromEntity(FeedbackEntity entity) {
    return FeedbackModel(
      id: entity.id,
      dateOfTrip: entity.dateOfTrip,
      driverName: entity.driverName,
      safetyRating: entity.safetyRating,
      professionalismRating: entity.professionalismRating,
      communicationRating: entity.communicationRating,
      punctualityRating: entity.punctualityRating,
      vehicleConditionRating: entity.vehicleConditionRating,
      areasOfExcellence: entity.areasOfExcellence,
      areasOfImprovement: entity.areasOfImprovement,
      incidentReported: entity.incidentReported,
      incidentDescription: entity.incidentDescription,
      clientName: entity.clientName,
      submitterName: entity.submitterName,
      createdAt: entity.createdAt,
    );
  }
}
