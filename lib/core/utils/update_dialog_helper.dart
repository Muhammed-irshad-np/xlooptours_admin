import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
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
import '../../features/xloop_vault/presentation/providers/vault_provider.dart';
import '../../features/xloop_vault/domain/entities/vault_data.dart';

class UpdateDialogHelper {
  static void showUpdateDialog(
    BuildContext context,
    NotificationEntity notification,
  ) {
    if (notification.id.startsWith('expiry_')) {
      _showEmployeeExpiryUpdateDialog(context, notification);
    } else if (notification.id.startsWith('maintenance_')) {
      _showVehicleMaintenanceUpdateDialog(context, notification);
    } else if (notification.id.startsWith('vault_')) {
      _showVaultExpiryUpdateDialog(context, notification);
    } else if (notification.id.startsWith('v_expiry_')) {
      _showVehicleExpiryUpdateDialog(context, notification);
    }
  }

  /// Shows a dialog to update an employee document's expiry date, with an
  /// optional file picker to replace the existing attachment.
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

    // Map document type label → storage key used by uploadDocumentAttachment
    const docTypeKeys = <String, String>{
      'Iqama': 'iqama',
      'Bahrain Residence ID': 'bahrain_residence',
      'Passport': 'passport',
      'Driving License': 'driving_license',
      'Saudi Visa': 'saudi_visa',
      'Bahrain Visa': 'bahrain_visa',
      'Dubai Visa': 'dubai_visa',
      'Qatar Visa': 'qatar_visa',
      'Authorization': 'authorization',
      'Health Insurance': 'health_insurance',
    };

    DateTime? selectedDate;
    final costController = TextEditingController();
    String? selectedHolderId;
    XFile? pickedFile;
    bool isSaving = false;

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

