import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import 'package:intl/intl.dart';
import '../../features/notifications/domain/entities/notification_entity.dart';
import '../../features/employee/presentation/providers/employee_provider.dart';
import '../../features/vehicle/presentation/providers/vehicle_provider.dart';
import '../../features/notifications/presentation/providers/notification_provider.dart';
import '../../widgets/custom_date_picker.dart';
import '../../features/vehicle/domain/entities/vehicle_documents.dart';
import '../../features/employee/domain/entities/employee_contact.dart';
import '../../features/employee/domain/entities/employee_documents.dart';
import '../../features/employee/domain/entities/employee_entity.dart';
import '../../features/vehicle/domain/entities/vehicle_entity.dart';

class UpdateDialogHelper {
  static void showUpdateDialog(
    BuildContext context,
    NotificationEntity notification,
  ) {
    if (notification.id.startsWith('expiry_')) {
      _showEmployeeExpiryUpdateDialog(context, notification);
    } else if (notification.id.startsWith('maintenance_')) {
      _showVehicleMaintenanceUpdateDialog(context, notification);
    }
  }

  static void _showEmployeeExpiryUpdateDialog(
    BuildContext context,
    NotificationEntity notification,
  ) async {
    final relatedId = notification.relatedId;
    if (relatedId == null) return;

    final employeeProvider = context.read<EmployeeProvider>();
    final employee = employeeProvider.employees
        .cast<EmployeeEntity?>()
        .firstWhere((e) => e?.id == relatedId, orElse: () => null);

    if (employee == null) return;

    final prefix = 'expiry_${relatedId}_';
    final documentTypeEncoded = notification.id.substring(prefix.length);
    final documentType = documentTypeEncoded.replaceAll('_', ' ');

    DateTime? selectedDate;
    final costController = TextEditingController();
    String? selectedHolderId;

    // Pre-fill if it's a phone recharge
    if (documentType.startsWith('Phone Recharge')) {
      final contactId = documentType.replaceFirst('Phone Recharge ', '').trim();
      final contact = employee.contacts.cast<EmployeeContact?>().firstWhere(
        (c) => '${c?.countryCode} ${c?.phoneNumber}' == contactId,
        orElse: () => null,
      );
      if (contact != null) {
        selectedHolderId = contact.currentHolderId ?? employee.id;
        if (contact.rechargeCost != null) {
          costController.text = contact.rechargeCost.toString();
        }
        selectedDate = contact.rechargeExpiryDate;
      }
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Update $documentType Expiry'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomDatePicker(
                    label: 'New Expiry Date',
                    date: selectedDate,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                  ),
                  if (documentType.startsWith('Phone Recharge')) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: costController,
                      decoration: const InputDecoration(
                        labelText: 'Recharge Cost',
                        border: OutlineInputBorder(),
                        prefixText: 'SAR ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedHolderId,
                      decoration: const InputDecoration(
                        labelText: 'Assign Cost To',
                        border: OutlineInputBorder(),
                      ),
                      items: employeeProvider.employees.map((e) {
                        return DropdownMenuItem(
                          value: e.id,
                          child: Text(e.fullName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedHolderId = value;
                        });
                      },
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select a date')),
                      );
                      return;
                    }

                    EmployeeEntity updatedEmployee = employee;

                    switch (documentType) {
                      case 'Iqama':
                        updatedEmployee = employee.copyWith(
                          iqama: employee.iqama != null
                              ? IqamaDocument(
                                  number: employee.iqama!.number,
                                  expiryDate: selectedDate!,
                                  insuranceExpiryDate:
                                      employee.iqama!.insuranceExpiryDate,
                                  attachmentUrl: employee.iqama!.attachmentUrl,
                                  notificationDays:
                                      employee.iqama!.notificationDays,
                                )
                              : IqamaDocument(
                                  number: "",
                                  expiryDate: selectedDate!,
                                ),
                        );
                        break;
                      case 'Driving License':
                        updatedEmployee = employee.copyWith(
                          drivingLicense: employee.drivingLicense != null
                              ? DrivingLicenseDocument(
                                  countryOfOrigin:
                                      employee.drivingLicense!.countryOfOrigin,
                                  number: employee.drivingLicense!.number,
                                  expiryDate: selectedDate!,
                                  type: employee.drivingLicense!.type,
                                  attachmentUrl:
                                      employee.drivingLicense!.attachmentUrl,
                                  notificationDays:
                                      employee.drivingLicense!.notificationDays,
                                )
                              : DrivingLicenseDocument(
                                  countryOfOrigin: "",
                                  number: "",
                                  expiryDate: selectedDate!,
                                  type: DrivingLicenseType.private,
                                ),
                        );
                        break;
                      case 'Passport':
                        updatedEmployee = employee.copyWith(
                          passport: employee.passport != null
                              ? PassportDocument(
                                  nameOnPassport:
                                      employee.passport!.nameOnPassport,
                                  number: employee.passport!.number,
                                  expiryDate: selectedDate!,
                                  attachmentUrl:
                                      employee.passport!.attachmentUrl,
                                  notificationDays:
                                      employee.passport!.notificationDays,
                                )
                              : PassportDocument(
                                  nameOnPassport: "",
                                  number: "",
                                  expiryDate: selectedDate!,
                                ),
                        );
                        break;
                      case 'Saudi Visa':
                        updatedEmployee = employee.copyWith(
                          saudiVisa: employee.saudiVisa != null
                              ? VisaDocument(
                                  number: employee.saudiVisa!.number,
                                  expiryDate: selectedDate!,
                                  type: employee.saudiVisa!.type,
                                  attachmentUrl:
                                      employee.saudiVisa!.attachmentUrl,
                                  notificationDays:
                                      employee.saudiVisa!.notificationDays,
                                )
                              : VisaDocument(
                                  number: "",
                                  expiryDate: selectedDate!,
                                ),
                        );
                        break;
                      case 'Bahrain Visa':
                        updatedEmployee = employee.copyWith(
                          bahrainVisa: employee.bahrainVisa != null
                              ? VisaDocument(
                                  number: employee.bahrainVisa!.number,
                                  expiryDate: selectedDate!,
                                  type: employee.bahrainVisa!.type,
                                  attachmentUrl:
                                      employee.bahrainVisa!.attachmentUrl,
                                  notificationDays:
                                      employee.bahrainVisa!.notificationDays,
                                )
                              : VisaDocument(
                                  number: "",
                                  expiryDate: selectedDate!,
                                ),
                        );
                        break;
                      case 'Dubai Visa':
                        updatedEmployee = employee.copyWith(
                          dubaiVisa: employee.dubaiVisa != null
                              ? VisaDocument(
                                  number: employee.dubaiVisa!.number,
                                  expiryDate: selectedDate!,
                                  type: employee.dubaiVisa!.type,
                                  attachmentUrl:
                                      employee.dubaiVisa!.attachmentUrl,
                                  notificationDays:
                                      employee.dubaiVisa!.notificationDays,
                                )
                              : VisaDocument(
                                  number: "",
                                  expiryDate: selectedDate!,
                                ),
                        );
                        break;
                      case 'Qatar Visa':
                        updatedEmployee = employee.copyWith(
                          qatarVisa: employee.qatarVisa != null
                              ? VisaDocument(
                                  number: employee.qatarVisa!.number,
                                  expiryDate: selectedDate!,
                                  type: employee.qatarVisa!.type,
                                  attachmentUrl:
                                      employee.qatarVisa!.attachmentUrl,
                                  notificationDays:
                                      employee.qatarVisa!.notificationDays,
                                )
                              : VisaDocument(
                                  number: "",
                                  expiryDate: selectedDate!,
                                ),
                        );
                        break;
                      default:
                        // Handle Phone Recharge contacts (documentType contains phone number)
                        if (documentType.startsWith('Phone Recharge')) {
                          final updatedContacts = employee.contacts.map((c) {
                            final contactId =
                                '${c.countryCode} ${c.phoneNumber}';
                            if (documentType.contains(contactId)) {
                              return c.copyWith(
                                rechargeExpiryDate: selectedDate,
                                rechargeCost: double.tryParse(
                                  costController.text,
                                ),
                                currentHolderId: selectedHolderId,
                              );
                            }
                            return c;
                          }).toList();
                          updatedEmployee = employee.copyWith(
                            contacts: updatedContacts,
                          );
                        }
                        break;
                    }

                    await employeeProvider.updateEmployee(updatedEmployee);

                    if (context.mounted) {
                      final notificationProvider = context
                          .read<NotificationProvider>();
                      final vehicleProvider = context.read<VehicleProvider>();
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);

                      await notificationProvider.markAsRead(notification.id);
                      await notificationProvider.refreshAlerts(
                        vehicles: vehicleProvider.vehicles,
                        maintenanceTypes: vehicleProvider.maintenanceTypes,
                      );

                      navigator.pop();
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Updated successfully')),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static void _showVehicleMaintenanceUpdateDialog(
    BuildContext context,
    NotificationEntity notification,
  ) async {
    final relatedId = notification.relatedId;
    if (relatedId == null) return;

    final vehicleProvider = context.read<VehicleProvider>();
    final vehicle = vehicleProvider.vehicles.cast<VehicleEntity?>().firstWhere(
      (v) => v?.id == relatedId,
      orElse: () => null,
    );

    if (vehicle == null) return;

    final prefix = 'maintenance_${relatedId}_';
    final categoryEncoded = notification.id.substring(prefix.length);
    final category = categoryEncoded.replaceAll('_', ' ');

    DateTime? selectedDate = DateTime.now();
    final mileageController = TextEditingController();
    final costController = TextEditingController();
    final notesController = TextEditingController();

    if (vehicle.currentOdometer != null) {
      mileageController.text = vehicle.currentOdometer.toString();
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Update $category'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Vehicle: ${vehicle.make} ${vehicle.model} (${vehicle.plateNumber})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('Maintenance Category: $category'),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: mileageController,
                      decoration: const InputDecoration(
                        labelText: 'Odometer Reading (KM)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    CustomDatePicker(
                      label: 'Service Date',
                      date: selectedDate,
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: costController,
                      decoration: const InputDecoration(
                        labelText: 'Cost (Optional)',
                        prefixText: 'SAR ',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select a date')),
                      );
                      return;
                    }
                    if (mileageController.text.isEmpty ||
                        int.tryParse(mileageController.text) == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid mileage'),
                        ),
                      );
                      return;
                    }

