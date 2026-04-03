import 'package:equatable/equatable.dart';

class MaintenanceTypeEntity extends Equatable {
  final String id;
  final String name;
  final int defaultIntervalKm;

  const MaintenanceTypeEntity({
    required this.id,
    required this.name,
    required this.defaultIntervalKm,
  });

  @override
  List<Object?> get props => [id, name, defaultIntervalKm];
}
