import 'package:equatable/equatable.dart';

class MaintenanceTypeEntity extends Equatable {
  final String id;
  final String name;
  final int suvIntervalKm;
  final int sedanIntervalKm;

  const MaintenanceTypeEntity({
    required this.id,
    required this.name,
    required this.suvIntervalKm,
    required this.sedanIntervalKm,
  });

  int get defaultIntervalKm => suvIntervalKm;

  @override
  List<Object?> get props => [id, name, suvIntervalKm, sedanIntervalKm];
}
