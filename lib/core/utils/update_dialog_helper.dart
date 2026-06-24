import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../features/notifications/domain/entities/notification_entity.dart';
import '../../features/employee/presentation/providers/employee_provider.dart';
import '../../features/vehicle/presentation/providers/vehicle_provider.dart';
import '../../features/notifications/presentation/providers/notification_provider.dart';
import '../../widgets/custom_date_picker.dart';
import '../../widgets/complete_follow_up_dialog.dart';
import '../../features/vehicle/domain/entities/vehicle_documents.dart';
import '../../features/employee/domain/entities/employee_contact.dart';
import '../../features/employee/domain/entities/employee_documents.dart';
import '../../features/employee/domain/entities/employee_entity.dart';
import '../../features/vehicle/domain/entities/vehicle_entity.dart';
import '../../features/xloop_vault/presentation/providers/vault_provider.dart';
import '../../features/xloop_vault/domain/entities/vault_data.dart';
import '../../features/vehicle/presentation/widgets/maintenance_extension_dialog.dart';
import '../../features/vehicle/domain/usecases/get_vehicle_maintenance_alerts_usecase.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../injection_container.dart';
import '../utils/activity_logger.dart';

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
    } else if (notification.id.startsWith('followup_')) {
      _showFollowUpResolveDialog(context, notification);
    }
  }

  /// Shows a dialog to update an employee document's expiry date, with all
  /// fields matching the real edit form (number, type, country, upload, etc.).
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

    // ── Document-specific controllers pre-filled from existing data ──────
    final numberController = TextEditingController();
    final nameController = TextEditingController(); // Passport name on passport
    final countryController =
        TextEditingController(); // Driving license country

    // Pre-fill visa type / license type from existing data
    VisaType selectedVisaType = VisaType.singleEntry;
    DrivingLicenseType selectedLicenseType = DrivingLicenseType.private;

    // Pre-fill all document-specific fields from existing employee data
    switch (documentType) {
      case 'Iqama':
        numberController.text = employee.iqama?.number ?? '';
        selectedDate = employee.iqama?.expiryDate;
        break;
      case 'Bahrain Residence ID':
        numberController.text = employee.bahrainResidence?.number ?? '';
        selectedDate = employee.bahrainResidence?.expiryDate;
        break;
      case 'Health Insurance':
        selectedDate = employee.healthInsurance?.expiryDate;
        break;
      case 'Passport':
        numberController.text = employee.passport?.number ?? '';
        nameController.text = employee.passport?.nameOnPassport ?? '';
        selectedDate = employee.passport?.expiryDate;
        break;
      case 'Saudi Visa':
        numberController.text = employee.saudiVisa?.number ?? '';
        selectedVisaType = employee.saudiVisa?.type ?? VisaType.singleEntry;
        selectedDate = employee.saudiVisa?.expiryDate;
        break;
      case 'Bahrain Visa':
        numberController.text = employee.bahrainVisa?.number ?? '';
        selectedVisaType = employee.bahrainVisa?.type ?? VisaType.singleEntry;
        selectedDate = employee.bahrainVisa?.expiryDate;
        break;
      case 'Dubai Visa':
        numberController.text = employee.dubaiVisa?.number ?? '';
        selectedVisaType = employee.dubaiVisa?.type ?? VisaType.singleEntry;
        selectedDate = employee.dubaiVisa?.expiryDate;
        break;
      case 'Qatar Visa':
        numberController.text = employee.qatarVisa?.number ?? '';
        selectedVisaType = employee.qatarVisa?.type ?? VisaType.singleEntry;
        selectedDate = employee.qatarVisa?.expiryDate;
        break;
      case 'Driving License':
        numberController.text = employee.drivingLicense?.number ?? '';
        countryController.text = employee.drivingLicense?.countryOfOrigin ?? '';
        selectedLicenseType =
            employee.drivingLicense?.type ?? DrivingLicenseType.private;
        selectedDate = employee.drivingLicense?.expiryDate;
        break;
      case 'Authorization':
        selectedDate = employee.authorization?.expiryDate;
        break;
      default:
        break;
    }

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

    // Which document types have a number field
    const docTypesWithNumber = {
      'Iqama',
      'Bahrain Residence ID',
      'Passport',
      'Saudi Visa',
      'Bahrain Visa',
      'Dubai Visa',
      'Qatar Visa',
      'Driving License',
    };

    // Which document types are visas (have visa type dropdown)
    const visaDocTypes = {
      'Saudi Visa',
      'Bahrain Visa',
      'Dubai Visa',
      'Qatar Visa',
    };

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
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Document number field ───────────────────────────
                      if (docTypesWithNumber.contains(documentType)) ...[
                        TextFormField(
                          controller: numberController,
                          decoration: InputDecoration(
                            labelText: documentType == 'Iqama'
                                ? 'Iqama Number'
                                : documentType == 'Bahrain Residence ID'
                                ? 'Residence ID Number'
                                : documentType == 'Passport'
                                ? 'Passport No.'
                                : documentType == 'Driving License'
                                ? 'License No.'
                                : 'Visa No.',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.numbers),
                          ),
                          keyboardType: TextInputType.text,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Passport: Name on Passport ─────────────────────
                      if (documentType == 'Passport') ...[
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Name on Passport',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Driving License: Country ───────────────────────
                      if (documentType == 'Driving License') ...[
                        TextFormField(
                          controller: countryController,
                          decoration: const InputDecoration(
                            labelText: 'Country',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.public),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Visa Type dropdown ─────────────────────────────
                      if (visaDocTypes.contains(documentType)) ...[
                        DropdownButtonFormField<VisaType>(
                          value: selectedVisaType,
                          decoration: const InputDecoration(
                            labelText: 'Visa Type',
                            border: OutlineInputBorder(),
                          ),
                          items: VisaType.values.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type.toString().split('.').last),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => selectedVisaType = val);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Driving License Type dropdown ──────────────────
                      if (documentType == 'Driving License') ...[
                        DropdownButtonFormField<DrivingLicenseType>(
                          value: selectedLicenseType,
                          decoration: const InputDecoration(
                            labelText: 'License Type',
                            border: OutlineInputBorder(),
                          ),
                          items: DrivingLicenseType.values.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type.toString().split('.').last),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => selectedLicenseType = val);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Expiry date picker ─────────────────────────────
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
                                  final result = await FilePicker.platform
                                      .pickFiles(
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
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
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
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'),
                            ),
                          ],
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
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setState(() => isSaving = true);

                          try {
                            // ── Upload new file if picked ────────────────
                            String? newAttachmentUrl;
                            if (pickedFile != null &&
                                docTypeKeys.containsKey(documentType)) {
                              newAttachmentUrl = await employeeProvider
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
                                if (selectedDate == null) {
                                  updatedEmployee = employee.copyWith(
                                    clearIqama: true,
                                  );
                                } else {
                                  updatedEmployee = employee.copyWith(
                                    iqama: IqamaDocument(
                                      number: numberController.text,
                                      expiryDate: selectedDate!,
                                      attachmentUrl: _url(
                                        employee.iqama?.attachmentUrl,
                                      ),
                                    ),
                                  );
                                }
                                break;
                              case 'Bahrain Residence ID':
                                if (selectedDate == null) {
                                  updatedEmployee = employee.copyWith(
                                    clearBahrainResidence: true,
                                  );
                                } else {
                                  updatedEmployee = employee.copyWith(
                                    bahrainResidence: BahrainResidenceDocument(
                                      number: numberController.text,
                                      expiryDate: selectedDate!,
                                      attachmentUrl: _url(
                                        employee
                                            .bahrainResidence
                                            ?.attachmentUrl,
                                      ),
                                    ),
                                  );
                                }
                                break;
                              case 'Health Insurance':
                                if (selectedDate == null) {
                                  updatedEmployee = employee.copyWith(
                                    clearHealthInsurance: true,
                                  );
                                } else {
                                  updatedEmployee = employee.copyWith(
                                    healthInsurance: HealthInsuranceDocument(
                                      expiryDate: selectedDate!,
                                      attachmentUrl: _url(
                                        employee.healthInsurance?.attachmentUrl,
                                      ),
                                    ),
                                  );
                                }
                                break;
                              case 'Driving License':
                                if (selectedDate == null) {
                                  updatedEmployee = employee.copyWith(
                                    clearDrivingLicense: true,
                                  );
                                } else {
                                  updatedEmployee = employee.copyWith(
                                    drivingLicense: DrivingLicenseDocument(
                                      countryOfOrigin: countryController.text,
                                      number: numberController.text,
                                      expiryDate: selectedDate!,
                                      type: selectedLicenseType,
                                      attachmentUrl: _url(
                                        employee.drivingLicense?.attachmentUrl,
                                      ),
                                    ),
                                  );
                                }
                                break;
                              case 'Passport':
                                if (selectedDate == null) {
                                  updatedEmployee = employee.copyWith(
                                    clearPassport: true,
                                  );
                                } else {
                                  updatedEmployee = employee.copyWith(
                                    passport: PassportDocument(
                                      nameOnPassport: nameController.text,
                                      number: numberController.text,
                                      expiryDate: selectedDate!,
                                      attachmentUrl: _url(
                                        employee.passport?.attachmentUrl,
                                      ),
                                    ),
                                  );
                                }
                                break;
                              case 'Saudi Visa':
                                if (selectedDate == null) {
                                  updatedEmployee = employee.copyWith(
                                    clearSaudiVisa: true,
                                  );
                                } else {
                                  updatedEmployee = employee.copyWith(
                                    saudiVisa: VisaDocument(
                                      number: numberController.text,
                                      expiryDate: selectedDate!,
                                      type: selectedVisaType,
                                      attachmentUrl: _url(
                                        employee.saudiVisa?.attachmentUrl,
                                      ),
                                    ),
                                  );
                                }
                                break;
                              case 'Bahrain Visa':
                                if (selectedDate == null) {
                                  updatedEmployee = employee.copyWith(
                                    clearBahrainVisa: true,
                                  );
                                } else {
                                  updatedEmployee = employee.copyWith(
                                    bahrainVisa: VisaDocument(
                                      number: numberController.text,
                                      expiryDate: selectedDate!,
                                      type: selectedVisaType,
                                      attachmentUrl: _url(
                                        employee.bahrainVisa?.attachmentUrl,
                                      ),
                                    ),
                                  );
                                }
                                break;
                              case 'Dubai Visa':
                                if (selectedDate == null) {
                                  updatedEmployee = employee.copyWith(
                                    clearDubaiVisa: true,
                                  );
                                } else {
                                  updatedEmployee = employee.copyWith(
                                    dubaiVisa: VisaDocument(
                                      number: numberController.text,
                                      expiryDate: selectedDate!,
                                      type: selectedVisaType,
                                      attachmentUrl: _url(
                                        employee.dubaiVisa?.attachmentUrl,
                                      ),
                                    ),
                                  );
                                }
                                break;
                              case 'Qatar Visa':
                                if (selectedDate == null) {
                                  updatedEmployee = employee.copyWith(
                                    clearQatarVisa: true,
                                  );
                                } else {
                                  updatedEmployee = employee.copyWith(
                                    qatarVisa: VisaDocument(
                                      number: numberController.text,
                                      expiryDate: selectedDate!,
                                      type: selectedVisaType,
                                      attachmentUrl: _url(
                                        employee.qatarVisa?.attachmentUrl,
                                      ),
                                    ),
                                  );
                                }
                                break;
                              default:
                                // Phone Recharge contacts
                                if (documentType.startsWith('Phone Recharge')) {
                                  final updatedContacts = employee.contacts.map(
                                    (c) {
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
                                    },
                                  ).toList();
                                  updatedEmployee = employee.copyWith(
                                    contacts: updatedContacts,
                                  );
                                }
                                break;
                            }

                            await employeeProvider.updateEmployee(
                              updatedEmployee,
                            );

                            if (ctx.mounted) {
                              final notifProvider = ctx
                                  .read<NotificationProvider>();
                              final vehicleProvider = ctx
                                  .read<VehicleProvider>();
                              final vaultProvider = ctx.read<VaultProvider>();
                              final messenger = ScaffoldMessenger.of(ctx);
                              final navigator = Navigator.of(ctx);

                              await notifProvider.markAsRead(notification.id);
                              await notifProvider.refreshAlerts(
                                vehicles: vehicleProvider.vehicles,
                                maintenanceTypes:
                                    vehicleProvider.maintenanceTypes,
                                employees: employeeProvider.employees,
                                employeeSettings: employeeProvider.settings,
                                vehicleSettings: vehicleProvider.settings,
                                vaultData: vaultProvider.vaultData,
                              );

                              await ActivityLogger.log(
                                ctx,
                                title: 'Employee Document Updated',
                                message:
                                    '${employee.fullName}\'s $documentType has been updated.',
                                relatedId: employee.id,
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

    bool isFollowUpRequired = false;
    final followUpReasonController = TextEditingController();
    DateTime? followUpDate;
    final followUpDateController = TextEditingController();
    final followUpKmController = TextEditingController();

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
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*'),
                        ),
                      ],
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: isFollowUpRequired,
                          onChanged: (val) {
                            setState(() {
                              isFollowUpRequired = val ?? false;
                            });
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'Requires Follow-up / Revisit (Recommended by mechanic/workshop)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isFollowUpRequired) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: followUpReasonController,
                        decoration: const InputDecoration(
                          labelText: 'Follow-up Reason',
                          hintText: 'e.g. Recheck brake pads, leak inspection',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: followUpDateController,
                              readOnly: true,
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      followUpDate ??
                                      DateTime.now().add(
                                        const Duration(days: 30),
                                      ),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setState(() {
                                    followUpDate = picked;
                                    followUpDateController.text =
                                        "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                                  });
                                }
                              },
                              decoration: const InputDecoration(
                                labelText: 'Follow-up Date (Optional)',
                                suffixIcon: Icon(Icons.calendar_today),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: followUpKmController,
                              decoration: const InputDecoration(
                                labelText: 'Follow-up Odometer (Optional)',
                                suffixText: 'km',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    final maintenanceUseCase =
                        sl<GetVehicleMaintenanceAlertsUseCase>();
                    final alerts = maintenanceUseCase(
                      vehicles: vehicleProvider.vehicles,
                      maintenanceTypes: vehicleProvider.maintenanceTypes,
                      includeAll: true,
                    );
                    final alert = alerts.firstWhere(
                      (a) =>
                          a.vehicle.id == vehicle.id &&
                          a.category.toLowerCase() == category.toLowerCase(),
                      orElse: () => VehicleMaintenanceAlert(
                        vehicle: vehicle,
                        category: category,
                        currentMileage: vehicle.currentOdometer ?? 0,
                        lastServiceMileage: 0,
                        nextServiceMileage: vehicle.currentOdometer ?? 0,
                        kmOverdue: 0,
                      ),
                    );

                    final extended = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => MaintenanceExtensionDialog(
                        vehicle: vehicle,
                        alert: alert,
                      ),
                    );
                    if (extended == true) {
                      if (context.mounted) {
                        final notifProvider = context
                            .read<NotificationProvider>();
                        final employeeProvider = context
                            .read<EmployeeProvider>();
                        final vaultProvider = context.read<VaultProvider>();
                        await notifProvider.markAsRead(notification.id);
                        await notifProvider.refreshAlerts(
                          vehicles: vehicleProvider.vehicles,
                          maintenanceTypes: vehicleProvider.maintenanceTypes,
                          employees: employeeProvider.employees,
                          employeeSettings: employeeProvider.settings,
                          vehicleSettings: vehicleProvider.settings,
                          vaultData: vaultProvider.vaultData,
                        );
                        Navigator.pop(context);
                      }
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFD97706),
                  ),
                  child: const Text('Extend Alert'),
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

                    final user = context.read<AuthProvider>().user;
                    final email = user?.email;
                    final username =
                        (user?.displayName != null &&
                            user!.displayName!.isNotEmpty)
                        ? user.displayName
                        : (email != null && email.contains('@')
                              ? email.split('@').first
                              : (email ?? 'System'));

                    final newRecord = MaintenanceRecord(
                      date: selectedDate!,
                      mileage: newMileage,
                      cost: double.tryParse(costController.text),
                      notes: notesController.text,
                      serviceType: category,
                      isFollowUpRequired: isFollowUpRequired,
                      followUpReason: isFollowUpRequired
                          ? followUpReasonController.text.trim()
                          : null,
                      nextServiceDate: isFollowUpRequired ? followUpDate : null,
                      nextServiceMileage: isFollowUpRequired
                          ? int.tryParse(followUpKmController.text)
                          : null,
                      isFollowUpCompleted: isFollowUpRequired ? false : null,
                      followUpIntervalKm: null,
                      followUpTimesCount: null,
                      followUpCompletions: isFollowUpRequired ? const [] : null,
                      performedBy: username,
                    );

                    final currentMaintenance =
                        vehicle.maintenance ?? const VehicleMaintenance();
                    VehicleMaintenance updatedMaintenance = currentMaintenance;

                    switch (category) {
                      case 'Engine Oil':
                      case 'Engine Oil Change':
                      case 'Engine Oil & Filter':
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
                      await ActivityLogger.log(
                        context,
                        title: 'Maintenance Updated',
                        message:
                            'Maintenance record for $category updated on vehicle ${vehicle.plateNumber}.',
                        relatedId: vehicle.id,
                      );

                      final notificationProvider = context
                          .read<NotificationProvider>();
                      final employeeProvider = context.read<EmployeeProvider>();
                      final vaultProvider = context.read<VaultProvider>();
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);

                      await notificationProvider.markAsRead(notification.id);
                      await notificationProvider.refreshAlerts(
                        vehicles: vehicleProvider.vehicles,
                        maintenanceTypes: vehicleProvider.maintenanceTypes,
                        employees: employeeProvider.employees,
                        employeeSettings: employeeProvider.settings,
                        vehicleSettings: vehicleProvider.settings,
                        vaultData: vaultProvider.vaultData,
                      );

                      navigator.pop();
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Updated successfully')),
                      );
                    }
                  },
                  child: const Text('Mark Completed'),
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

    final documentType = notification.id
        .substring('vault_'.length)
        .replaceAll('_', ' ');

    DateTime? selectedDate;
    XFile? pickedFile;
    bool isSaving = false;
    final regNoController = TextEditingController();

    // Pre-fill existing date
    if (documentType == 'Commercial License') {
      selectedDate = vaultData.license.expiryDate;
      regNoController.text = vaultData.license.registrationNo;
    }

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              title: Text(
                'Update $documentType',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (documentType == 'Commercial License') ...[
                    TextFormField(
                      controller: regNoController,
                      decoration: const InputDecoration(
                        labelText: 'Registration No.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
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
                    icon: Icon(
                      pickedFile != null
                          ? Icons.check_circle
                          : Icons.attach_file,
                    ),
                    label: Text(
                      pickedFile != null
                          ? p.basename(pickedFile!.path)
                          : 'Choose File',
                    ),
                    onPressed: isSaving
                        ? null
                        : () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.any,
                            );
                            if (result != null && result.files.isNotEmpty) {
                              setState(
                                () => pickedFile = XFile(
                                  result.files.first.path!,
                                ),
                              );
                            }
                          },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (selectedDate == null) return;
                          setState(() => isSaving = true);
                          try {
                            VaultDocument? newDoc;
                            if (pickedFile != null) {
                              newDoc = await vaultProvider.uploadDocument(
                                pickedFile!,
                                'vault/company_documents',
                              );
                            }

                            VaultData updatedData = vaultData;
                            if (documentType == 'Commercial License') {
                              updatedData = vaultData.copyWith(
                                license: vaultData.license.copyWith(
                                  expiryDate: selectedDate!,
                                  registrationNo: regNoController.text,
                                  document:
                                      newDoc ?? vaultData.license.document,
                                ),
                              );
                            } else if (documentType == 'VAT Certificate') {
                              updatedData = vaultData.copyWith(
                                vatCertificate: vaultData.vatCertificate
                                    .copyWith(
                                      document:
                                          newDoc ??
                                          vaultData.vatCertificate.document,
                                    ),
                              );
                            }

                            await vaultProvider.updateVaultData(updatedData);

                            if (ctx.mounted) {
                              final notifProvider = ctx
                                  .read<NotificationProvider>();
                              final vehicleProvider = ctx
                                  .read<VehicleProvider>();
                              final employeeProvider = ctx
                                  .read<EmployeeProvider>();
                              await notifProvider.markAsRead(notification.id);
                              await notifProvider.refreshAlerts(
                                vehicles: vehicleProvider.vehicles,
                                maintenanceTypes:
                                    vehicleProvider.maintenanceTypes,
                                employees: employeeProvider.employees,
                                employeeSettings: employeeProvider.settings,
                                vehicleSettings: vehicleProvider.settings,
                                vaultData: vaultProvider.vaultData,
                              );
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('Updated successfully'),
                                ),
                              );
                            }
                          } catch (e) {
                            setState(() => isSaving = false);
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
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
    final suffix = notification.id.substring(prefix.length);
    String documentType = suffix;
    String? driverId;
    if (suffix.startsWith('Tafweed_')) {
      documentType = 'Tafweed';
      driverId = suffix.substring('Tafweed_'.length);
    } else {
      documentType = documentType.replaceAll('_', ' ');
    }

    DateTime? selectedDate;
    XFile? pickedFile;
    bool isSaving = false;

    final employeeProvider = context.read<EmployeeProvider>();
    if (employeeProvider.employees.isEmpty) {
      await employeeProvider.fetchAllEmployees();
    }
    if (!context.mounted) return;

    TafweedRecord? existingTafweed;
    if (documentType == 'Tafweed' && driverId != null) {
      existingTafweed = vehicle.tafweeds?.cast<TafweedRecord?>().firstWhere(
        (t) => t?.driverId == driverId,
        orElse: () => null,
      );
    }

    String? selectedDriverId = driverId;
    DateTime? issuedDate = existingTafweed?.issuedDate ?? DateTime.now();
    selectedDate = existingTafweed?.expiryDate;

    // Map doc type to internal field
    final Map<String, String> docKeys = {
      'Istimara': 'istimara',
      'Insurance': 'insurance',
      'Fahas': 'fahas',
      'Bahrain Insurance': 'bahrain_insurance',
      'Tafweed': 'tafweed',
    };

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            // For Tafweed, the user has requested it to be strictly read-only in the vehicle details,
            // but updatable from Action Items.
            final supportsUpload = docKeys.containsKey(documentType);

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              title: Text(
                'Update $documentType',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (documentType == 'Tafweed') ...[
                        // Vehicle Details context
                        Text(
                          'Vehicle: ${vehicle.make} ${vehicle.model} (${vehicle.plateNumber})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        // Driver selector
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Authorized Driver',
                            border: OutlineInputBorder(),
                          ),
                          value: selectedDriverId,
                          items: employeeProvider.employees
                              .where((e) => e.isActive)
                              .map((e) {
                                return DropdownMenuItem(
                                  value: e.id,
                                  child: Text(e.fullName),
                                );
                              })
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              selectedDriverId = val;
                              if (val != null) {
                                final existing = vehicle.tafweeds
                                    ?.where((t) => t.driverId == val)
                                    .firstOrNull;
                                if (existing != null) {
                                  issuedDate = existing.issuedDate;
                                  selectedDate = existing.expiryDate;
                                } else {
                                  issuedDate = DateTime.now();
                                  selectedDate = null;
                                }
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        // Issue Date picker
                        CustomDatePicker(
                          label: 'Tafweed Issue Date',
                          date: issuedDate,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: issuedDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365 * 5),
                              ),
                            );
                            if (picked != null) {
                              setState(() => issuedDate = picked);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        // Expiry Date picker
                        CustomDatePicker(
                          label: 'Tafweed Expiry Date',
                          date: selectedDate,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: selectedDate ?? DateTime.now(),
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 365),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365 * 5),
                              ),
                            );
                            if (picked != null) {
                              setState(() => selectedDate = picked);
                            }
                          },
                        ),
                        if (selectedDriverId != null) ...[
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    final confirm =
                                        await showDialog<bool>(
                                          context: ctx,
                                          builder: (c) => AlertDialog(
                                            title: const Text(
                                              'Cancel Authorization',
                                            ),
                                            content: const Text(
                                              'Are you sure you want to cancel the current authorization? This will record the end date as today and move it to history.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(c, false),
                                                child: const Text('No'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () =>
                                                    Navigator.pop(c, true),
                                                child: const Text('Yes'),
                                              ),
                                            ],
                                          ),
                                        ) ??
                                        false;

                                    if (!confirm) return;

                                    setState(() => isSaving = true);
                                    try {
                                      final currentTafweeds =
                                          List<TafweedRecord>.from(
                                            vehicle.tafweeds ?? [],
                                          );
                                      final idx = currentTafweeds.indexWhere(
                                        (t) => t.driverId == selectedDriverId,
                                      );
                                      if (idx != -1) {
                                        final recordToArchive =
                                            currentTafweeds[idx];
                                        currentTafweeds.removeAt(idx);

                                        final updatedHistory =
                                            List<TafweedRecord>.from(
                                              vehicle.tafweedHistory ?? [],
                                            );
                                        updatedHistory.add(
                                          recordToArchive.copyWith(
                                            expiryDate: DateTime.now(),
                                          ),
                                        );

                                        final updatedVehicle = vehicle.copyWith(
                                          tafweeds: currentTafweeds,
                                          tafweedHistory: updatedHistory,
                                        );

                                        await vehicleProvider.updateVehicle(
                                          updatedVehicle,
                                        );
                                      }

                                      if (ctx.mounted) {
                                        await ActivityLogger.log(
                                          ctx,
                                          title: 'Authorization Cancelled',
                                          message:
                                              'Tafweed authorization for vehicle ${vehicle.plateNumber} has been cancelled.',
                                          relatedId: vehicle.id,
                                        );
                                        final notifProvider = ctx
                                            .read<NotificationProvider>();
                                        final employeeProvider = ctx
                                            .read<EmployeeProvider>();
                                        final vaultProvider = ctx
                                            .read<VaultProvider>();
                                        await notifProvider.markAsRead(
                                          notification.id,
                                        );
                                        await notifProvider.refreshAlerts(
                                          vehicles: vehicleProvider.vehicles,
                                          maintenanceTypes:
                                              vehicleProvider.maintenanceTypes,
                                          employees: employeeProvider.employees,
                                          employeeSettings:
                                              employeeProvider.settings,
                                          vehicleSettings:
                                              vehicleProvider.settings,
                                          vaultData: vaultProvider.vaultData,
                                        );
                                        if (!ctx.mounted) return;
                                        Navigator.pop(ctx);
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Authorization cancelled successfully',
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      setState(() => isSaving = false);
                                      if (!ctx.mounted) return;
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  },
                            icon: Icon(
                              Icons.cancel_outlined,
                              color: Colors.orange[700],
                              size: 18.sp,
                            ),
                            label: Text(
                              'Cancel Authorization',
                              style: TextStyle(
                                color: Colors.orange[700],
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.orange[50],
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 8.h,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                            ),
                          ),
                        ],
                      ] else ...[
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
                            if (picked != null)
                              setState(() => selectedDate = picked);
                          },
                        ),
                      ],
                      if (supportsUpload) ...[
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          icon: Icon(
                            pickedFile != null
                                ? Icons.check_circle
                                : Icons.attach_file,
                          ),
                          label: Text(
                            pickedFile != null
                                ? p.basename(pickedFile!.path)
                                : 'Choose File',
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final result = await FilePicker.platform
                                      .pickFiles(type: FileType.any);
                                  if (result != null &&
                                      result.files.isNotEmpty) {
                                    setState(
                                      () => pickedFile = XFile(
                                        result.files.first.path!,
                                      ),
                                    );
                                  }
                                },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setState(() => isSaving = true);
                          try {
                            String? newUrl;
                            if (pickedFile != null &&
                                docKeys.containsKey(documentType)) {
                              newUrl = await vehicleProvider
                                  .uploadVehicleDocument(
                                    pickedFile!,
                                    vehicle.id,
                                    docKeys[documentType]!,
                                  );
                            }

                            VehicleEntity updatedVehicle = vehicle;
                            String? url(String? existing) => newUrl ?? existing;

                            switch (documentType) {
                              case 'Istimara':
                                if (selectedDate == null) {
                                  updatedVehicle = vehicle.copyWith(
                                    clearRegistration: true,
                                  );
                                } else {
                                  updatedVehicle = vehicle.copyWith(
                                    registration:
                                        (vehicle.registration ??
                                                VehicleDocument(
                                                  expiryDate: selectedDate!,
                                                ))
                                            .copyWith(
                                              expiryDate: selectedDate!,
                                              attachmentUrl: url(
                                                vehicle
                                                    .registration
                                                    ?.attachmentUrl,
                                              ),
                                            ),
                                  );
                                }
                                break;
                              case 'Insurance':
                                if (selectedDate == null) {
                                  updatedVehicle = vehicle.copyWith(
                                    clearInsurance: true,
                                  );
                                } else {
                                  updatedVehicle = vehicle.copyWith(
                                    insurance:
                                        (vehicle.insurance ??
                                                VehicleDocument(
                                                  expiryDate: selectedDate!,
                                                ))
                                            .copyWith(
                                              expiryDate: selectedDate!,
                                              attachmentUrl: url(
                                                vehicle
                                                    .insurance
                                                    ?.attachmentUrl,
                                              ),
                                            ),
                                  );
                                }
                                break;
                              case 'Fahas':
                                if (selectedDate == null) {
                                  updatedVehicle = vehicle.copyWith(
                                    clearFahas: true,
                                  );
                                } else {
                                  updatedVehicle = vehicle.copyWith(
                                    fahas:
                                        (vehicle.fahas ??
                                                VehicleDocument(
                                                  expiryDate: selectedDate!,
                                                ))
                                            .copyWith(
                                              expiryDate: selectedDate!,
                                              attachmentUrl: url(
                                                vehicle.fahas?.attachmentUrl,
                                              ),
                                            ),
                                  );
                                }
                                break;
                              case 'Bahrain Insurance':
                                if (selectedDate == null) {
                                  updatedVehicle = vehicle.copyWith(
                                    clearBahrainInsurance: true,
                                  );
                                } else {
                                  updatedVehicle = vehicle.copyWith(
                                    bahrainInsurance:
                                        (vehicle.bahrainInsurance ??
                                                VehicleDocument(
                                                  expiryDate: selectedDate!,
                                                ))
                                            .copyWith(
                                              expiryDate: selectedDate!,
                                              attachmentUrl: url(
                                                vehicle
                                                    .bahrainInsurance
                                                    ?.attachmentUrl,
                                              ),
                                            ),
                                  );
                                }
                                break;
                              case 'Tafweed':
                                if (selectedDriverId == null) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please select an authorized driver',
                                      ),
                                    ),
                                  );
                                  setState(() => isSaving = false);
                                  return;
                                }
                                if (selectedDate == null) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please select an expiry date',
                                      ),
                                    ),
                                  );
                                  setState(() => isSaving = false);
                                  return;
                                }

                                // Check if selected driver is authorized on another vehicle
                                final existingVehicles = vehicleProvider
                                    .vehicles
                                    .where(
                                      (v) =>
                                          v.id != vehicle.id &&
                                          (v.tafweeds?.any(
                                                (t) =>
                                                    t.driverId ==
                                                    selectedDriverId,
                                              ) ??
                                              false),
                                    )
                                    .toList();

                                bool confirmSwap = true;
                                if (existingVehicles.isNotEmpty) {
                                  if (!ctx.mounted) return;
                                  confirmSwap =
                                      await showDialog<bool>(
                                        context: ctx,
                                        builder: (c) => AlertDialog(
                                          title: const Text(
                                            'Driver Already Authorized',
                                          ),
                                          content: Text(
                                            'This driver is currently authorized for '
                                            '${existingVehicles.first.make} ${existingVehicles.first.model} '
                                            '(${existingVehicles.first.plateNumber}). '
                                            'Do you want to swap the driver to this vehicle? '
                                            'They will be removed from the other vehicle\'s authorization '
                                            'and that record will be saved to history.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(c, false),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(c, true),
                                              child: const Text('Swap'),
                                            ),
                                          ],
                                        ),
                                      ) ??
                                      false;
                                }

                                if (!confirmSwap) {
                                  setState(() => isSaving = false);
                                  return;
                                }

                                // Archive from other vehicles if swap occurred
                                for (final otherVehicle in existingVehicles) {
                                  final recordToArchive = otherVehicle.tafweeds
                                      ?.where(
                                        (t) => t.driverId == selectedDriverId,
                                      )
                                      .firstOrNull;

                                  final updatedActiveTafweeds =
                                      List<TafweedRecord>.from(
                                        otherVehicle.tafweeds ?? [],
                                      )..removeWhere(
                                        (t) => t.driverId == selectedDriverId,
                                      );

                                  final updatedHistory =
                                      List<TafweedRecord>.from(
                                        otherVehicle.tafweedHistory ?? [],
                                      );
                                  if (recordToArchive != null) {
                                    updatedHistory.add(
                                      recordToArchive.copyWith(
                                        expiryDate: DateTime.now(),
                                      ),
                                    );
                                  }

                                  final updatedOtherVehicle = otherVehicle
                                      .copyWith(
                                        tafweeds: updatedActiveTafweeds,
                                        tafweedHistory: updatedHistory,
                                      );
                                  await vehicleProvider.updateVehicle(
                                    updatedOtherVehicle,
                                  );
                                }

                                final List<TafweedRecord> currentTafweeds =
                                    List.from(vehicle.tafweeds ?? []);

                                // Archive old driver's record if it was changed
                                List<TafweedRecord> updatedHistory = List.from(
                                  vehicle.tafweedHistory ?? [],
                                );
                                if (driverId != null &&
                                    driverId != selectedDriverId) {
                                  final oldIndex = currentTafweeds.indexWhere(
                                    (t) => t.driverId == driverId,
                                  );
                                  if (oldIndex != -1) {
                                    final oldRecord = currentTafweeds[oldIndex];
                                    currentTafweeds.removeAt(oldIndex);
                                    updatedHistory.add(
                                      oldRecord.copyWith(
                                        expiryDate: DateTime.now(),
                                      ),
                                    );
                                  }
                                }

                                final targetIndex = currentTafweeds.indexWhere(
                                  (t) => t.driverId == selectedDriverId,
                                );
                                final attachmentUrl = url(
                                  targetIndex != -1
                                      ? currentTafweeds[targetIndex]
                                            .attachmentUrl
                                      : null,
                                );
                                final notificationDays = targetIndex != -1
                                    ? currentTafweeds[targetIndex]
                                          .notificationDays
                                    : null;

                                final newRecord = TafweedRecord(
                                  driverId: selectedDriverId!,
                                  issuedDate: issuedDate ?? DateTime.now(),
                                  expiryDate: selectedDate!,
                                  attachmentUrl: attachmentUrl,
                                  notificationDays: notificationDays,
                                );

                                if (targetIndex != -1) {
                                  currentTafweeds[targetIndex] = newRecord;
                                } else {
                                  currentTafweeds.add(newRecord);
                                }

                                updatedVehicle = vehicle.copyWith(
                                  tafweeds: currentTafweeds,
                                  tafweedHistory: updatedHistory,
                                );
                                break;
                            }

                            await vehicleProvider.updateVehicle(updatedVehicle);

                            if (ctx.mounted) {
                              final notifProvider = ctx
                                  .read<NotificationProvider>();
                              final employeeProvider = ctx
                                  .read<EmployeeProvider>();
                              final vaultProvider = ctx.read<VaultProvider>();
                              await notifProvider.markAsRead(notification.id);
                              await notifProvider.refreshAlerts(
                                vehicles: vehicleProvider.vehicles,
                                maintenanceTypes:
                                    vehicleProvider.maintenanceTypes,
                                employees: employeeProvider.employees,
                                employeeSettings: employeeProvider.settings,
                                vehicleSettings: vehicleProvider.settings,
                                vaultData: vaultProvider.vaultData,
                              );
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('Updated successfully'),
                                ),
                              );
                            }
                          } catch (e) {
                            setState(() => isSaving = false);
                            if (!ctx.mounted) return;
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
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

  static void _showFollowUpResolveDialog(
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

    final parts = notification.id.split('_');
    final timestamp = parts.length > 2 ? int.tryParse(parts[2]) : null;

    MaintenanceRecord? record;
    if (timestamp != null) {
      record = vehicle.maintenanceHistory
          ?.cast<MaintenanceRecord?>()
          .firstWhere(
            (r) => r?.date.millisecondsSinceEpoch == timestamp,
            orElse: () => null,
          );
    }

    if (record == null) return;

    await showDialog(
      context: context,
      builder: (ctx) {
        return CompleteFollowUpDialog(vehicle: vehicle, record: record!);
      },
    );
  }
}
