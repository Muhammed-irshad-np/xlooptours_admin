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

      // Iqama
      if (employee.iqama != null) {
        final days = employee.iqama!.expiryDate.difference(now).inDays;
        final alertDays = employee.iqama!.notificationDays ?? 30;
        if (days <= alertDays) {
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

      // Driving License
      if (employee.drivingLicense != null) {
        final days = employee.drivingLicense!.expiryDate.difference(now).inDays;
        final alertDays = employee.drivingLicense!.notificationDays ?? 30;
        if (days <= alertDays) {
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

      // Passport
      if (employee.passport != null) {
        final days = employee.passport!.expiryDate.difference(now).inDays;
        final alertDays = employee.passport!.notificationDays ?? 30;
        if (days <= alertDays) {
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

      // Saudi Visa
      if (employee.saudiVisa != null) {
        final days = employee.saudiVisa!.expiryDate.difference(now).inDays;
        final alertDays = employee.saudiVisa!.notificationDays ?? 30;
        if (days <= alertDays) {
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

      // Bahrain Visa
      if (employee.bahrainVisa != null) {
        final days = employee.bahrainVisa!.expiryDate.difference(now).inDays;
        final alertDays = employee.bahrainVisa!.notificationDays ?? 30;
        if (days <= alertDays) {
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

      // Dubai Visa
      if (employee.dubaiVisa != null) {
        final days = employee.dubaiVisa!.expiryDate.difference(now).inDays;
        final alertDays = employee.dubaiVisa!.notificationDays ?? 30;
        if (days <= alertDays) {
          alerts.add(
            EmployeeExpiryAlert(
              employeeId: employee.id,
              employeeName: employee.fullName,
              documentType: 'Dubai Visa',
              expiryDate: employee.dubaiVisa!.expiryDate,
              daysUntilExpiry: days,
            ),
          );
        }
      }

      // Qatar Visa
      if (employee.qatarVisa != null) {
        final days = employee.qatarVisa!.expiryDate.difference(now).inDays;
        final alertDays = employee.qatarVisa!.notificationDays ?? 30;
        if (days <= alertDays) {
          alerts.add(
            EmployeeExpiryAlert(
              employeeId: employee.id,
              employeeName: employee.fullName,
              documentType: 'Qatar Visa',
              expiryDate: employee.qatarVisa!.expiryDate,
              daysUntilExpiry: days,
            ),
          );
        }
      }

      // Phone Recharge
      if (employee.phoneRechargeDate != null) {
        final days = employee.phoneRechargeDate!.difference(now).inDays;
        final alertDays = employee.phoneRechargeNotificationDays ?? 30;
        if (days <= alertDays) {
          alerts.add(
            EmployeeExpiryAlert(
              employeeId: employee.id,
              employeeName: employee.fullName,
              documentType: 'Phone Recharge',
              expiryDate: employee.phoneRechargeDate!,
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
