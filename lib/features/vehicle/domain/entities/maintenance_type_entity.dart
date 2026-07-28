import 'package:equatable/equatable.dart';

class MaintenanceTypeEntity extends Equatable {
  final String id;
  final String name;
  final int suvIntervalKm;
  final int sedanIntervalKm;

  /// Trigger type: 'odometer' (default) or 'date'
  final String triggerType;

  const MaintenanceTypeEntity({
    required this.id,
    required this.name,
    required this.suvIntervalKm,
    required this.sedanIntervalKm,
    this.triggerType = 'odometer',
  });

  bool get isDateTrigger => triggerType == 'date';
  bool get isOdometerTrigger => triggerType != 'date';

  int get defaultIntervalKm => suvIntervalKm;

  @override
  List<Object?> get props => [
        id,
        name,
        suvIntervalKm,
        sedanIntervalKm,
        triggerType,
      ];
}
