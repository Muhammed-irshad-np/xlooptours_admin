import 'package:xloop_invoice/features/employee/domain/entities/employee_entity.dart';
import 'package:xloop_invoice/features/employee/domain/entities/employee_settings_entity.dart';
import '../entities/employee_expiry_alert.dart';
import '../repositories/employee_repository.dart';

class GetEmployeeExpiryAlertsUseCase {
  final EmployeeRepository repository;

  GetEmployeeExpiryAlertsUseCase(this.repository);

  Future<List<EmployeeExpiryAlert>> call({
    bool includeAll = false,
    List<EmployeeEntity>? localEmployees,
    EmployeeSettingsEntity? localSettings,
  }) async {
    final employees = localEmployees ?? await repository.getAllEmployees();
    final settings = localSettings ?? await repository.getEmployeeSettings();
    final List<EmployeeExpiryAlert> alerts = [];
    final now = DateTime.now();

    for (var employee in employees) {
      if (!employee.isActive) continue;

      // Iqama
      if (employee.iqama != null) {
        final days = employee.iqama!.expiryDate.difference(now).inDays;
        final alertDays = settings.iqamaAlertDays;
        if (includeAll || days <= alertDays) {
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
        final alertDays = settings.drivingLicenseAlertDays;
        if (includeAll || days <= alertDays) {
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
        final alertDays = settings.passportAlertDays;
        if (includeAll || days <= alertDays) {
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
        final alertDays = settings.saudiVisaAlertDays;
        if (includeAll || days <= alertDays) {
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

      // Bahrain Residence
      if (employee.bahrainResidence != null) {
        final days = employee.bahrainResidence!.expiryDate.difference(now).inDays;
        final alertDays = settings.bahrainResidenceAlertDays;
        if (includeAll || days <= alertDays) {
          alerts.add(
            EmployeeExpiryAlert(
              employeeId: employee.id,
              employeeName: employee.fullName,
              documentType: 'Bahrain Residence',
              expiryDate: employee.bahrainResidence!.expiryDate,
              daysUntilExpiry: days,
            ),
          );
        }
      }

      // Bahrain Visa
      if (employee.bahrainVisa != null) {
        final days = employee.bahrainVisa!.expiryDate.difference(now).inDays;
        final alertDays = settings.bahrainVisaAlertDays;
        if (includeAll || days <= alertDays) {
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
        final alertDays = settings.dubaiVisaAlertDays;
        if (includeAll || days <= alertDays) {
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
        final alertDays = settings.qatarVisaAlertDays;
        if (includeAll || days <= alertDays) {
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

      // Health Insurance
      if (employee.healthInsurance != null) {
        final days = employee.healthInsurance!.expiryDate.difference(now).inDays;
        final alertDays = settings.healthInsuranceAlertDays;
        if (includeAll || days <= alertDays) {
          alerts.add(
            EmployeeExpiryAlert(
              employeeId: employee.id,
              employeeName: employee.fullName,
              documentType: 'Health Insurance',
              expiryDate: employee.healthInsurance!.expiryDate,
              daysUntilExpiry: days,
            ),
          );
        }
      }

      // Tafweed (Authorization)
      if (employee.authorization != null) {
        final days = employee.authorization!.expiryDate.difference(now).inDays;
        final alertDays = settings.tafweedAlertDays;
        if (includeAll || days <= alertDays) {
          alerts.add(
            EmployeeExpiryAlert(
              employeeId: employee.id,
              employeeName: employee.fullName,
              documentType: 'Tafweed (Authorization)',
              expiryDate: employee.authorization!.expiryDate,
              daysUntilExpiry: days,
            ),
          );
        }
      }

      // Phone Recharge – per contact
      for (final contact in employee.contacts) {
        if (contact.rechargeExpiryDate != null) {
          final days = contact.rechargeExpiryDate!.difference(now).inDays;
          final alertDays = settings.phoneRechargeAlertDays;
          if (includeAll || days <= alertDays) {
            // Tag alert to the current holder if SIM is swapped
            final holderId = contact.currentHolderId ?? employee.id;
            final holderName = contact.currentHolderName ?? employee.fullName;
            alerts.add(
              EmployeeExpiryAlert(
                employeeId: holderId,
                employeeName: holderName,
                documentType:
                    'Phone Recharge (${contact.countryCode} ${contact.phoneNumber})',
                expiryDate: contact.rechargeExpiryDate!,
                daysUntilExpiry: days,
              ),
            );
          }
        }
      }
    }

    // Sort alerts by days until expiry (ascending, so most urgent first)
    alerts.sort((a, b) => a.daysUntilExpiry.compareTo(b.daysUntilExpiry));

    return alerts;
  }
}
