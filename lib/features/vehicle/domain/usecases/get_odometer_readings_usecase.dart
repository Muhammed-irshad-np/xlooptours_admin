import '../entities/odometer_reading_entity.dart';
import '../repositories/odometer_repository.dart';
import 'validate_odometer_reading_usecase.dart';

class GetOdometerReadingsUseCase {
  final OdometerRepository repository;

  const GetOdometerReadingsUseCase(this.repository);

  Future<List<OdometerReadingEntity>> call(String vehicleId) =>
      repository.getReadings(vehicleId);
}

/// Median km/day across the fleet.
///
/// Used as the baseline for a vehicle that has too little history of its own,
/// so a brand-new vehicle still gets a meaningful plausibility band instead of
/// falling straight through to a hard-coded constant.
class GetFleetDailyMedianUseCase {
  final OdometerRepository repository;

  const GetFleetDailyMedianUseCase(this.repository);

  Future<double?> call({int limit = 500}) async {
    final readings = await repository.getRecentReadings(limit: limit);
    if (readings.length < 2) return null;

    final byVehicle = <String, List<OdometerReadingEntity>>{};
    for (final r in readings) {
      byVehicle.putIfAbsent(r.vehicleId, () => []).add(r);
    }

    final perVehicleMedians = <double>[];
    for (final list in byVehicle.values) {
      list.sort((a, b) => a.readingAt.compareTo(b.readingAt));
      final m = ValidateOdometerReadingUseCase.ownDailyMedian(list);
      if (m != null && m > 0) perVehicleMedians.add(m);
    }

    if (perVehicleMedians.isEmpty) return null;
    perVehicleMedians.sort();
    final mid = perVehicleMedians.length ~/ 2;
    return perVehicleMedians.length.isOdd
        ? perVehicleMedians[mid]
        : (perVehicleMedians[mid - 1] + perVehicleMedians[mid]) / 2;
  }
}
