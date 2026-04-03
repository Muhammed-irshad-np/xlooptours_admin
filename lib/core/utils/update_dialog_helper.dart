import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/notifications/domain/entities/notification_entity.dart';
import '../../features/employee/presentation/providers/employee_provider.dart';
import '../../features/vehicle/presentation/providers/vehicle_provider.dart';
import '../../features/notifications/presentation/providers/notification_provider.dart';
import '../../widgets/custom_date_picker.dart';
import '../../features/vehicle/domain/entities/vehicle_documents.dart';
import '../../features/employee/domain/entities/employee_documents.dart';
import '../../features/employee/domain/entities/employee_entity.dart';
import '../../features/vehicle/domain/entities/vehicle_entity.dart';

class UpdateDialogHelper {
  static void showUpdateDialog(BuildContext context, NotificationEntity notification) {
    if (notification.id.startsWith('expiry_')) {
      _showEmployeeExpiryUpdateDialog(context, notification);
    } else if (notification.id.startsWith('maintenance_')) {
      _showVehicleMaintenanceUpdateDialog(context, notification);
    }
  }

  static void _showEmployeeExpiryUpdateDialog(BuildContext context, NotificationEntity notification) async {
    final relatedId = notification.relatedId;
    if (relatedId == null) return;

    final employeeProvider = context.read<EmployeeProvider>();
    final employee = employeeProvider.employees.cast<EmployeeEntity?>().firstWhere(
      (e) => e?.id == relatedId,
      orElse: () => null,
    );

    if (employee == null) return;

    // The id is structured as: expiry_EMPLID_Document_Type
    // The prefix length is 'expiry_${relatedId}_'.length
    final prefix = 'expiry_${relatedId}_';
    final documentTypeEncoded = notification.id.substring(prefix.length);
    final documentType = documentTypeEncoded.replaceAll('_', ' ');

    DateTime? selectedDate;

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
                                  insuranceExpiryDate: employee.iqama!.insuranceExpiryDate,
                                  attachmentUrl: employee.iqama!.attachmentUrl,
                                  notificationDays: employee.iqama!.notificationDays) 
                              : IqamaDocument(number: "", expiryDate: selectedDate!),
                        );
                        break;
                      case 'Driving License':
                        updatedEmployee = employee.copyWith(
                          drivingLicense: employee.drivingLicense != null
                              ? DrivingLicenseDocument(
                                  countryOfOrigin: employee.drivingLicense!.countryOfOrigin,
                                  number: employee.drivingLicense!.number,
                                  expiryDate: selectedDate!,
                                  type: employee.drivingLicense!.type,
                                  attachmentUrl: employee.drivingLicense!.attachmentUrl,
                                  notificationDays: employee.drivingLicense!.notificationDays)
                              : DrivingLicenseDocument(countryOfOrigin: "", number: "", expiryDate: selectedDate!, type: DrivingLicenseType.private),
                        );
                        break;
                      case 'Passport':
                        updatedEmployee = employee.copyWith(
                          passport: employee.passport != null
                              ? PassportDocument(
                                  nameOnPassport: employee.passport!.nameOnPassport,
                                  number: employee.passport!.number,
                                  expiryDate: selectedDate!,
                                  attachmentUrl: employee.passport!.attachmentUrl,
                                  notificationDays: employee.passport!.notificationDays)
                              : PassportDocument(nameOnPassport: "", number: "", expiryDate: selectedDate!),
                        );
                        break;
                      case 'Saudi Visa':
                        updatedEmployee = employee.copyWith(
                          saudiVisa: employee.saudiVisa != null
                              ? VisaDocument(number: employee.saudiVisa!.number, expiryDate: selectedDate!, type: employee.saudiVisa!.type, attachmentUrl: employee.saudiVisa!.attachmentUrl, notificationDays: employee.saudiVisa!.notificationDays)
                              : VisaDocument(number: "", expiryDate: selectedDate!),
                        );
                        break;
                      case 'Bahrain Visa':
                        updatedEmployee = employee.copyWith(
                          bahrainVisa: employee.bahrainVisa != null
                              ? VisaDocument(number: employee.bahrainVisa!.number, expiryDate: selectedDate!, type: employee.bahrainVisa!.type, attachmentUrl: employee.bahrainVisa!.attachmentUrl, notificationDays: employee.bahrainVisa!.notificationDays)
                              : VisaDocument(number: "", expiryDate: selectedDate!),
                        );
                        break;
                      case 'Dubai Visa':
                        updatedEmployee = employee.copyWith(
                          dubaiVisa: employee.dubaiVisa != null
                              ? VisaDocument(number: employee.dubaiVisa!.number, expiryDate: selectedDate!, type: employee.dubaiVisa!.type, attachmentUrl: employee.dubaiVisa!.attachmentUrl, notificationDays: employee.dubaiVisa!.notificationDays)
                              : VisaDocument(number: "", expiryDate: selectedDate!),
                        );
                        break;
                      case 'Qatar Visa':
                        updatedEmployee = employee.copyWith(
                          qatarVisa: employee.qatarVisa != null
                              ? VisaDocument(number: employee.qatarVisa!.number, expiryDate: selectedDate!, type: employee.qatarVisa!.type, attachmentUrl: employee.qatarVisa!.attachmentUrl, notificationDays: employee.qatarVisa!.notificationDays)
                              : VisaDocument(number: "", expiryDate: selectedDate!),
                        );
                        break;
                      case 'Phone Recharge':
                        updatedEmployee = employee.copyWith(
                          phoneRechargeDate: selectedDate,
                        );
                        break;
                    }

                    await employeeProvider.updateEmployee(updatedEmployee);
                    if (context.mounted) {
                      await context.read<NotificationProvider>().markAsRead(notification.id);
                      final vehicleProvider = context.read<VehicleProvider>();
                      await context.read<NotificationProvider>().refreshAlerts(
                        vehicles: vehicleProvider.vehicles,
                        maintenanceTypes: vehicleProvider.maintenanceTypes,
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
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

  static void _showVehicleMaintenanceUpdateDialog(BuildContext context, NotificationEntity notification) async {
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

    // Suggest current odometer if available
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
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomDatePicker(
                    label: 'Date of Maintenance',
                    date: selectedDate,
                    onTap: () async {
                      final picked = await showDatePicker(
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
                    controller: mileageController,
                    decoration: const InputDecoration(
                      labelText: 'Odometer Reading (KM)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: costController,
                    decoration: const InputDecoration(
                      labelText: 'Cost (Optional)',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      border: OutlineInputBorder(),
                    ),
                  ),
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
                    if (mileageController.text.isEmpty || int.tryParse(mileageController.text) == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid mileage')),
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

                    final currentMaintenance = vehicle.maintenance ?? const VehicleMaintenance();
                    VehicleMaintenance updatedMaintenance = currentMaintenance;

                    switch (category) {
                      case 'Engine Oil': updatedMaintenance = VehicleMaintenance(engineOil: newRecord, gearOil: currentMaintenance.gearOil, housingOil: currentMaintenance.housingOil, tyreChange: currentMaintenance.tyreChange, batteryChange: currentMaintenance.batteryChange, brakePads: currentMaintenance.brakePads, airFilter: currentMaintenance.airFilter, acService: currentMaintenance.acService, wheelAlignment: currentMaintenance.wheelAlignment, sparkPlugs: currentMaintenance.sparkPlugs, coolantFlush: currentMaintenance.coolantFlush, wiperBlades: currentMaintenance.wiperBlades, timingBelt: currentMaintenance.timingBelt, transmissionFluid: currentMaintenance.transmissionFluid, brakeFluid: currentMaintenance.brakeFluid, fuelFilter: currentMaintenance.fuelFilter); break;
                      case 'Gear Oil': updatedMaintenance = VehicleMaintenance(engineOil: currentMaintenance.engineOil, gearOil: newRecord, housingOil: currentMaintenance.housingOil, tyreChange: currentMaintenance.tyreChange, batteryChange: currentMaintenance.batteryChange, brakePads: currentMaintenance.brakePads, airFilter: currentMaintenance.airFilter, acService: currentMaintenance.acService, wheelAlignment: currentMaintenance.wheelAlignment, sparkPlugs: currentMaintenance.sparkPlugs, coolantFlush: currentMaintenance.coolantFlush, wiperBlades: currentMaintenance.wiperBlades, timingBelt: currentMaintenance.timingBelt, transmissionFluid: currentMaintenance.transmissionFluid, brakeFluid: currentMaintenance.brakeFluid, fuelFilter: currentMaintenance.fuelFilter); break;
                      case 'Housing Oil': updatedMaintenance = VehicleMaintenance(engineOil: currentMaintenance.engineOil, gearOil: currentMaintenance.gearOil, housingOil: newRecord, tyreChange: currentMaintenance.tyreChange, batteryChange: currentMaintenance.batteryChange, brakePads: currentMaintenance.brakePads, airFilter: currentMaintenance.airFilter, acService: currentMaintenance.acService, wheelAlignment: currentMaintenance.wheelAlignment, sparkPlugs: currentMaintenance.sparkPlugs, coolantFlush: currentMaintenance.coolantFlush, wiperBlades: currentMaintenance.wiperBlades, timingBelt: currentMaintenance.timingBelt, transmissionFluid: currentMaintenance.transmissionFluid, brakeFluid: currentMaintenance.brakeFluid, fuelFilter: currentMaintenance.fuelFilter); break;
                      case 'Tyre Change': updatedMaintenance = VehicleMaintenance(engineOil: currentMaintenance.engineOil, gearOil: currentMaintenance.gearOil, housingOil: currentMaintenance.housingOil, tyreChange: newRecord, batteryChange: currentMaintenance.batteryChange, brakePads: currentMaintenance.brakePads, airFilter: currentMaintenance.airFilter, acService: currentMaintenance.acService, wheelAlignment: currentMaintenance.wheelAlignment, sparkPlugs: currentMaintenance.sparkPlugs, coolantFlush: currentMaintenance.coolantFlush, wiperBlades: currentMaintenance.wiperBlades, timingBelt: currentMaintenance.timingBelt, transmissionFluid: currentMaintenance.transmissionFluid, brakeFluid: currentMaintenance.brakeFluid, fuelFilter: currentMaintenance.fuelFilter); break;
                      case 'Battery Change': updatedMaintenance = VehicleMaintenance(engineOil: currentMaintenance.engineOil, gearOil: currentMaintenance.gearOil, housingOil: currentMaintenance.housingOil, tyreChange: currentMaintenance.tyreChange, batteryChange: newRecord, brakePads: currentMaintenance.brakePads, airFilter: currentMaintenance.airFilter, acService: currentMaintenance.acService, wheelAlignment: currentMaintenance.wheelAlignment, sparkPlugs: currentMaintenance.sparkPlugs, coolantFlush: currentMaintenance.coolantFlush, wiperBlades: currentMaintenance.wiperBlades, timingBelt: currentMaintenance.timingBelt, transmissionFluid: currentMaintenance.transmissionFluid, brakeFluid: currentMaintenance.brakeFluid, fuelFilter: currentMaintenance.fuelFilter); break;
                      case 'Brake Pads': updatedMaintenance = VehicleMaintenance(engineOil: currentMaintenance.engineOil, gearOil: currentMaintenance.gearOil, housingOil: currentMaintenance.housingOil, tyreChange: currentMaintenance.tyreChange, batteryChange: currentMaintenance.batteryChange, brakePads: newRecord, airFilter: currentMaintenance.airFilter, acService: currentMaintenance.acService, wheelAlignment: currentMaintenance.wheelAlignment, sparkPlugs: currentMaintenance.sparkPlugs, coolantFlush: currentMaintenance.coolantFlush, wiperBlades: currentMaintenance.wiperBlades, timingBelt: currentMaintenance.timingBelt, transmissionFluid: currentMaintenance.transmissionFluid, brakeFluid: currentMaintenance.brakeFluid, fuelFilter: currentMaintenance.fuelFilter); break;
                      case 'Air Filter': updatedMaintenance = VehicleMaintenance(engineOil: currentMaintenance.engineOil, gearOil: currentMaintenance.gearOil, housingOil: currentMaintenance.housingOil, tyreChange: currentMaintenance.tyreChange, batteryChange: currentMaintenance.batteryChange, brakePads: currentMaintenance.brakePads, airFilter: newRecord, acService: currentMaintenance.acService, wheelAlignment: currentMaintenance.wheelAlignment, sparkPlugs: currentMaintenance.sparkPlugs, coolantFlush: currentMaintenance.coolantFlush, wiperBlades: currentMaintenance.wiperBlades, timingBelt: currentMaintenance.timingBelt, transmissionFluid: currentMaintenance.transmissionFluid, brakeFluid: currentMaintenance.brakeFluid, fuelFilter: currentMaintenance.fuelFilter); break;
                      case 'AC Service': updatedMaintenance = VehicleMaintenance(engineOil: currentMaintenance.engineOil, gearOil: currentMaintenance.gearOil, housingOil: currentMaintenance.housingOil, tyreChange: currentMaintenance.tyreChange, batteryChange: currentMaintenance.batteryChange, brakePads: currentMaintenance.brakePads, airFilter: currentMaintenance.airFilter, acService: newRecord, wheelAlignment: currentMaintenance.wheelAlignment, sparkPlugs: currentMaintenance.sparkPlugs, coolantFlush: currentMaintenance.coolantFlush, wiperBlades: currentMaintenance.wiperBlades, timingBelt: currentMaintenance.timingBelt, transmissionFluid: currentMaintenance.transmissionFluid, brakeFluid: currentMaintenance.brakeFluid, fuelFilter: currentMaintenance.fuelFilter); break;
                      case 'Wheel Alignment': updatedMaintenance = VehicleMaintenance(engineOil: currentMaintenance.engineOil, gearOil: currentMaintenance.gearOil, housingOil: currentMaintenance.housingOil, tyreChange: currentMaintenance.tyreChange, batteryChange: currentMaintenance.batteryChange, brakePads: currentMaintenance.brakePads, airFilter: currentMaintenance.airFilter, acService: currentMaintenance.acService, wheelAlignment: newRecord, sparkPlugs: currentMaintenance.sparkPlugs, coolantFlush: currentMaintenance.coolantFlush, wiperBlades: currentMaintenance.wiperBlades, timingBelt: currentMaintenance.timingBelt, transmissionFluid: currentMaintenance.transmissionFluid, brakeFluid: currentMaintenance.brakeFluid, fuelFilter: currentMaintenance.fuelFilter); break;
                      case 'Spark Plugs': updatedMaintenance = VehicleMaintenance(engineOil: currentMaintenance.engineOil, gearOil: currentMaintenance.gearOil, housingOil: currentMaintenance.housingOil, tyreChange: currentMaintenance.tyreChange, batteryChange: currentMaintenance.batteryChange, brakePads: currentMaintenance.brakePads, airFilter: currentMaintenance.airFilter, acService: currentMaintenance.acService, wheelAlignment: currentMaintenance.wheelAlignment, sparkPlugs: newRecord, coolantFlush: currentMaintenance.coolantFlush, wiperBlades: currentMaintenance.wiperBlades, timingBelt: currentMaintenance.timingBelt, transmissionFluid: currentMaintenance.transmissionFluid, brakeFluid: currentMaintenance.brakeFluid, fuelFilter: currentMaintenance.fuelFilter); break;
                      case 'Coolant Flush': updatedMaintenance = VehicleMaintenance(engineOil: currentMaintenance.engineOil, gearOil: currentMaintenance.gearOil, housingOil: currentMaintenance.housingOil, tyreChange: currentMaintenance.tyreChange, batteryChange: currentMaintenance.batteryChange, brakePads: currentMaintenance.brakePads, airFilter: currentMaintenance.airFilter, acService: currentMaintenance.acService, wheelAlignment: currentMaintenance.wheelAlignment, sparkPlugs: currentMaintenance.sparkPlugs, coolantFlush: newRecord, wiperBlades: currentMaintenance.wiperBlades, timingBelt: currentMaintenance.timingBelt, transmissionFluid: currentMaintenance.transmissionFluid, brakeFluid: currentMaintenance.brakeFluid, fuelFilter: currentMaintenance.fuelFilter); break;
                      case 'Wiper Blades': updatedMaintenance = VehicleMaintenance(engineOil: currentMaintenance.engineOil, gearOil: currentMaintenance.gearOil, housingOil: currentMaintenance.housingOil, tyreChange: currentMaintenance.tyreChange, batteryChange: currentMaintenance.batteryChange, brakePads: currentMaintenance.brakePads, airFilter: currentMaintenance.airFilter, acService: currentMaintenance.acService, wheelAlignment: currentMaintenance.wheelAlignment, sparkPlugs: currentMaintenance.sparkPlugs, coolantFlush: currentMaintenance.coolantFlush, wiperBlades: newRecord, timingBelt: currentMaintenance.timingBelt, transmissionFluid: currentMaintenance.transmissionFluid, brakeFluid: currentMaintenance.brakeFluid, fuelFilter: currentMaintenance.fuelFilter); break;
                      case 'Timing Belt': updatedMaintenance = VehicleMaintenance(engineOil: currentMaintenance.engineOil, gearOil: currentMaintenance.gearOil, housingOil: currentMaintenance.housingOil, tyreChange: currentMaintenance.tyreChange, batteryChange: currentMaintenance.batteryChange, brakePads: currentMaintenance.brakePads, airFilter: currentMaintenance.airFilter, acService: currentMaintenance.acService, wheelAlignment: currentMaintenance.wheelAlignment, sparkPlugs: currentMaintenance.sparkPlugs, coolantFlush: currentMaintenance.coolantFlush, wiperBlades: currentMaintenance.wiperBlades, timingBelt: newRecord, transmissionFluid: currentMaintenance.transmissionFluid, brakeFluid: currentMaintenance.brakeFluid, fuelFilter: currentMaintenance.fuelFilter); break;
                      case 'Transmission Fluid': updatedMaintenance = VehicleMaintenance(engineOil: currentMaintenance.engineOil, gearOil: currentMaintenance.gearOil, housingOil: currentMaintenance.housingOil, tyreChange: currentMaintenance.tyreChange, batteryChange: currentMaintenance.batteryChange, brakePads: currentMaintenance.brakePads, airFilter: currentMaintenance.airFilter, acService: currentMaintenance.acService, wheelAlignment: currentMaintenance.wheelAlignment, sparkPlugs: currentMaintenance.sparkPlugs, coolantFlush: currentMaintenance.coolantFlush, wiperBlades: currentMaintenance.wiperBlades, timingBelt: currentMaintenance.timingBelt, transmissionFluid: newRecord, brakeFluid: currentMaintenance.brakeFluid, fuelFilter: currentMaintenance.fuelFilter); break;
                      case 'Brake Fluid': updatedMaintenance = VehicleMaintenance(engineOil: currentMaintenance.engineOil, gearOil: currentMaintenance.gearOil, housingOil: currentMaintenance.housingOil, tyreChange: currentMaintenance.tyreChange, batteryChange: currentMaintenance.batteryChange, brakePads: currentMaintenance.brakePads, airFilter: currentMaintenance.airFilter, acService: currentMaintenance.acService, wheelAlignment: currentMaintenance.wheelAlignment, sparkPlugs: currentMaintenance.sparkPlugs, coolantFlush: currentMaintenance.coolantFlush, wiperBlades: currentMaintenance.wiperBlades, timingBelt: currentMaintenance.timingBelt, transmissionFluid: currentMaintenance.transmissionFluid, brakeFluid: newRecord, fuelFilter: currentMaintenance.fuelFilter); break;
                      case 'Fuel Filter': updatedMaintenance = VehicleMaintenance(engineOil: currentMaintenance.engineOil, gearOil: currentMaintenance.gearOil, housingOil: currentMaintenance.housingOil, tyreChange: currentMaintenance.tyreChange, batteryChange: currentMaintenance.batteryChange, brakePads: currentMaintenance.brakePads, airFilter: currentMaintenance.airFilter, acService: currentMaintenance.acService, wheelAlignment: currentMaintenance.wheelAlignment, sparkPlugs: currentMaintenance.sparkPlugs, coolantFlush: currentMaintenance.coolantFlush, wiperBlades: currentMaintenance.wiperBlades, timingBelt: currentMaintenance.timingBelt, transmissionFluid: currentMaintenance.transmissionFluid, brakeFluid: currentMaintenance.brakeFluid, fuelFilter: newRecord); break;
                    }

                    // For the vehicle, we should also update the current odometer if the newly provided one is greater
                    int updatedOdometer = vehicle.currentOdometer ?? 0;
                    if (newMileage > updatedOdometer) {
                      updatedOdometer = newMileage;
                    }

                    final updatedHistory = List<MaintenanceRecord>.from(vehicle.maintenanceHistory ?? []);
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
                      await context.read<NotificationProvider>().markAsRead(notification.id);
                      await context.read<NotificationProvider>().refreshAlerts(
                        vehicles: vehicleProvider.vehicles,
                        maintenanceTypes: vehicleProvider.maintenanceTypes,
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
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
