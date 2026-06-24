import 'package:xloop_invoice/features/employee/domain/repositories/employee_repository.dart';
import '../entities/vehicle_expiry_alert.dart';
import '../repositories/vehicle_repository.dart';

class GetVehicleExpiryAlertsUseCase {
  final VehicleRepository repository;
  final EmployeeRepository employeeRepository;

  GetVehicleExpiryAlertsUseCase(this.repository, this.employeeRepository);

  Future<List<VehicleExpiryAlert>> call({bool includeAll = false}) async {
    final vehicles = await repository.getAllVehicles();
    final settings = await repository.getVehicleSettings();
    final employees = await employeeRepository.getAllEmployees();

    // Create a map of employee ID to employee full name for O(1) lookups
    final Map<String, String> employeeNameMap = {
      for (var emp in employees) emp.id: emp.fullName
    };

    final List<VehicleExpiryAlert> alerts = [];
    final now = DateTime.now();

    for (var vehicle in vehicles) {
      if (vehicle.status?.toLowerCase() != 'active') continue;

      // Isthimara (Registration)
      if (vehicle.registration != null) {
        final days = vehicle.registration!.expiryDate.difference(now).inDays;
        final alertDays = vehicle.registration!.notificationDays ?? settings.isthimaraAlertDays;
        if (includeAll || days <= alertDays) {
          alerts.add(
            VehicleExpiryAlert(
              vehicleId: vehicle.id,
              plateNumber: vehicle.plateNumber,
              documentType: 'Isthimara',
              expiryDate: vehicle.registration!.expiryDate,
              daysUntilExpiry: days,
            ),
          );
        }
      }

      // Fahas
      if (vehicle.fahas != null) {
        final days = vehicle.fahas!.expiryDate.difference(now).inDays;
        final alertDays = vehicle.fahas!.notificationDays ?? settings.fahasAlertDays;
        if (includeAll || days <= alertDays) {
          alerts.add(
            VehicleExpiryAlert(
              vehicleId: vehicle.id,
              plateNumber: vehicle.plateNumber,
              documentType: 'Fahas',
              expiryDate: vehicle.fahas!.expiryDate,
              daysUntilExpiry: days,
            ),
          );
        }
      }

      // Insurance
      if (vehicle.insurance != null) {
        final days = vehicle.insurance!.expiryDate.difference(now).inDays;
        final alertDays = vehicle.insurance!.notificationDays ?? settings.insuranceAlertDays;
        if (includeAll || days <= alertDays) {
          alerts.add(
            VehicleExpiryAlert(
              vehicleId: vehicle.id,
              plateNumber: vehicle.plateNumber,
              documentType: 'Insurance',
              expiryDate: vehicle.insurance!.expiryDate,
              daysUntilExpiry: days,
            ),
          );
        }
      }

      // Bahrain Insurance
      if (vehicle.bahrainInsurance != null) {
        final days = vehicle.bahrainInsurance!.expiryDate.difference(now).inDays;
        final alertDays = vehicle.bahrainInsurance!.notificationDays ?? settings.bahrainInsuranceAlertDays;
        if (includeAll || days <= alertDays) {
          alerts.add(
            VehicleExpiryAlert(
              vehicleId: vehicle.id,
              plateNumber: vehicle.plateNumber,
              documentType: 'Bahrain Insurance',
              expiryDate: vehicle.bahrainInsurance!.expiryDate,
              daysUntilExpiry: days,
            ),
          );
        }
      }

      // Tafweed
      if (vehicle.tafweeds != null) {
        for (var tafweed in vehicle.tafweeds!) {
          final days = tafweed.expiryDate.difference(now).inDays;
          final alertDays = tafweed.notificationDays ?? settings.tafweedAlertDays;
          if (includeAll || days <= alertDays) {
            final driverName = employeeNameMap[tafweed.driverId];
            alerts.add(
              VehicleExpiryAlert(
                vehicleId: vehicle.id,
                plateNumber: vehicle.plateNumber,
                documentType: 'Tafweed',
                expiryDate: tafweed.expiryDate,
                daysUntilExpiry: days,
                documentId: tafweed.driverId,
                driverName: driverName,
              ),
            );
          }
        }
      }
    }

    // Sort alerts by days until expiry (ascending)
    alerts.sort((a, b) => a.daysUntilExpiry.compareTo(b.daysUntilExpiry));

    return alerts;
  }
}
