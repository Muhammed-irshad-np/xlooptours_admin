import '../entities/vehicle_entity.dart';

/// Decides which vehicles are due an odometer reading on the dashboard.
///
/// Readings are taken twice a week, on [checkDays] (Monday and Thursday). A
/// vehicle is due when its last accepted reading is older than the most recent
/// check day (today counts if today is a check day). So from Monday to
/// Wednesday a reading taken on or after Monday clears it, and from Thursday to
/// Sunday a reading taken on or after Thursday does.
///
/// Any accepted reading counts, whatever its source (dashboard, maintenance,
/// expense, vehicle form), because `lastOdometerUpdateDate` mirrors the latest
/// accepted reading. A reading held for review does not move it, so the
/// vehicle stays on the list until the reading is settled.
class GetVehiclesNeedingOdometerUpdateUseCase {
  /// Days of the week an odometer reading is due.
  static const List<int> checkDays = [DateTime.monday, DateTime.thursday];

  /// Human-readable form of [checkDays], for labels.
  static const String checkDaysLabel = 'Mon & Thu';

  List<VehicleEntity> call(List<VehicleEntity> vehicles, {DateTime? now}) {
    final dueSince = getMostRecentCheckDay(now ?? DateTime.now());
    return vehicles.where((vehicle) {
      if (vehicle.lastOdometerUpdateDate == null) return true;
      return vehicle.lastOdometerUpdateDate!.isBefore(dueSince);
    }).toList();
  }

  static bool isCheckDay(DateTime date) => checkDays.contains(date.weekday);

  /// Midnight of the most recent check day on or before [date].
  static DateTime getMostRecentCheckDay(DateTime date) {
    var day = DateTime(date.year, date.month, date.day);
    // Check days are at most 4 days apart, so this ends within a week.
    for (var i = 0; i < 7 && !isCheckDay(day); i++) {
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return day;
  }

  /// Number of check days after [start]'s date, up to and including [end]'s.
  static int countCheckDays(DateTime start, DateTime end) {
    var day = DateTime(start.year, start.month, start.day);
    final limit = DateTime(end.year, end.month, end.day);
    var count = 0;
    while (day.isBefore(limit)) {
      // Built from fields rather than adding 24 hours, so a DST shift cannot
      // skip or repeat a calendar day.
      day = DateTime(day.year, day.month, day.day + 1);
      if (isCheckDay(day)) count++;
    }
    return count;
  }

  /// Check days that passed without a reading, not counting the one currently
  /// due. A vehicle that has never been read counts every check day since
  /// purchase (at least one).
  int getMissedUpdatesCount(VehicleEntity vehicle, {DateTime? now}) {
    final today = now ?? DateTime.now();
    if (vehicle.lastOdometerUpdateDate == null) {
      if (vehicle.purchaseDate != null) {
        final days = countCheckDays(vehicle.purchaseDate!, today);
        return days > 0 ? days : 1;
      }
      return 1;
    }
    final days = countCheckDays(vehicle.lastOdometerUpdateDate!, today);
    if (days <= 1) return 0;
    return days - 1;
  }
}
