import '../entities/vehicle_entity.dart';
import '../entities/vehicle_documents.dart';

class VehicleFollowUpAlert {
  final VehicleEntity vehicle;
  final MaintenanceRecord record;
  final int? currentMileage;
  final int? nextServiceMileage;
  final DateTime? nextServiceDate;
  final String reason;
  final bool isOverdue;

  VehicleFollowUpAlert({
    required this.vehicle,
    required this.record,
    this.currentMileage,
    this.nextServiceMileage,
    this.nextServiceDate,
    required this.reason,
    required this.isOverdue,
  });
}

class GetVehicleFollowUpAlertsUseCase {
  List<VehicleFollowUpAlert> call({
    required List<VehicleEntity> vehicles,
    bool includeAll = false,
  }) {
    final alerts = <VehicleFollowUpAlert>[];
    final now = DateTime.now();

    for (final vehicle in vehicles) {
      if (vehicle.maintenanceHistory == null || vehicle.maintenanceHistory!.isEmpty) {
        continue;
      }

      final currentMileage = vehicle.currentOdometer ?? 0;

      for (final record in vehicle.maintenanceHistory!) {
        // Only inspect records flagged for follow-up that are not completed
        if (record.isFollowUpRequired == true && record.isFollowUpCompleted != true) {
          bool isOverdue = false;

          // Check mileage-based follow-up
          if (record.nextServiceMileage != null && record.nextServiceMileage! > 0) {
            if (currentMileage >= record.nextServiceMileage!) {
              isOverdue = true;
            }
          }

          // Check date-based follow-up (warn if overdue or due today/in the past)
          if (record.nextServiceDate != null) {
            // Check if today is after the nextServiceDate
            // Subtracting time component for accurate date-only comparison
            final targetDate = DateTime(
              record.nextServiceDate!.year,
              record.nextServiceDate!.month,
              record.nextServiceDate!.day,
            );
            final today = DateTime(now.year, now.month, now.day);
            if (today.isAfter(targetDate) || today.isAtSameMomentAs(targetDate)) {
              isOverdue = true;
            }
          }

          // If it's overdue, or if we want to include all pending ones (for diagnostics/listings)
          if (includeAll || isOverdue) {
            final completionsCount = record.followUpCompletions?.length ?? 0;
            final totalCount = record.followUpTimesCount ?? 1;
            final visitInfo = (record.followUpIntervalKm != null && record.followUpIntervalKm! > 0 && record.followUpTimesCount != null)
                ? ' (Visit ${completionsCount + 1} of $totalCount)'
                : '';
            alerts.add(
              VehicleFollowUpAlert(
                vehicle: vehicle,
                record: record,
                currentMileage: currentMileage,
                nextServiceMileage: record.nextServiceMileage,
                nextServiceDate: record.nextServiceDate,
                reason: '${record.followUpReason ?? 'General Follow-up'}$visitInfo',
                isOverdue: isOverdue,
              ),
            );
          }
        }
      }
    }

    return alerts;
  }
}