    /// Returns the extension-only filename, trimmed to ~30 chars for display.
    String _fileName(XFile f) {
      final base = p.basename(f.path);
      return base.length > 30 ? '...${base.substring(base.length - 27)}' : base;
    }

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            // Whether this document type supports an attachment upload
            final supportsUpload =
                docTypeKeys.containsKey(documentType) &&
                !documentType.startsWith('Phone Recharge');

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Update $documentType',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Expiry date picker ───────────────────────────────
                    CustomDatePicker(
                      label: 'New Expiry Date',
                      date: selectedDate,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() => selectedDate = picked);
                        }
                      },
                    ),

                    // ── File upload (only for doc types that have attachments) ─
                    if (supportsUpload) ...[
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 4),
                      Text(
                        'Replace Document (optional)',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        icon: Icon(
                          pickedFile != null
                              ? Icons.check_circle
                              : Icons.attach_file,
                          color: pickedFile != null
                              ? Colors.green
                              : Colors.blue[700],
                        ),
                        label: Text(
                          pickedFile != null
                              ? _fileName(pickedFile!)
                              : 'Choose File',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: pickedFile != null
                                ? Colors.green[800]
                                : Colors.blue[700],
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: pickedFile != null
                                ? Colors.green
                                : Colors.blue,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                final result =
                                    await FilePicker.platform.pickFiles(
                                  type: FileType.any,
                                  allowMultiple: false,
                                );
                                if (result != null &&
                                    result.files.isNotEmpty) {
                                  final pf = result.files.first;
                                  setState(
                                    () => pickedFile = XFile(pf.path ?? ''),
                                  );
                                }
                              },
                      ),
                      if (pickedFile != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Selected: ${_fileName(pickedFile!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'Leave blank to keep the existing attachment.',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],

                    // ── Phone recharge extra fields ───────────────────────
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
                          setState(() => selectedHolderId = value);
                        },
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (selectedDate == null) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Please select a date'),
                              ),
                            );
                            return;
                          }

                          setState(() => isSaving = true);

                          try {
                            // ── Upload new file if picked ────────────────
                            String? newAttachmentUrl;
                            if (pickedFile != null &&
                                docTypeKeys.containsKey(documentType)) {
                              newAttachmentUrl =
                                  await employeeProvider
                                      .uploadDocumentAttachment(
                                        pickedFile!,
                                        employee.id,
                                        docTypeKeys[documentType]!,
                                      );
                            }

                            // ── Build updated employee with new date (+url) ─
                            EmployeeEntity updatedEmployee = employee;

                            String? _url(String? existing) =>
                                newAttachmentUrl ?? existing;

                            switch (documentType) {
                              case 'Iqama':
                                updatedEmployee = employee.copyWith(
                                  iqama: employee.iqama != null
                                      ? IqamaDocument(
                                          number: employee.iqama!.number,
                                          expiryDate: selectedDate!,
                                          attachmentUrl: _url(
                                            employee.iqama!.attachmentUrl,
                                          ),
                                        )
                                      : IqamaDocument(
                                          number: '',
                                          expiryDate: selectedDate!,
                                          attachmentUrl: newAttachmentUrl,
                                        ),
                                );
                                break;
                              case 'Bahrain Residence ID':
                                updatedEmployee = employee.copyWith(
                                  bahrainResidence:
                                      employee.bahrainResidence != null
                                          ? BahrainResidenceDocument(
                                              number: employee
                                                  .bahrainResidence!.number,
                                              expiryDate: selectedDate!,
                                              attachmentUrl: _url(
                                                employee.bahrainResidence!
                                                    .attachmentUrl,
                                              ),
                                            )
                                          : BahrainResidenceDocument(
                                              number: '',
                                              expiryDate: selectedDate!,
                                              attachmentUrl: newAttachmentUrl,
                                            ),
                                );
                                break;
                              case 'Health Insurance':
                                updatedEmployee = employee.copyWith(
                                  healthInsurance: employee.healthInsurance !=
                                          null
                                      ? HealthInsuranceDocument(
                                          expiryDate: selectedDate!,
                                          attachmentUrl: _url(
                                            employee.healthInsurance!
                                                .attachmentUrl,
                                          ),
                                        )
                                      : HealthInsuranceDocument(
                                          expiryDate: selectedDate!,
                                          attachmentUrl: newAttachmentUrl,
                                        ),
                                );
                                break;
                              case 'Driving License':
                                updatedEmployee = employee.copyWith(
                                  drivingLicense:
                                      employee.drivingLicense != null
                                          ? DrivingLicenseDocument(
                                              countryOfOrigin: employee
                                                  .drivingLicense!
                                                  .countryOfOrigin,
                                              number: employee
                                                  .drivingLicense!.number,
                                              expiryDate: selectedDate!,
                                              type: employee
                                                  .drivingLicense!.type,
                                              attachmentUrl: _url(
                                                employee.drivingLicense!
                                                    .attachmentUrl,
                                              ),
                                            )
                                          : DrivingLicenseDocument(
                                              countryOfOrigin: '',
                                              number: '',
                                              expiryDate: selectedDate!,
                                              type: DrivingLicenseType.private,
                                              attachmentUrl: newAttachmentUrl,
                                            ),
                                );
                                break;
                              case 'Passport':
                                updatedEmployee = employee.copyWith(
                                  passport: employee.passport != null
                                      ? PassportDocument(
                                          nameOnPassport: employee
                                              .passport!.nameOnPassport,
                                          number: employee.passport!.number,
                                          expiryDate: selectedDate!,
                                          attachmentUrl: _url(
                                            employee.passport!.attachmentUrl,
                                          ),
                                        )
                                      : PassportDocument(
                                          nameOnPassport: '',
                                          number: '',
                                          expiryDate: selectedDate!,
                                          attachmentUrl: newAttachmentUrl,
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
                                          attachmentUrl: _url(
                                            employee.saudiVisa!.attachmentUrl,
                                          ),
                                        )
                                      : VisaDocument(
                                          number: '',
                                          expiryDate: selectedDate!,
                                          attachmentUrl: newAttachmentUrl,
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
                                          attachmentUrl: _url(
                                            employee.bahrainVisa!.attachmentUrl,
                                          ),
                                        )
                                      : VisaDocument(
                                          number: '',
                                          expiryDate: selectedDate!,
                                          attachmentUrl: newAttachmentUrl,
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
                                          attachmentUrl: _url(
                                            employee.dubaiVisa!.attachmentUrl,
                                          ),
                                        )
                                      : VisaDocument(
                                          number: '',
                                          expiryDate: selectedDate!,
                                          attachmentUrl: newAttachmentUrl,
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
                                          attachmentUrl: _url(
                                            employee.qatarVisa!.attachmentUrl,
                                          ),
                                        )
                                      : VisaDocument(
                                          number: '',
                                          expiryDate: selectedDate!,
                                          attachmentUrl: newAttachmentUrl,
                                        ),
                                );
                                break;
                              default:
                                // Phone Recharge contacts
                                if (documentType.startsWith('Phone Recharge')) {
                                  final updatedContacts =
                                      employee.contacts.map((c) {
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

                            await employeeProvider
                                .updateEmployee(updatedEmployee);

                            if (ctx.mounted) {
                              final notifProvider =
                                  ctx.read<NotificationProvider>();
                              final vehicleProvider =
                                  ctx.read<VehicleProvider>();
                              final messenger = ScaffoldMessenger.of(ctx);
                              final navigator = Navigator.of(ctx);

                              await notifProvider.markAsRead(notification.id);
                              await notifProvider.refreshAlerts(
                                vehicles: vehicleProvider.vehicles,
                                maintenanceTypes:
                                    vehicleProvider.maintenanceTypes,
                              );

                              navigator.pop();
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Updated successfully'),
                                ),
                              );
                            }
                          } catch (e) {
                            setState(() => isSaving = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save'),
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

  static void _showVaultExpiryUpdateDialog(
    BuildContext context,
    NotificationEntity notification,
  ) async {
    final vaultProvider = context.read<VaultProvider>();
    final vaultData = vaultProvider.vaultData;
    if (vaultData == null) return;

    final documentType = notification.id.substring('vault_'.length).replaceAll('_', ' ');

    DateTime? selectedDate;
    XFile? pickedFile;
    bool isSaving = false;

    // Pre-fill existing date
    if (documentType == 'Commercial License') {
      selectedDate = vaultData.license.expiryDate;
    }

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
              title: Text('Update $documentType', style: const TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CustomDatePicker(
                    label: 'New Expiry Date',
                    date: selectedDate,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => selectedDate = picked);
                    },
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    icon: Icon(pickedFile != null ? Icons.check_circle : Icons.attach_file),
                    label: Text(pickedFile != null ? p.basename(pickedFile!.path) : 'Choose File'),
                    onPressed: isSaving ? null : () async {
                      final result = await FilePicker.platform.pickFiles(type: FileType.any);
                      if (result != null && result.files.isNotEmpty) {
                        setState(() => pickedFile = XFile(result.files.first.path!));
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: isSaving ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    if (selectedDate == null) return;
                    setState(() => isSaving = true);
                    try {
                      String? newUrl;
                      if (pickedFile != null) {
                        newUrl = await vaultProvider.uploadDocument(
                          pickedFile!,
                          'vault/company_documents',
                        );
                      }

                      VaultData updatedData = vaultData;
                      if (documentType == 'Commercial License') {
                        updatedData = vaultData.copyWith(
                          license: vaultData.license.copyWith(
                            expiryDate: selectedDate,
                            documentUrl: newUrl ?? vaultData.license.documentUrl,
                          ),
                        );
                      }

                      await vaultProvider.updateVaultData(updatedData);

                      if (ctx.mounted) {
                        final notifProvider = ctx.read<NotificationProvider>();
                        final vehicleProvider = ctx.read<VehicleProvider>();
                        await notifProvider.markAsRead(notification.id);
                        await notifProvider.refreshAlerts(
                          vehicles: vehicleProvider.vehicles,
                          maintenanceTypes: vehicleProvider.maintenanceTypes,
                        );
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Updated successfully')));
                      }
                    } catch (e) {
                      setState(() => isSaving = false);
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                    }
                  },
                  child: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static void _showVehicleExpiryUpdateDialog(
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

    final prefix = 'v_expiry_${relatedId}_';
    final documentType = notification.id.substring(prefix.length).replaceAll('_', ' ');

    DateTime? selectedDate;
    XFile? pickedFile;
    bool isSaving = false;

    // Map doc type to internal field
    final Map<String, String> docKeys = {
      'Istimara': 'istimara',
      'Insurance': 'insurance',
      'Fahas': 'fahas',
      'Bahrain Insurance': 'bahrain_insurance',
    };

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
              title: Text('Update $documentType', style: const TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CustomDatePicker(
                    label: 'New Expiry Date',
                    date: selectedDate,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => selectedDate = picked);
                    },
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    icon: Icon(pickedFile != null ? Icons.check_circle : Icons.attach_file),
                    label: Text(pickedFile != null ? p.basename(pickedFile!.path) : 'Choose File'),
                    onPressed: isSaving ? null : () async {
                      final result = await FilePicker.platform.pickFiles(type: FileType.any);
                      if (result != null && result.files.isNotEmpty) {
                        setState(() => pickedFile = XFile(result.files.first.path!));
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: isSaving ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    if (selectedDate == null) return;
                    setState(() => isSaving = true);
                    try {
                      String? newUrl;
                      if (pickedFile != null && docKeys.containsKey(documentType)) {
                        newUrl = await vehicleProvider.uploadVehicleDocument(
                          pickedFile!,
                          vehicle.id,
                          docKeys[documentType]!,
                        );
                      }

                      VehicleEntity updatedVehicle = vehicle;
                      String? url(String? existing) => newUrl ?? existing;

                      switch (documentType) {
                        case 'Istimara':
                          updatedVehicle = vehicle.copyWith(
                            registration: (vehicle.registration ??
                                    VehicleDocument(expiryDate: selectedDate!))
                                .copyWith(
                              expiryDate: selectedDate,
                              attachmentUrl: url(vehicle.registration?.attachmentUrl),
                            ),
                          );
                          break;
                        case 'Insurance':
                          updatedVehicle = vehicle.copyWith(
                            insurance: (vehicle.insurance ??
                                    VehicleDocument(expiryDate: selectedDate!))
                                .copyWith(
                              expiryDate: selectedDate,
                              attachmentUrl: url(vehicle.insurance?.attachmentUrl),
                            ),
                          );
                          break;
                        case 'Fahas':
                          updatedVehicle = vehicle.copyWith(
                            fahas: (vehicle.fahas ??
                                    VehicleDocument(expiryDate: selectedDate!))
                                .copyWith(
                              expiryDate: selectedDate,
                              attachmentUrl: url(vehicle.fahas?.attachmentUrl),
                            ),
                          );
                          break;
                        case 'Bahrain Insurance':
                          updatedVehicle = vehicle.copyWith(
                            bahrainInsurance: (vehicle.bahrainInsurance ??
                                    VehicleDocument(expiryDate: selectedDate!))
                                .copyWith(
                              expiryDate: selectedDate,
                              attachmentUrl:
                                  url(vehicle.bahrainInsurance?.attachmentUrl),
                            ),
                          );
                          break;
                      }

                      await vehicleProvider.updateVehicle(updatedVehicle);

                      if (ctx.mounted) {
                        final notifProvider = ctx.read<NotificationProvider>();
                        await notifProvider.markAsRead(notification.id);
                        await notifProvider.refreshAlerts(
                          vehicles: vehicleProvider.vehicles,
                          maintenanceTypes: vehicleProvider.maintenanceTypes,
                        );
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Updated successfully')));
                      }
                    } catch (e) {
                      setState(() => isSaving = false);
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                    }
                  },
                  child: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
