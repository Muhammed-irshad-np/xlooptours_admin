import 'package:equatable/equatable.dart';

class FeedbackEntity extends Equatable {
  final String id;
  final DateTime dateOfTrip;
  final String driverName;
  final String caseCode;
  final int safetyRating;
  final int professionalismRating;
  final int communicationRating;
  final int punctualityRating;
  final int vehicleConditionRating;
  final String? areasOfExcellence;
  final String? areasOfImprovement;
  final bool incidentReported;
  final String? incidentDescription;
  final String clientName;
  final String? submitterName;
  final DateTime createdAt;

  const FeedbackEntity({
    required this.id,
    required this.dateOfTrip,
    required this.driverName,
    required this.caseCode,
    required this.safetyRating,
    required this.professionalismRating,
    required this.communicationRating,
    required this.punctualityRating,
    required this.vehicleConditionRating,
    this.areasOfExcellence,
    this.areasOfImprovement,
    required this.incidentReported,
    this.incidentDescription,
    required this.clientName,
    this.submitterName,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        dateOfTrip,
        driverName,
        caseCode,
        safetyRating,
        professionalismRating,
        communicationRating,
        punctualityRating,
        vehicleConditionRating,
        areasOfExcellence,
        areasOfImprovement,
        incidentReported,
        incidentDescription,
        clientName,
        submitterName,
        createdAt,
      ];
}
