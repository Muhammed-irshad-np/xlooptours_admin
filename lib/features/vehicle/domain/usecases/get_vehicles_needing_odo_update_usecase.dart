import '../entities/vehicle_entity.dart';

class GetVehiclesNeedingOdometerUpdateUseCase {
  List<VehicleEntity> call(List<VehicleEntity> vehicles) {
    final now = DateTime.now();
    final mostRecentThursday = getMostRecentThursday(now);
    return vehicles.where((vehicle) {
      if (vehicle.lastOdometerUpdateDate == null) return true;
      return vehicle.lastOdometerUpdateDate!.isBefore(mostRecentThursday);
    }).toList();
  }

  static DateTime getMostRecentThursday(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    int daysSinceThursday = dateOnly.weekday - DateTime.thursday;
    if (daysSinceThursday < 0) {
      daysSinceThursday += 7; // Go back to last week's Thursday
    }
    return dateOnly.subtract(Duration(days: daysSinceThursday));
  }

  static int countThursdays(DateTime start, DateTime end) {
    DateTime temp = DateTime(start.year, start.month, start.day);
    DateTime limit = DateTime(end.year, end.month, end.day);
    int count = 0;
    while (temp.isBefore(limit)) {
      temp = temp.add(const Duration(days: 1));
      if (temp.weekday == DateTime.thursday) {
        count++;
      }
    }
    return count;
  }

  int getMissedUpdatesCount(VehicleEntity vehicle) {
    final now = DateTime.now();
    if (vehicle.lastOdometerUpdateDate == null) {
      if (vehicle.purchaseDate != null) {
        final thursdays = countThursdays(vehicle.purchaseDate!, now);
        return thursdays > 0 ? thursdays : 1;
      }
      return 1;
    }
    final thursdays = countThursdays(vehicle.lastOdometerUpdateDate!, now);
    if (thursdays <= 1) return 0;
    return thursdays - 1;
  }
}
