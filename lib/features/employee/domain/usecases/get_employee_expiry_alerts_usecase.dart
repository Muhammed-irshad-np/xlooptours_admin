import '../entities/employee_expiry_alert.dart';
import '../repositories/employee_repository.dart';

class GetEmployeeExpiryAlertsUseCase {
  final EmployeeRepository repository;

  GetEmployeeExpiryAlertsUseCase(this.repository);

  Future<List<EmployeeExpiryAlert>> call() async {
    final employees = await repository.getAllEmployees();
    final List<EmployeeExpiryAlert> alerts = [];
    final now = DateTime.now();

    for (var employee in employees) {
      if (!employee.isActive) continue;

      // Iqama: 1 month before
      if (employee.iqama != null) {
        final days = employee.iqama!.expiryDate.difference(now).inDays;
        if (days <= 30) {
          alerts.add(
            EmployeeExpiryAlert(
              employeeId: employee.id,
              employeeName: employee.fullName,
              documentType: 'Iqama',
              expiryDate: employee.iqama!.expiryDate,
              daysUntilExpiry: days,
            ),
          );
        }
      }

      // Driving License: 1 month before
      if (employee.drivingLicense != null) {
        final days = employee.drivingLicense!.expiryDate.difference(now).inDays;
        if (days <= 30) {
          alerts.add(
            EmployeeExpiryAlert(
              employeeId: employee.id,
              employeeName: employee.fullName,
              documentType: 'Driving License',
              expiryDate: employee.drivingLicense!.expiryDate,
              daysUntilExpiry: days,
            ),
          );
        }
      }

      // Passport: 1 month before
      if (employee.passport != null) {
        final days = employee.passport!.expiryDate.difference(now).inDays;
        if (days <= 30) {
          // Alerting anything under 1 month
          alerts.add(
            EmployeeExpiryAlert(
              employeeId: employee.id,
              employeeName: employee.fullName,
              documentType: 'Passport',
              expiryDate: employee.passport!.expiryDate,
              daysUntilExpiry: days,
            ),
          );
        }
      }

      // Saudi Visa: 1 month before
      if (employee.saudiVisa != null) {
        final days = employee.saudiVisa!.expiryDate.difference(now).inDays;
        if (days <= 30) {
          alerts.add(
            EmployeeExpiryAlert(
              employeeId: employee.id,
              employeeName: employee.fullName,
              documentType: 'Saudi Visa',
              expiryDate: employee.saudiVisa!.expiryDate,
              daysUntilExpiry: days,
            ),
          );
        }
      }

      // Bahrain Visa: 1 month before
      if (employee.bahrainVisa != null) {
        final days = employee.bahrainVisa!.expiryDate.difference(now).inDays;
        if (days <= 30) {
          alerts.add(
            EmployeeExpiryAlert(
              employeeId: employee.id,
              employeeName: employee.fullName,
              documentType: 'Bahrain Visa',
              expiryDate: employee.bahrainVisa!.expiryDate,
              daysUntilExpiry: days,
            ),
          );
        }
      }
    }

    // Sort alerts by days until expiry (ascending, so most urgent first)
    alerts.sort((a, b) => a.daysUntilExpiry.compareTo(b.daysUntilExpiry));

    return alerts;
  }
}