                    final newMileage = int.parse(mileageController.text);
                    final newRecord = MaintenanceRecord(
                      date: selectedDate!,
                      mileage: newMileage,
                      cost: double.tryParse(costController.text),
                      notes: notesController.text,
                      serviceType: category,
                    );

                    final currentMaintenance =
                        vehicle.maintenance ?? const VehicleMaintenance();
                    VehicleMaintenance updatedMaintenance = currentMaintenance;

                    switch (category) {
                      case 'Engine Oil':
                        updatedMaintenance = currentMaintenance.copyWith(
                          engineOil: newRecord,
                        );
                        break;
                      case 'Gear Oil':
                        updatedMaintenance = currentMaintenance.copyWith(
                          gearOil: newRecord,
                        );
                        break;
                      case 'Housing Oil':
                        updatedMaintenance = currentMaintenance.copyWith(
                          housingOil: newRecord,
                        );
                        break;
                      case 'Tyre Change':
                        updatedMaintenance = currentMaintenance.copyWith(
                          tyreChange: newRecord,
                        );
                        break;
                      case 'Battery Change':
                        updatedMaintenance = currentMaintenance.copyWith(
                          batteryChange: newRecord,
                        );
                        break;
                      case 'Brake Pads':
                        updatedMaintenance = currentMaintenance.copyWith(
                          brakePads: newRecord,
                        );
                        break;
                      case 'Air Filter':
                        updatedMaintenance = currentMaintenance.copyWith(
                          airFilter: newRecord,
                        );
                        break;
                      case 'AC Service':
                        updatedMaintenance = currentMaintenance.copyWith(
                          acService: newRecord,
                        );
                        break;
                      case 'Wheel Alignment':
                        updatedMaintenance = currentMaintenance.copyWith(
                          wheelAlignment: newRecord,
                        );
                        break;
                      case 'Spark Plugs':
                        updatedMaintenance = currentMaintenance.copyWith(
                          sparkPlugs: newRecord,
                        );
                        break;
                      case 'Coolant Flush':
                        updatedMaintenance = currentMaintenance.copyWith(
                          coolantFlush: newRecord,
                        );
                        break;
                      case 'Wiper Blades':
                        updatedMaintenance = currentMaintenance.copyWith(
                          wiperBlades: newRecord,
                        );
                        break;
                      case 'Timing Belt':
                        updatedMaintenance = currentMaintenance.copyWith(
                          timingBelt: newRecord,
                        );
                        break;
                      case 'Transmission Fluid':
                        updatedMaintenance = currentMaintenance.copyWith(
                          transmissionFluid: newRecord,
                        );
                        break;
                      case 'Brake Fluid':
                        updatedMaintenance = currentMaintenance.copyWith(
                          brakeFluid: newRecord,
                        );
                        break;
                      case 'Fuel Filter':
                        updatedMaintenance = currentMaintenance.copyWith(
                          fuelFilter: newRecord,
                        );
                        break;
                    }

                    int updatedOdometer = vehicle.currentOdometer ?? 0;
                    if (newMileage > updatedOdometer) {
                      updatedOdometer = newMileage;
                    }

                    final updatedHistory = List<MaintenanceRecord>.from(
                      vehicle.maintenanceHistory ?? [],
                    );
                    updatedHistory.add(newRecord);

                    final updatedVehicle = vehicle.copyWith(
                      maintenance: updatedMaintenance,
                      currentOdometer: updatedOdometer,
                      lastOdometerUpdateDate:
                          newMileage > (vehicle.currentOdometer ?? 0)
                          ? DateTime.now()
                          : vehicle.lastOdometerUpdateDate,
                      maintenanceHistory: updatedHistory,
                    );

                    await vehicleProvider.updateVehicle(updatedVehicle);

                    if (context.mounted) {
                      final notificationProvider = context
                          .read<NotificationProvider>();
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);

                      await notificationProvider.markAsRead(notification.id);
                      await notificationProvider.refreshAlerts(
                        vehicles: vehicleProvider.vehicles,
                        maintenanceTypes: vehicleProvider.maintenanceTypes,
                      );

                      navigator.pop();
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Updated successfully')),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
