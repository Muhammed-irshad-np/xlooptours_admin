import 'package:equatable/equatable.dart';

class EvaluationEntity extends Equatable {
  final String id;
  final String driverId;
  final String driverName;
  final String? vehicleId;
  final String status; // 'pending', 'evaluated'
  final DateTime createdAt;
  final DateTime? submittedAt;
  final DateTime? evaluatedAt;
  final Map<String, dynamic> media; // e.g., {'full_body': {'url': '...', 'timestamp': '...'}, ...}
  final Map<String, dynamic>? scores; // e.g., {'appearance': 4, 'vehicle': 5, 'remarks': '...', 'passed': true}

  const EvaluationEntity({
    required this.id,
    required this.driverId,
    required this.driverName,
    this.vehicleId,
    required this.status,
    required this.createdAt,
    this.submittedAt,
    this.evaluatedAt,
    required this.media,
    this.scores,
  });

  @override
  List<Object?> get props => [
        id,
        driverId,
        driverName,
        vehicleId,
        status,
        createdAt,
        submittedAt,
        evaluatedAt,
        media,
        scores,
      ];
}
