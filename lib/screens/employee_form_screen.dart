import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:xloop_invoice/core/utils/app_snack_bar.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../features/employee/domain/entities/employee_contact.dart';

import 'package:provider/provider.dart';
import '../features/employee/domain/entities/employee_documents.dart';
import '../features/employee/domain/entities/employee_entity.dart';
import '../features/employee/domain/entities/external_vehicle_info.dart';
import '../features/employee/presentation/providers/employee_provider.dart';
import '../features/vehicle/domain/entities/vehicle_make_entity.dart';
import '../features/vehicle/presentation/providers/vehicle_provider.dart';
import '../widgets/custom_date_picker.dart';
import 'vehicle_makes_screen.dart';
import '../core/widgets/modern_app_bar.dart';
import '../core/utils/activity_logger.dart';
import '../core/utils/change_diff_helper.dart';

class EmployeeFormScreen extends StatefulWidget {
  // ... (rest of class)

  final EmployeeEntity? employee;

  const EmployeeFormScreen({super.key, this.employee});

  @override
  State<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends State<EmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _idNumberController;
  late TextEditingController _nationalityController;

  // External driver vehicle details (external drivers only). Make/model/year/
  // color are picked from the same Vehicle Master used by the fleet form —
  // only the plate number is free text.
  late TextEditingController _plateNumberController;
  final ValueNotifier<String?> _selectedVehicleMake = ValueNotifier(null);
  final ValueNotifier<String?> _selectedVehicleModel = ValueNotifier(null);
  final ValueNotifier<int?> _selectedVehicleYear = ValueNotifier(null);
  final ValueNotifier<String?> _selectedVehicleColor = ValueNotifier(null);
  final ValueNotifier<List<VehicleMakeEntity>> _allVehicleMakes =
      ValueNotifier([]);
  final ValueNotifier<List<VehicleModelDetailEntity>> _availableVehicleModels =
      ValueNotifier([]);
  final ValueNotifier<List<int>> _availableVehicleYears = ValueNotifier([]);
  final ValueNotifier<List<String>> _availableVehicleColors = ValueNotifier(
    [],
  );

  final ValueNotifier<String> _selectedPosition = ValueNotifier('Driver');
  final ValueNotifier<String> _selectedIdType = ValueNotifier('Iqama');
  final ValueNotifier<String> _selectedGender = ValueNotifier('Male');
  final ValueNotifier<String> _employmentType = ValueNotifier(
    EmploymentType.internal,
  );
  final ValueNotifier<DateTime?> _joinDate = ValueNotifier(null);
  final ValueNotifier<DateTime?> _birthDate = ValueNotifier(null);
  final ValueNotifier<bool> _isActive = ValueNotifier(true);
  final ValueNotifier<String?> _currentImageUrl = ValueNotifier(null);
  final ValueNotifier<XFile?> _pickedImage = ValueNotifier(null);
  final ImagePicker _picker = ImagePicker();

  // Document Specific Controllers
  late TextEditingController _iqamaNumberController;
  final ValueNotifier<DateTime?> _iqamaExpiryDate = ValueNotifier(null);

  late TextEditingController _bahrainResidenceNumberController;
  final ValueNotifier<DateTime?> _bahrainResidenceExpiryDate = ValueNotifier(
    null,
  );

  // Health Insurance
  final ValueNotifier<DateTime?> _healthInsuranceExpiryDate = ValueNotifier(null);
  final ValueNotifier<XFile?> _healthInsuranceAttachment = ValueNotifier(null);
  final ValueNotifier<String?> _healthInsuranceAttachmentUrl = ValueNotifier(null);

  late TextEditingController _passportNameController;
  late TextEditingController _passportNumberController;
  final ValueNotifier<DateTime?> _passportExpiryDate = ValueNotifier(null);

  late TextEditingController _saudiVisaNumberController;
  final ValueNotifier<DateTime?> _saudiVisaExpiryDate = ValueNotifier(null);
  final ValueNotifier<VisaType> _selectedSaudiVisaType = ValueNotifier(
    VisaType.singleEntry,
  );

  late TextEditingController _bahrainVisaNumberController;
  final ValueNotifier<DateTime?> _bahrainVisaExpiryDate = ValueNotifier(null);
  final ValueNotifier<VisaType> _selectedBahrainVisaType = ValueNotifier(
    VisaType.singleEntry,
  );

  late TextEditingController _dubaiVisaNumberController;
  final ValueNotifier<DateTime?> _dubaiVisaExpiryDate = ValueNotifier(null);
  final ValueNotifier<VisaType> _selectedDubaiVisaType = ValueNotifier(
    VisaType.singleEntry,
  );

  late TextEditingController _qatarVisaNumberController;
  final ValueNotifier<DateTime?> _qatarVisaExpiryDate = ValueNotifier(null);
  final ValueNotifier<VisaType> _selectedQatarVisaType = ValueNotifier(
    VisaType.singleEntry,
  );

  late TextEditingController _licenseCountryController;
  late TextEditingController _licenseNumberController;
  final ValueNotifier<DateTime?> _licenseExpiryDate = ValueNotifier(null);
  final ValueNotifier<DrivingLicenseType> _selectedLicenseType = ValueNotifier(
    DrivingLicenseType.private,
  );

  // Contacts state – each entry is a mutable map of controllers/value notifiers
  final ValueNotifier<List<_ContactEntry>> _contactEntries = ValueNotifier([]);

  // Attachment file pickers (one per document)
  final ValueNotifier<XFile?> _iqamaAttachment = ValueNotifier(null);
  final ValueNotifier<String?> _iqamaAttachmentUrl = ValueNotifier(null);

  final ValueNotifier<XFile?> _bahrainResidenceAttachment = ValueNotifier(null);
  final ValueNotifier<String?> _bahrainResidenceAttachmentUrl = ValueNotifier(
    null,
  );

  final ValueNotifier<XFile?> _passportAttachment = ValueNotifier(null);
  final ValueNotifier<String?> _passportAttachmentUrl = ValueNotifier(null);

  final ValueNotifier<XFile?> _saudiVisaAttachment = ValueNotifier(null);
  final ValueNotifier<String?> _saudiVisaAttachmentUrl = ValueNotifier(null);

  final ValueNotifier<XFile?> _bahrainVisaAttachment = ValueNotifier(null);
  final ValueNotifier<String?> _bahrainVisaAttachmentUrl = ValueNotifier(null);

  final ValueNotifier<XFile?> _dubaiVisaAttachment = ValueNotifier(null);
  final ValueNotifier<String?> _dubaiVisaAttachmentUrl = ValueNotifier(null);

  final ValueNotifier<XFile?> _qatarVisaAttachment = ValueNotifier(null);
  final ValueNotifier<String?> _qatarVisaAttachmentUrl = ValueNotifier(null);

  final ValueNotifier<XFile?> _licenseAttachment = ValueNotifier(null);
  final ValueNotifier<String?> _licenseAttachmentUrl = ValueNotifier(null);

  final ValueNotifier<bool> _isSaving = ValueNotifier(false);
  late final ValueNotifier<String> _primaryCountryCode;

  final List<String> _positions = [
    'CEO',
    'COO',
    'CFO',
    'Driver',
    'Senior Software Developer',
    'Administrative Officer',
    'Other',
  ];

  final List<String> _idTypes = ['Iqama', 'National ID', 'Passport'];
  final List<String> _genders = ['Male', 'Female'];

  /// True when the current form selections describe a driver, so the external
  /// vehicle block applies.
  bool get _isDriverPosition =>
      _selectedPosition.value.toLowerCase().contains('driver');

  bool get _isExternal => _employmentType.value == EmploymentType.external;

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    _nameController = TextEditingController(text: e?.fullName ?? '');
    _emailController = TextEditingController(text: e?.email ?? '');
    _phoneController = TextEditingController(text: e?.phoneNumber ?? '');
    _idNumberController = TextEditingController(text: e?.idNumber ?? '');
    _nationalityController = TextEditingController(text: e?.nationality ?? '');
    _plateNumberController = TextEditingController(
      text: e?.externalVehicle?.plateNumber ?? '',
    );
    _selectedVehicleMake.value = (e?.externalVehicle?.make.isNotEmpty ?? false)
        ? e!.externalVehicle!.make
        : null;
    _selectedVehicleModel.value =
        (e?.externalVehicle?.model.isNotEmpty ?? false)
        ? e!.externalVehicle!.model
        : null;
    _selectedVehicleYear.value = e?.externalVehicle?.year;
    _selectedVehicleColor.value =
        (e?.externalVehicle?.vehicleColor.isNotEmpty ?? false)
        ? e!.externalVehicle!.vehicleColor
        : null;
    _loadVehicleMakes();
    _primaryCountryCode = ValueNotifier(e?.countryCode ?? '+966');

    _iqamaNumberController = TextEditingController(
      text: e?.iqama?.number ?? '',
    );
    _iqamaExpiryDate.value = e?.iqama?.expiryDate;

    _bahrainResidenceNumberController = TextEditingController(
      text: e?.bahrainResidence?.number ?? '',
    );
    _bahrainResidenceExpiryDate.value = e?.bahrainResidence?.expiryDate;

    _healthInsuranceExpiryDate.value = e?.healthInsurance?.expiryDate;
    _healthInsuranceAttachmentUrl.value = e?.healthInsurance?.attachmentUrl;

    _passportNameController = TextEditingController(
      text: e?.passport?.nameOnPassport ?? '',
    );
    _passportNumberController = TextEditingController(
      text: e?.passport?.number ?? '',
    );
    _passportExpiryDate.value = e?.passport?.expiryDate;

    _saudiVisaNumberController = TextEditingController(
      text: e?.saudiVisa?.number ?? '',
    );
    _saudiVisaExpiryDate.value = e?.saudiVisa?.expiryDate;
    if (e?.saudiVisa?.type != null) {
      _selectedSaudiVisaType.value = e!.saudiVisa!.type!;
    }

    _bahrainVisaNumberController = TextEditingController(
      text: e?.bahrainVisa?.number ?? '',
    );
    _bahrainVisaExpiryDate.value = e?.bahrainVisa?.expiryDate;
    if (e?.bahrainVisa?.type != null) {
      _selectedBahrainVisaType.value = e!.bahrainVisa!.type!;
    }

    _dubaiVisaNumberController = TextEditingController(
      text: e?.dubaiVisa?.number ?? '',
    );
    _dubaiVisaExpiryDate.value = e?.dubaiVisa?.expiryDate;
    if (e?.dubaiVisa?.type != null) {
      _selectedDubaiVisaType.value = e!.dubaiVisa!.type!;
    }

    _qatarVisaNumberController = TextEditingController(
      text: e?.qatarVisa?.number ?? '',
    );
    _qatarVisaExpiryDate.value = e?.qatarVisa?.expiryDate;
    if (e?.qatarVisa?.type != null) {
      _selectedQatarVisaType.value = e!.qatarVisa!.type!;
    }

    _licenseCountryController = TextEditingController(
      text: e?.drivingLicense?.countryOfOrigin ?? '',
    );
    _licenseNumberController = TextEditingController(
      text: e?.drivingLicense?.number ?? '',
    );
    _licenseExpiryDate.value = e?.drivingLicense?.expiryDate;
    if (e?.drivingLicense?.type != null) {
      _selectedLicenseType.value = e!.drivingLicense!.type;
    }

    // Populate contacts from existing employee
    if (e != null && e.contacts.isNotEmpty) {
      _contactEntries.value = e.contacts
          .map((c) => _ContactEntry.fromContact(c))
          .toList();
    }

    // Pre-populate attachment URLs from existing employee
    _iqamaAttachmentUrl.value = e?.iqama?.attachmentUrl;
    _bahrainResidenceAttachmentUrl.value = e?.bahrainResidence?.attachmentUrl;
    _passportAttachmentUrl.value = e?.passport?.attachmentUrl;
    _saudiVisaAttachmentUrl.value = e?.saudiVisa?.attachmentUrl;
    _bahrainVisaAttachmentUrl.value = e?.bahrainVisa?.attachmentUrl;
    _dubaiVisaAttachmentUrl.value = e?.dubaiVisa?.attachmentUrl;
    _qatarVisaAttachmentUrl.value = e?.qatarVisa?.attachmentUrl;
    _licenseAttachmentUrl.value = e?.drivingLicense?.attachmentUrl;

    if (e != null) {
      if (_positions.contains(e.position)) {
        _selectedPosition.value = e.position;
      } else {
        _selectedPosition.value = 'Other';
      }

      if (_idTypes.contains(e.idType)) {
        _selectedIdType.value = e.idType;
      }

      if (_genders.contains(e.gender)) {
        _selectedGender.value = e.gender;
      }

      if (EmploymentType.values.contains(e.employmentType)) {
        _employmentType.value = e.employmentType;
      }

      _joinDate.value = e.joinDate;
      _birthDate.value = e.birthDate;
      _isActive.value = e.isActive;
      _currentImageUrl.value = e.imageUrl;
    }
  }

  /// Loads the Vehicle Master (same makes/models/colors as the fleet form) so
  /// an external driver's car is picked, not typed.
  Future<void> _loadVehicleMakes() async {
    final provider = context.read<VehicleProvider>();
    if (provider.vehicleMakes.isEmpty) {
      await provider.fetchAllVehicleMakes();
    }
    if (!mounted) return;
    _allVehicleMakes.value = provider.vehicleMakes;
    _updateAvailableVehicleOptions(_selectedVehicleMake.value);
  }

  /// Cascades model/year/color options from the selected make, mirroring the
  /// fleet Vehicle form. A value already on the record that isn't in the
  /// master (legacy data, or the make hasn't been extended yet) is kept
  /// selectable rather than silently dropped.
  void _updateAvailableVehicleOptions(String? makeName) {
    if (makeName == null) {
      _availableVehicleModels.value = [];
      _availableVehicleYears.value = [];
      _availableVehicleColors.value = [];
      return;
    }

    final make = _allVehicleMakes.value.firstWhere(
      (m) => m.name == makeName,
      orElse: () => const VehicleMakeEntity(id: '', name: ''),
    );

    final models = List<VehicleModelDetailEntity>.from(make.models);
    final years = List<int>.from(make.years);
    final colors = List<String>.from(make.colors);

    if (_selectedVehicleModel.value != null &&
        !models.any((m) => m.name == _selectedVehicleModel.value)) {
      models.add(
        VehicleModelDetailEntity(name: _selectedVehicleModel.value!, type: ''),
      );
    }
    if (_selectedVehicleYear.value != null &&
        !years.contains(_selectedVehicleYear.value)) {
      years.add(_selectedVehicleYear.value!);
    }
    if (_selectedVehicleColor.value != null &&
        !colors.contains(_selectedVehicleColor.value)) {
      colors.add(_selectedVehicleColor.value!);
    }

    _availableVehicleModels.value = models;
    _availableVehicleYears.value = years;
    _availableVehicleColors.value = colors;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _idNumberController.dispose();
    _nationalityController.dispose();
    _plateNumberController.dispose();
    _selectedVehicleMake.dispose();
    _selectedVehicleModel.dispose();
    _selectedVehicleYear.dispose();
    _selectedVehicleColor.dispose();
    _allVehicleMakes.dispose();
    _availableVehicleModels.dispose();
    _availableVehicleYears.dispose();
    _availableVehicleColors.dispose();
    _primaryCountryCode.dispose();
    _selectedPosition.dispose();
    _selectedIdType.dispose();
    _selectedGender.dispose();
    _employmentType.dispose();
    _joinDate.dispose();
    _birthDate.dispose();
    _isActive.dispose();
    _currentImageUrl.dispose();
    _pickedImage.dispose();

    _iqamaNumberController.dispose();
    _iqamaExpiryDate.dispose();
    _bahrainResidenceNumberController.dispose();
    _bahrainResidenceExpiryDate.dispose();
    _healthInsuranceExpiryDate.dispose();
    _healthInsuranceAttachment.dispose();
    _healthInsuranceAttachmentUrl.dispose();
    _passportNameController.dispose();
    _passportNumberController.dispose();
    _passportExpiryDate.dispose();
    _saudiVisaNumberController.dispose();
    _saudiVisaExpiryDate.dispose();
    _selectedSaudiVisaType.dispose();
    _bahrainVisaNumberController.dispose();
    _bahrainVisaExpiryDate.dispose();
    _selectedBahrainVisaType.dispose();
    _dubaiVisaNumberController.dispose();
    _dubaiVisaExpiryDate.dispose();
    _selectedDubaiVisaType.dispose();
    _qatarVisaNumberController.dispose();
    _qatarVisaExpiryDate.dispose();
    _selectedQatarVisaType.dispose();
    _licenseCountryController.dispose();
    _licenseNumberController.dispose();
    _licenseExpiryDate.dispose();
    _selectedLicenseType.dispose();

    // Dispose contact entries
    for (final entry in _contactEntries.value) {
      entry.phoneController.dispose();
      entry.labelController.dispose();
      entry.countryCode.dispose();
      entry.rechargeExpiry.dispose();
    }
    _contactEntries.dispose();

    _isSaving.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isJoinDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isJoinDate
          ? (_joinDate.value ?? DateTime.now())
          : (_birthDate.value ?? DateTime(1990)),
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      if (isJoinDate) {
        _joinDate.value = picked;
      } else {
        _birthDate.value = picked;
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        _pickedImage.value = image;
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        AppSnackBar.showError(context, 'Error picking image: $e');
      }
    }
  }

  /// Converting an existing internal employee to external discards their HR
  /// record, so make that explicit before saving.
  Future<bool> _confirmConversionToExternal() async {
    final existing = widget.employee;
    if (existing == null || !existing.isInternal || !_isExternal) return true;

    final hasRecordToLose = existing.email.isNotEmpty ||
        existing.idNumber.isNotEmpty ||
        existing.joinDate != null ||
        existing.birthDate != null ||
        existing.contacts.isNotEmpty ||
        existing.iqama != null ||
        existing.bahrainResidence != null ||
        existing.healthInsurance != null ||
        existing.drivingLicense != null ||
        existing.passport != null ||
        existing.saudiVisa != null ||
        existing.bahrainVisa != null ||
        existing.dubaiVisa != null ||
        existing.qatarVisa != null;
    if (!hasRecordToLose) return true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Convert to External?'),
        content: Text(
          '${existing.fullName} currently has a full internal record. '
          'External staff keep only name, gender, phone and nationality — '
          'their email, IDs, dates, SIM contacts and documents will be '
          'removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange[800]),
            child: const Text('Convert'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _saveEmployee() async {
    if (!_formKey.currentState!.validate()) return;
    if (!await _confirmConversionToExternal()) return;

    _isSaving.value = true;

    try {
      final id = widget.employee?.id ?? const Uuid().v4();
      final provider = context.read<EmployeeProvider>();

      // Upload profile image if changed
      String? imageUrl = _currentImageUrl.value;
      if (_pickedImage.value != null && mounted) {
        imageUrl = await provider.uploadEmployeeImage(_pickedImage.value!, id);
      }

      // Upload document attachments if new files were picked.
      // External staff have no document section, so nothing is ever picked.
      String? iqamaUrl = _iqamaAttachmentUrl.value;
      if (_iqamaAttachment.value != null && mounted) {
        iqamaUrl = await provider.uploadDocumentAttachment(
          _iqamaAttachment.value!,
          id,
          'iqama',
        );
      }

      String? bahrainResidenceUrl = _bahrainResidenceAttachmentUrl.value;
      if (_bahrainResidenceAttachment.value != null && mounted) {
        bahrainResidenceUrl = await provider.uploadDocumentAttachment(
          _bahrainResidenceAttachment.value!,
          id,
          'bahrain_residence',
        );
      }

      String? passportUrl = _passportAttachmentUrl.value;
      if (_passportAttachment.value != null && mounted) {
        passportUrl = await provider.uploadDocumentAttachment(
          _passportAttachment.value!,
          id,
          'passport',
        );
      }

      String? saudiVisaUrl = _saudiVisaAttachmentUrl.value;
      if (_saudiVisaAttachment.value != null && mounted) {
        saudiVisaUrl = await provider.uploadDocumentAttachment(
          _saudiVisaAttachment.value!,
          id,
          'saudi_visa',
        );
      }

      String? bahrainVisaUrl = _bahrainVisaAttachmentUrl.value;
      if (_bahrainVisaAttachment.value != null && mounted) {
        bahrainVisaUrl = await provider.uploadDocumentAttachment(
          _bahrainVisaAttachment.value!,
          id,
          'bahrain_visa',
        );
      }

      String? dubaiVisaUrl = _dubaiVisaAttachmentUrl.value;
      if (_dubaiVisaAttachment.value != null && mounted) {
        dubaiVisaUrl = await provider.uploadDocumentAttachment(
          _dubaiVisaAttachment.value!,
          id,
          'dubai_visa',
        );
      }

      String? qatarVisaUrl = _qatarVisaAttachmentUrl.value;
      if (_qatarVisaAttachment.value != null && mounted) {
        qatarVisaUrl = await provider.uploadDocumentAttachment(
          _qatarVisaAttachment.value!,
          id,
          'qatar_visa',
        );
      }

      String? licenseUrl = _licenseAttachmentUrl.value;
      if (_licenseAttachment.value != null && mounted) {
        licenseUrl = await provider.uploadDocumentAttachment(
          _licenseAttachment.value!,
          id,
          'driving_license',
        );
      }

      String? healthInsuranceUrl = _healthInsuranceAttachmentUrl.value;
      if (_healthInsuranceAttachment.value != null && mounted) {
        healthInsuranceUrl = await provider.uploadDocumentAttachment(
          _healthInsuranceAttachment.value!,
          id,
          'health_insurance',
        );
      }

      final isExternal = _isExternal;

      // External staff keep a minimal record — no company documents, no SIM
      // contacts. Hoisted here so the rule is stated once.
      final iqama = isExternal ||
              _iqamaNumberController.text.isEmpty ||
              _iqamaExpiryDate.value == null
          ? null
          : IqamaDocument(
              number: _iqamaNumberController.text.trim(),
              expiryDate: _iqamaExpiryDate.value!,
              attachmentUrl: iqamaUrl,
            );

      final bahrainResidence = isExternal ||
              _bahrainResidenceNumberController.text.isEmpty ||
              _bahrainResidenceExpiryDate.value == null
          ? null
          : BahrainResidenceDocument(
              number: _bahrainResidenceNumberController.text.trim(),
              expiryDate: _bahrainResidenceExpiryDate.value!,
              attachmentUrl: bahrainResidenceUrl,
            );

      final healthInsurance =
          isExternal || _healthInsuranceExpiryDate.value == null
              ? null
              : HealthInsuranceDocument(
                  expiryDate: _healthInsuranceExpiryDate.value!,
                  attachmentUrl: healthInsuranceUrl,
                );

      final passport = isExternal ||
              _passportNumberController.text.isEmpty ||
              _passportExpiryDate.value == null
          ? null
          : PassportDocument(
              nameOnPassport: _passportNameController.text.trim(),
              number: _passportNumberController.text.trim(),
              expiryDate: _passportExpiryDate.value!,
              attachmentUrl: passportUrl,
            );

      final saudiVisa = isExternal ||
              _saudiVisaNumberController.text.isEmpty ||
              _saudiVisaExpiryDate.value == null
          ? null
          : VisaDocument(
              number: _saudiVisaNumberController.text.trim(),
              expiryDate: _saudiVisaExpiryDate.value!,
              type: _selectedSaudiVisaType.value,
              attachmentUrl: saudiVisaUrl,
            );

      final bahrainVisa = isExternal ||
              _bahrainVisaNumberController.text.isEmpty ||
              _bahrainVisaExpiryDate.value == null
          ? null
          : VisaDocument(
              number: _bahrainVisaNumberController.text.trim(),
              expiryDate: _bahrainVisaExpiryDate.value!,
              type: _selectedBahrainVisaType.value,
              attachmentUrl: bahrainVisaUrl,
            );

      final dubaiVisa = isExternal ||
              _dubaiVisaNumberController.text.isEmpty ||
              _dubaiVisaExpiryDate.value == null
          ? null
          : VisaDocument(
              number: _dubaiVisaNumberController.text.trim(),
              expiryDate: _dubaiVisaExpiryDate.value!,
              type: _selectedDubaiVisaType.value,
              attachmentUrl: dubaiVisaUrl,
            );

      final qatarVisa = isExternal ||
              _qatarVisaNumberController.text.isEmpty ||
              _qatarVisaExpiryDate.value == null
          ? null
          : VisaDocument(
              number: _qatarVisaNumberController.text.trim(),
              expiryDate: _qatarVisaExpiryDate.value!,
              type: _selectedQatarVisaType.value,
              attachmentUrl: qatarVisaUrl,
            );

      final drivingLicense = isExternal ||
              _licenseNumberController.text.isEmpty ||
              _licenseExpiryDate.value == null
          ? null
          : DrivingLicenseDocument(
              countryOfOrigin: _licenseCountryController.text.trim(),
              number: _licenseNumberController.text.trim(),
              expiryDate: _licenseExpiryDate.value!,
              type: _selectedLicenseType.value,
              attachmentUrl: licenseUrl,
            );

      final newEmployee = EmployeeEntity(
        id: id,
        fullName: _nameController.text.trim(),
        position: _selectedPosition.value,
        // Everything below the minimal external set is deliberately blanked so
        // an Internal → External switch does not leave stale data behind.
        email: isExternal ? '' : _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        countryCode: _primaryCountryCode.value,
        nationality: _nationalityController.text.trim(),
        idType: isExternal ? '' : _selectedIdType.value,
        idNumber: isExternal ? '' : _idNumberController.text.trim(),
        joinDate: isExternal ? null : _joinDate.value,
        birthDate: isExternal ? null : _birthDate.value,
        gender: _selectedGender.value,
        employmentType: _employmentType.value,
        externalVehicle: isExternal && _isDriverPosition
            ? ExternalVehicleInfo(
                make: _selectedVehicleMake.value ?? '',
                model: _selectedVehicleModel.value ?? '',
                year: _selectedVehicleYear.value,
                vehicleColor: _selectedVehicleColor.value ?? '',
                plateNumber: _plateNumberController.text.trim(),
              )
            : null,
        isActive: _isActive.value,
        imageUrl: imageUrl,
        iqama: iqama,
        bahrainResidence: bahrainResidence,
        healthInsurance: healthInsurance,
        passport: passport,
        saudiVisa: saudiVisa,
        bahrainVisa: bahrainVisa,
        dubaiVisa: dubaiVisa,
        qatarVisa: qatarVisa,
        drivingLicense: drivingLicense,
        contacts: isExternal
            ? const []
            : _contactEntries.value.map((entry) => entry.toContact()).toList(),
      );

      if (mounted) {
        if (widget.employee == null) {
          await provider.addEmployee(newEmployee);
          if (mounted) {
            await ActivityLogger.log(
              context,
              title: 'Employee Added',
              message: 'Employee ${newEmployee.fullName} has been added.',
              relatedId: newEmployee.id,
            );
          }
        } else {
          await provider.updateEmployee(newEmployee);
          if (mounted) {
            final changeSummary = ChangeDiffHelper.describeEmployeeChanges(
              widget.employee!,
              newEmployee,
            );
            
            await ActivityLogger.log(
              context,
              title: 'Employee Updated',
              message: changeSummary != null 
                  ? 'Employee ${newEmployee.fullName} updated: $changeSummary.'
                  : 'Employee ${newEmployee.fullName} has been updated.',
              relatedId: newEmployee.id,
            );
          }
        }
      }



      if (mounted) {
        Navigator.pop(context, true);
        AppSnackBar.showSuccess(context, 'Employee saved successfully');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Error saving employee: $e');
      }
    } finally {
      if (mounted) {
        _isSaving.value = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: widget.employee == null ? 'Add New Employee' : 'Edit Employee',
      ),
      body: Form(
        key: _formKey,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Basic Info Section
                  _buildSectionTitle('Basic Information'),
                  SizedBox(height: 16.h),

                  // Image Picker
                  Center(
                    child: Stack(
                      children: [
                        ValueListenableBuilder<XFile?>(
                          valueListenable: _pickedImage,
                          builder: (context, pickedImage, _) {
                            return ValueListenableBuilder<String?>(
                              valueListenable: _currentImageUrl,
                              builder: (context, currentImageUrl, _) {
                                return CircleAvatar(
                                  radius: 50.r,
                                  backgroundColor: Colors.grey[200],
                                  backgroundImage: pickedImage != null
                                      ? (kIsWeb
                                            ? NetworkImage(pickedImage.path)
                                            : FileImage(File(pickedImage.path))
                                                  as ImageProvider)
                                      : (currentImageUrl != null
                                            ? CachedNetworkImageProvider(
                                                currentImageUrl,
                                              )
                                            : null),
                                  child:
                                      (pickedImage == null &&
                                          currentImageUrl == null)
                                      ? Icon(
                                          Icons.person,
                                          size: 50.sp,
                                          color: Colors.grey[400],
                                        )
                                      : null,
                                );
                              },
                            );
                          },
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap: _pickImage,
                            child: CircleAvatar(
                              radius: 18.r,
                              backgroundColor: Colors.blue,
                              child: Icon(
                                Icons.edit,
                                size: 18.sp,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),

                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _nameController,
                          label: 'Full Name',
                          icon: Icons.person,
                          validator: (v) =>
                              v!.isEmpty ? 'Please enter full name' : null,
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: ValueListenableBuilder<String>(
                          valueListenable: _selectedPosition,
                          builder: (context, selectedPosition, _) {
                            return _buildDropdown(
                              label: 'Position',
                              value: selectedPosition,
                              items: _positions,
                              onChanged: (val) {
                                _selectedPosition.value = val!;
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  ValueListenableBuilder<String>(
                    valueListenable: _employmentType,
                    builder: (context, employmentType, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDropdown(
                            label: 'Employment Type',
                            value: employmentType,
                            items: EmploymentType.values,
                            onChanged: (val) => _employmentType.value = val!,
                          ),
                          if (employmentType == EmploymentType.external) ...[
                            SizedBox(height: 8.h),
                            Text(
                              'External staff are contracted third parties — '
                              'only basic contact details are recorded.',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.orange[800],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),

                  SizedBox(height: 16.h),

                  // Internal staff carry the full HR record; external staff
                  // only the handful of fields collected below.
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      _employmentType,
                      _selectedPosition,
                    ]),
                    builder: (context, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _isExternal
                            ? _buildExternalSections()
                            : _buildInternalSections(),
                      );
                    },
                  ),

                  SizedBox(height: 24.h),
                  Divider(),
                  ValueListenableBuilder<bool>(
                    valueListenable: _isActive,
                    builder: (context, isActive, _) {
                      return SwitchListTile(
                        title: const Text('Active Employee'),
                        subtitle: const Text(
                          'Is this employee currently working?',
                        ),
                        value: isActive,
                        onChanged: (val) => _isActive.value = val,
                      );
                    },
                  ),

                  SizedBox(height: 32.h),
                  ValueListenableBuilder<bool>(
                    valueListenable: _isSaving,
                    builder: (context, isSaving, _) {
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isSaving ? null : _saveEmployee,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.blue[800],
                            foregroundColor: Colors.white,
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Save Employee',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Minimal record for contracted third parties: name, gender, phone and
  /// nationality — plus the car details when the person is an external driver.
  List<Widget> _buildExternalSections() {
    return [
      _buildSectionTitle('Contact Information'),
      SizedBox(height: 16.h),
      Row(
        children: [
          _buildCountryCodeDropdown(),
          SizedBox(width: 8.w),
          Expanded(
            child: _buildTextField(
              controller: _phoneController,
              label: 'Mobile No',
              icon: Icons.phone,
              validator: (v) =>
                  v!.trim().isEmpty ? 'Please enter mobile number' : null,
            ),
          ),
        ],
      ),
      SizedBox(height: 16.h),
      _buildSectionTitle('Personal Details'),
      SizedBox(height: 16.h),
      Row(
        children: [
          Expanded(
            child: ValueListenableBuilder<String>(
              valueListenable: _selectedGender,
              builder: (context, selectedGender, _) {
                return _buildDropdown(
                  label: 'Gender',
                  value: selectedGender,
                  items: _genders,
                  onChanged: (val) => _selectedGender.value = val!,
                );
              },
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: _buildTextField(
              controller: _nationalityController,
              label: 'Nationality',
              icon: Icons.flag,
            ),
          ),
        ],
      ),
      if (_isDriverPosition) ...[
        SizedBox(height: 24.h),
        const Divider(),
        SizedBox(height: 16.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle('Vehicle Details'),
            TextButton.icon(
              onPressed: _manageVehicleMakes,
              icon: const Icon(Icons.settings, size: 16),
              label: const Text('Manage Makes'),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ValueListenableBuilder<List<VehicleMakeEntity>>(
                  valueListenable: _allVehicleMakes,
                  builder: (context, makes, _) {
                    if (makes.isEmpty) {
                      return Text(
                        'No vehicle makes configured yet. Tap "Manage '
                        'Makes" above to add one.',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      );
                    }
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildVehicleMakeDropdown()),
                            SizedBox(width: 16.w),
                            Expanded(child: _buildVehicleModelDropdown()),
                          ],
                        ),
                        SizedBox(height: 16.h),
                        Row(
                          children: [
                            Expanded(child: _buildVehicleYearDropdown()),
                            SizedBox(width: 16.w),
                            Expanded(child: _buildVehicleColorDropdown()),
                          ],
                        ),
                        SizedBox(height: 16.h),
                      ],
                    );
                  },
                ),
                _buildTextField(
                  controller: _plateNumberController,
                  label: 'Car Plate No',
                  icon: Icons.confirmation_number,
                  validator: (v) => v!.trim().isEmpty
                      ? 'Please enter car plate number'
                      : null,
                ),
              ],
            ),
          ),
        ),
      ],
    ];
  }

  Widget _buildCountryCodeDropdown() {
    return SizedBox(
      width: 120.w,
      child: ValueListenableBuilder<String>(
        valueListenable: _primaryCountryCode,
        builder: (context, code, _) {
          return DropdownButtonFormField<String>(
            initialValue: code,
            decoration: InputDecoration(
              labelText: 'Code',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 8.w,
                vertical: 10.h,
              ),
            ),
            items: const [
              DropdownMenuItem(value: '+966', child: Text('+966 🇸🇦')),
              DropdownMenuItem(value: '+973', child: Text('+973 🇧🇭')),
              DropdownMenuItem(value: '+971', child: Text('+971 🇦🇪')),
              DropdownMenuItem(value: '+974', child: Text('+974 🇶🇦')),
              DropdownMenuItem(value: '+968', child: Text('+968 🇴🇲')),
              DropdownMenuItem(value: '+965', child: Text('+965 🇰🇼')),
              DropdownMenuItem(value: '+91', child: Text('+91 🇮🇳')),
            ],
            onChanged: (val) {
              if (val != null) {
                _primaryCountryCode.value = val;
              }
            },
          );
        },
      ),
    );
  }

  /// Opens Vehicle Master's make/model manager and refreshes the local list
  /// on return, so a make added there is available immediately.
  Future<void> _manageVehicleMakes() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const VehicleMakesScreen()),
    );
    if (mounted) _loadVehicleMakes();
  }

  // External-driver vehicle pickers — same Vehicle Master and cascading
  // make → model/year/color pattern as the fleet Vehicle form, so nothing is
  // typed freely except the plate number.

  Widget _buildVehicleMakeDropdown() {
    return AnimatedBuilder(
      animation: Listenable.merge([_selectedVehicleMake, _allVehicleMakes]),
      builder: (context, _) {
        return DropdownButtonFormField<String>(
          initialValue: _selectedVehicleMake.value,
          decoration: InputDecoration(
            labelText: 'Make',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
          items: _allVehicleMakes.value
              .map((m) => DropdownMenuItem(value: m.name, child: Text(m.name)))
              .toList(),
          onChanged: (val) {
            _selectedVehicleMake.value = val;
            _selectedVehicleModel.value = null;
            _selectedVehicleYear.value = null;
            _selectedVehicleColor.value = null;
            _updateAvailableVehicleOptions(val);
          },
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        );
      },
    );
  }

  Widget _buildVehicleModelDropdown() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _selectedVehicleMake,
        _selectedVehicleModel,
        _availableVehicleModels,
      ]),
      builder: (context, _) {
        return DropdownButtonFormField<String>(
          initialValue: _selectedVehicleModel.value,
          decoration: InputDecoration(
            labelText: 'Model',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
            enabled: _selectedVehicleMake.value != null,
          ),
          items: _availableVehicleModels.value
              .map((m) => DropdownMenuItem(value: m.name, child: Text(m.name)))
              .toList(),
          onChanged: _selectedVehicleMake.value == null
              ? null
              : (val) => _selectedVehicleModel.value = val,
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        );
      },
    );
  }

  Widget _buildVehicleYearDropdown() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _selectedVehicleMake,
        _selectedVehicleYear,
        _availableVehicleYears,
      ]),
      builder: (context, _) {
        return DropdownButtonFormField<int>(
          initialValue: _selectedVehicleYear.value,
          decoration: InputDecoration(
            labelText: 'Year',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
            enabled: _selectedVehicleMake.value != null,
          ),
          items: _availableVehicleYears.value
              .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
              .toList(),
          onChanged: _selectedVehicleMake.value == null
              ? null
              : (val) => _selectedVehicleYear.value = val,
        );
      },
    );
  }

  Widget _buildVehicleColorDropdown() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _selectedVehicleMake,
        _selectedVehicleColor,
        _availableVehicleColors,
      ]),
      builder: (context, _) {
        return DropdownButtonFormField<String>(
          initialValue: _selectedVehicleColor.value,
          decoration: InputDecoration(
            labelText: 'Color',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
            enabled: _selectedVehicleMake.value != null,
          ),
          items: _availableVehicleColors.value
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: _selectedVehicleMake.value == null
              ? null
              : (val) => _selectedVehicleColor.value = val,
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        );
      },
    );
  }

  /// Full HR record: contacts, IDs, dates and every document card.
  List<Widget> _buildInternalSections() {
    return [
                // Contact Info
                _buildSectionTitle('Contact Information'),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    _buildCountryCodeDropdown(),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: _buildTextField(
                        controller: _phoneController,
                        label: 'Primary Contact',
                        icon: Icons.phone,
                        validator: (v) =>
                            v!.isEmpty ? 'Please enter phone number' : null,
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        icon: Icons.email,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                _buildContactsSection(),
                SizedBox(height: 16.h),

                // Personal Details
                _buildSectionTitle('Personal Details'),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    Expanded(
                      child: ValueListenableBuilder<String>(
                        valueListenable: _selectedGender,
                        builder: (context, selectedGender, _) {
                          return _buildDropdown(
                            label: 'Gender',
                            value: selectedGender,
                            items: _genders,
                            onChanged: (val) => _selectedGender.value = val!,
                          );
                        },
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: _buildTextField(
                        controller: _nationalityController,
                        label: 'Nationality',
                        icon: Icons.flag,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    Expanded(
                      child: ValueListenableBuilder<String>(
                        valueListenable: _selectedIdType,
                        builder: (context, selectedIdType, _) {
                          return _buildDropdown(
                            label: 'ID Type',
                            value: selectedIdType,
                            items: _idTypes,
                            onChanged: (val) => _selectedIdType.value = val!,
                          );
                        },
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: _buildTextField(
                        controller: _idNumberController,
                        label: 'ID Number',
                        icon: Icons.numbers,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    Expanded(
                      child: ValueListenableBuilder<DateTime?>(
                        valueListenable: _birthDate,
                        builder: (context, birthDate, _) {
                          return CustomDatePicker(
                            label: 'Birth Date',
                            date: birthDate,
                            onTap: () => _selectDate(context, false),
                            onClear: () => _birthDate.value = null,
                          );
                        },
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: ValueListenableBuilder<DateTime?>(
                        valueListenable: _joinDate,
                        builder: (context, joinDate, _) {
                          return CustomDatePicker(
                            label: 'Join Date',
                            date: joinDate,
                            onTap: () => _selectDate(context, true),
                            onClear: () => _joinDate.value = null,
                          );
                        },
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 24.h),
                Divider(),
                SizedBox(height: 16.h),
                _buildSectionTitle('Documents & Expiries'),
                SizedBox(height: 16.h),

                // Iqama Card
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExpansionTile(
                    title: const Text(
                      'Iqama Details',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    leading: const Icon(Icons.badge, color: Colors.blue),
                    childrenPadding: const EdgeInsets.all(16),
                    children: [
                      _buildTextField(
                        controller: _iqamaNumberController,
                        label: 'Iqama Number',
                        icon: Icons.numbers,
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        children: [
                          Expanded(
                            child: ValueListenableBuilder<DateTime?>(
                              valueListenable: _iqamaExpiryDate,
                              builder: (context, date, _) {
                                return CustomDatePicker(
                                  label: 'Iqama Expiry',
                                  date: date,
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: date ?? DateTime.now(),
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      _iqamaExpiryDate.value = picked;
                                    }
                                  },
                                  onClear: () =>
                                      _iqamaExpiryDate.value = null,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      _buildAttachmentPicker(
                        label: 'Iqama Scan / Copy',
                        pickedFileNotifier: _iqamaAttachment,
                        existingUrlNotifier: _iqamaAttachmentUrl,
                      ),
                    ],
                  ),
                ),

                // Bahrain Residence Card
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExpansionTile(
                    title: const Text(
                      'Bahrain Residence Details',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    leading: const Icon(Icons.badge, color: Colors.indigo),
                    childrenPadding: const EdgeInsets.all(16),
                    children: [
                      _buildTextField(
                        controller: _bahrainResidenceNumberController,
                        label: 'Residence ID Number',
                        icon: Icons.numbers,
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        children: [
                          Expanded(
                            child: ValueListenableBuilder<DateTime?>(
                              valueListenable: _bahrainResidenceExpiryDate,
                              builder: (context, date, _) {
                                return CustomDatePicker(
                                  label: 'ID Expiry',
                                  date: date,
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: date ?? DateTime.now(),
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      _bahrainResidenceExpiryDate.value =
                                          picked;
                                    }
                                  },
                                  onClear: () =>
                                      _bahrainResidenceExpiryDate.value =
                                          null,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      _buildAttachmentPicker(
                        label: 'Residence ID Scan / Copy',
                        pickedFileNotifier: _bahrainResidenceAttachment,
                        existingUrlNotifier: _bahrainResidenceAttachmentUrl,
                      ),
                    ],
                  ),
                ),

                // Health Insurance Card
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExpansionTile(
                    title: const Text(
                      'Health Insurance Details',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    leading: const Icon(
                      Icons.health_and_safety,
                      color: Colors.red,
                    ),
                    childrenPadding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ValueListenableBuilder<DateTime?>(
                              valueListenable: _healthInsuranceExpiryDate,
                              builder: (context, date, _) {
                                return CustomDatePicker(
                                  label: 'Health Insurance Expiry',
                                  date: date,
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: date ?? DateTime.now(),
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      _healthInsuranceExpiryDate.value =
                                          picked;
                                    }
                                  },
                                  onClear: () =>
                                      _healthInsuranceExpiryDate.value = null,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      _buildAttachmentPicker(
                        label: 'Health Insurance Card Scan / Copy',
                        pickedFileNotifier: _healthInsuranceAttachment,
                        existingUrlNotifier: _healthInsuranceAttachmentUrl,
                      ),
                    ],
                  ),
                ),

                // Passport Card
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExpansionTile(
                    title: const Text(
                      'Passport Details',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    leading: const Icon(Icons.book, color: Colors.orange),
                    childrenPadding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _passportNumberController,
                              label: 'Passport No.',
                              icon: Icons.numbers,
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: ValueListenableBuilder<DateTime?>(
                              valueListenable: _passportExpiryDate,
                              builder: (context, date, _) {
                                return CustomDatePicker(
                                  label: 'Expiry',
                                  date: date,
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: date ?? DateTime.now(),
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      _passportExpiryDate.value = picked;
                                    }
                                  },
                                  onClear: () =>
                                      _passportExpiryDate.value = null,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _passportNameController,
                              label: 'Name on Passport',
                              icon: Icons.person,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      _buildAttachmentPicker(
                        label: 'Passport Scan / Copy',
                        pickedFileNotifier: _passportAttachment,
                        existingUrlNotifier: _passportAttachmentUrl,
                      ),
                    ],
                  ),
                ),

                // Saudi Visa Card
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExpansionTile(
                    title: const Text(
                      'Saudi Visa Details',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    leading: const Icon(
                      Icons.airplane_ticket,
                      color: Colors.green,
                    ),
                    childrenPadding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _saudiVisaNumberController,
                              label: 'Visa No.',
                              icon: Icons.numbers,
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: ValueListenableBuilder<DateTime?>(
                              valueListenable: _saudiVisaExpiryDate,
                              builder: (context, date, _) {
                                return CustomDatePicker(
                                  label: 'Expiry',
                                  date: date,
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: date ?? DateTime.now(),
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      _saudiVisaExpiryDate.value = picked;
                                    }
                                  },
                                  onClear: () =>
                                      _saudiVisaExpiryDate.value = null,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        children: [
                          Expanded(
                            child: ValueListenableBuilder<VisaType>(
                              valueListenable: _selectedSaudiVisaType,
                              builder: (context, type, _) {
                                return _buildDropdown(
                                  label: 'Visa Type',
                                  value: type.toString().split('.').last,
                                  items: VisaType.values
                                      .map(
                                        (e) => e.toString().split('.').last,
                                      )
                                      .toList(),
                                  onChanged: (val) {
                                    _selectedSaudiVisaType.value = VisaType
                                        .values
                                        .firstWhere(
                                          (e) =>
                                              e.toString().split('.').last ==
                                              val,
                                        );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      _buildAttachmentPicker(
                        label: 'Saudi Visa Scan / Copy',
                        pickedFileNotifier: _saudiVisaAttachment,
                        existingUrlNotifier: _saudiVisaAttachmentUrl,
                      ),
                    ],
                  ),
                ),

                // Bahrain Visa Card
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExpansionTile(
                    title: const Text(
                      'Bahrain Visa Details',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    leading: const Icon(
                      Icons.airplane_ticket_outlined,
                      color: Colors.teal,
                    ),
                    childrenPadding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _bahrainVisaNumberController,
                              label: 'Visa No.',
                              icon: Icons.numbers,
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: ValueListenableBuilder<DateTime?>(
                              valueListenable: _bahrainVisaExpiryDate,
                              builder: (context, date, _) {
                                return CustomDatePicker(
                                  label: 'Expiry',
                                  date: date,
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: date ?? DateTime.now(),
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      _bahrainVisaExpiryDate.value = picked;
                                    }
                                  },
                                  onClear: () =>
                                      _bahrainVisaExpiryDate.value = null,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        children: [
                          Expanded(
                            child: ValueListenableBuilder<VisaType>(
                              valueListenable: _selectedBahrainVisaType,
                              builder: (context, type, _) {
                                return _buildDropdown(
                                  label: 'Visa Type',
                                  value: type.toString().split('.').last,
                                  items: VisaType.values
                                      .map(
                                        (e) => e.toString().split('.').last,
                                      )
                                      .toList(),
                                  onChanged: (val) {
                                    _selectedBahrainVisaType.value = VisaType
                                        .values
                                        .firstWhere(
                                          (e) =>
                                              e.toString().split('.').last ==
                                              val,
                                        );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      _buildAttachmentPicker(
                        label: 'Bahrain Visa Scan / Copy',
                        pickedFileNotifier: _bahrainVisaAttachment,
                        existingUrlNotifier: _bahrainVisaAttachmentUrl,
                      ),
                    ],
                  ),
                ),

                // Dubai Visa Card
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExpansionTile(
                    title: const Text(
                      'Dubai Visa Details',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    leading: const Icon(
                      Icons.flight_takeoff,
                      color: Colors.amber,
                    ),
                    childrenPadding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _dubaiVisaNumberController,
                              label: 'Visa No.',
                              icon: Icons.numbers,
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: ValueListenableBuilder<DateTime?>(
                              valueListenable: _dubaiVisaExpiryDate,
                              builder: (context, date, _) {
                                return CustomDatePicker(
                                  label: 'Expiry',
                                  date: date,
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: date ?? DateTime.now(),
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      _dubaiVisaExpiryDate.value = picked;
                                    }
                                  },
                                  onClear: () =>
                                      _dubaiVisaExpiryDate.value = null,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        children: [
                          Expanded(
                            child: ValueListenableBuilder<VisaType>(
                              valueListenable: _selectedDubaiVisaType,
                              builder: (context, type, _) {
                                return _buildDropdown(
                                  label: 'Visa Type',
                                  value: type.toString().split('.').last,
                                  items: VisaType.values
                                      .map(
                                        (e) => e.toString().split('.').last,
                                      )
                                      .toList(),
                                  onChanged: (val) {
                                    _selectedDubaiVisaType.value = VisaType
                                        .values
                                        .firstWhere(
                                          (e) =>
                                              e.toString().split('.').last ==
                                              val,
                                        );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      _buildAttachmentPicker(
                        label: 'Dubai Visa Scan / Copy',
                        pickedFileNotifier: _dubaiVisaAttachment,
                        existingUrlNotifier: _dubaiVisaAttachmentUrl,
                      ),
                    ],
                  ),
                ),

                // Qatar Visa Card
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExpansionTile(
                    title: const Text(
                      'Qatar Visa Details',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    leading: const Icon(
                      Icons.flight_land,
                      color: Colors.deepPurple,
                    ),
                    childrenPadding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _qatarVisaNumberController,
                              label: 'Visa No.',
                              icon: Icons.numbers,
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: ValueListenableBuilder<DateTime?>(
                              valueListenable: _qatarVisaExpiryDate,
                              builder: (context, date, _) {
                                return CustomDatePicker(
                                  label: 'Expiry',
                                  date: date,
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: date ?? DateTime.now(),
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      _qatarVisaExpiryDate.value = picked;
                                    }
                                  },
                                  onClear: () =>
                                      _qatarVisaExpiryDate.value = null,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        children: [
                          Expanded(
                            child: ValueListenableBuilder<VisaType>(
                              valueListenable: _selectedQatarVisaType,
                              builder: (context, type, _) {
                                return _buildDropdown(
                                  label: 'Visa Type',
                                  value: type.toString().split('.').last,
                                  items: VisaType.values
                                      .map(
                                        (e) => e.toString().split('.').last,
                                      )
                                      .toList(),
                                  onChanged: (val) {
                                    _selectedQatarVisaType.value = VisaType
                                        .values
                                        .firstWhere(
                                          (e) =>
                                              e.toString().split('.').last ==
                                              val,
                                        );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      _buildAttachmentPicker(
                        label: 'Qatar Visa Scan / Copy',
                        pickedFileNotifier: _qatarVisaAttachment,
                        existingUrlNotifier: _qatarVisaAttachmentUrl,
                      ),
                    ],
                  ),
                ),

                // Driving License Card
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExpansionTile(
                    title: const Text(
                      'Driving License Details',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    leading: const Icon(
                      Icons.drive_eta,
                      color: Colors.indigo,
                    ),
                    childrenPadding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _licenseNumberController,
                              label: 'License No.',
                              icon: Icons.numbers,
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: ValueListenableBuilder<DateTime?>(
                              valueListenable: _licenseExpiryDate,
                              builder: (context, date, _) {
                                return CustomDatePicker(
                                  label: 'Expiry',
                                  date: date,
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: date ?? DateTime.now(),
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      _licenseExpiryDate.value = picked;
                                    }
                                  },
                                  onClear: () =>
                                      _licenseExpiryDate.value = null,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _licenseCountryController,
                              label: 'Country',
                              icon: Icons.public,
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: ValueListenableBuilder<DrivingLicenseType>(
                              valueListenable: _selectedLicenseType,
                              builder: (context, type, _) {
                                return _buildDropdown(
                                  label: 'License Type',
                                  value: type.toString().split('.').last,
                                  items: DrivingLicenseType.values
                                      .map(
                                        (e) => e.toString().split('.').last,
                                      )
                                      .toList(),
                                  onChanged: (val) {
                                    _selectedLicenseType.value =
                                        DrivingLicenseType.values.firstWhere(
                                          (e) =>
                                              e.toString().split('.').last ==
                                              val,
                                        );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      _buildAttachmentPicker(
                        label: 'Driving License Scan / Copy',
                        pickedFileNotifier: _licenseAttachment,
                        existingUrlNotifier: _licenseAttachmentUrl,
                      ),
                    ],
                  ),
                ),
    ];
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18.sp,
        fontWeight: FontWeight.bold,
        color: Colors.blue[900],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    // Automatically derive inputFormatters from keyboardType
    List<TextInputFormatter>? formatters;
    if (keyboardType == TextInputType.number) {
      formatters = [FilteringTextInputFormatter.digitsOnly];
    } else if (keyboardType == TextInputType.phone) {
      formatters = [FilteringTextInputFormatter.digitsOnly];
    } else if (keyboardType != null &&
        keyboardType.toString().contains('number')) {
      formatters = [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ];
    }
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
    );
  }

  /// A reusable widget that lets the user optionally pick a document scan/image.
  ///
  /// [pickedFileNotifier]  – holds the locally picked [XFile] (before upload).
  /// [existingUrlNotifier] – holds the already-uploaded URL string, if any.
  Widget _buildAttachmentPicker({
    required String label,
    required ValueNotifier<XFile?> pickedFileNotifier,
    required ValueNotifier<String?> existingUrlNotifier,
  }) {
    return ValueListenableBuilder<XFile?>(
      valueListenable: pickedFileNotifier,
      builder: (context, pickedFile, _) {
        return ValueListenableBuilder<String?>(
          valueListenable: existingUrlNotifier,
          builder: (context, existingUrl, _) {
            final hasExisting = existingUrl != null && existingUrl.isNotEmpty;
            final hasPicked = pickedFile != null;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.attach_file_rounded,
                      size: 16.sp,
                      color: Colors.grey[600],
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    // Clear button if something is picked/existing
                    if (hasPicked || hasExisting)
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 16.sp,
                          color: Colors.redAccent,
                        ),
                        tooltip: 'Remove attachment',
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          pickedFileNotifier.value = null;
                          existingUrlNotifier.value = null;
                        },
                      ),
                  ],
                ),
                SizedBox(height: 6.h),
                // Status / display area
                if (hasPicked)
                  _attachmentChip(
                    icon: Icons.insert_drive_file_outlined,
                    text: pickedFile.name,
                    color: Colors.green.shade700,
                  )
                else if (hasExisting)
                  _attachmentChip(
                    icon: Icons.cloud_done_outlined,
                    text: 'View existing scan',
                    color: Colors.blue.shade700,
                    onTap: () {
                      // Could open a web view in a future iteration
                    },
                  ),
                SizedBox(height: 6.h),
                // Pick button
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['jpg', 'png', 'jpeg', 'pdf'],
                        withData: kIsWeb,
                      );
                      if (result != null) {
                        final platformFile = result.files.single;
                        if (kIsWeb && platformFile.bytes != null) {
                          pickedFileNotifier.value = XFile.fromData(
                            platformFile.bytes!,
                            name: platformFile.name,
                          );
                        } else if (platformFile.path != null) {
                          pickedFileNotifier.value = XFile(platformFile.path!, name: platformFile.name);
                        }
                      }
                    } catch (e) {
                      debugPrint('Error picking file: $e');
                    }
                  },
                  icon: Icon(Icons.upload_file_rounded, size: 16.sp),
                  label: Text(
                    hasPicked || hasExisting
                        ? 'Change File'
                        : 'Upload Scan (Optional)',
                    style: TextStyle(fontSize: 12.sp),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 8.h,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _attachmentChip({
    required IconData icon,
    required String text,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6.r),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14.sp, color: color),
            SizedBox(width: 6.w),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactsSection() {
    return ValueListenableBuilder<List<_ContactEntry>>(
      valueListenable: _contactEntries,
      builder: (context, entries, _) {
        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.sim_card,
                          color: Colors.blue[700],
                          size: 20.sp,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Secondary SIM Cards',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () {
                        final updated = List<_ContactEntry>.from(entries)
                          ..add(_ContactEntry.empty());
                        _contactEntries.value = updated;
                      },
                      icon: Icon(Icons.add, size: 18.sp),
                      label: Text('Add', style: TextStyle(fontSize: 13.sp)),
                    ),
                  ],
                ),
                if (entries.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.h),
                    child: Center(
                      child: Text(
                        'No contacts added. Tap "Add" to add a SIM.',
                        style: TextStyle(fontSize: 13.sp, color: Colors.grey),
                      ),
                    ),
                  ),
                ...entries.asMap().entries.map((mapEntry) {
                  final index = mapEntry.key;
                  final entry = mapEntry.value;
                  return _buildContactEntryCard(entry, index);
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContactEntryCard(_ContactEntry entry, int index) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '#${index + 1}',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  final updated = List<_ContactEntry>.from(
                    _contactEntries.value,
                  )..removeAt(index);
                  entry.phoneController.dispose();
                  entry.labelController.dispose();
                  entry.countryCode.dispose();
                  entry.rechargeExpiry.dispose();
                  _contactEntries.value = updated;
                },
                icon: Icon(Icons.delete, color: Colors.red, size: 20.sp),
                tooltip: 'Remove Contact',
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              SizedBox(
                width: 120.w,
                child: DropdownButtonFormField<String>(
                  value: entry.countryCode.value,
                  decoration: InputDecoration(
                    labelText: 'Code',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 10.h,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: '+966', child: Text('+966 🇸🇦')),
                    DropdownMenuItem(value: '+973', child: Text('+973 🇧🇭')),
                    DropdownMenuItem(value: '+971', child: Text('+971 🇦🇪')),
                    DropdownMenuItem(value: '+974', child: Text('+974 🇶🇦')),
                    DropdownMenuItem(value: '+968', child: Text('+968 🇴🇲')),
                    DropdownMenuItem(value: '+965', child: Text('+965 🇰🇼')),
                    DropdownMenuItem(value: '+91', child: Text('+91 🇮🇳')),
                  ],
                  onChanged: (val) {
                    if (val != null) entry.countryCode.value = val;
                  },
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildTextField(
                  controller: entry.phoneController,
                  label: 'Phone Number',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          _buildTextField(
            controller: entry.labelController,
            label: 'Label (e.g. Saudi SIM, Bahrain SIM)',
            icon: Icons.label,
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: ValueListenableBuilder<DateTime?>(
                  valueListenable: entry.rechargeExpiry,
                  builder: (context, date, _) {
                    return CustomDatePicker(
                      label: 'Recharge Expiry',
                      date: date,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: date ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          entry.rechargeExpiry.value = picked;
                        }
                      },
                      onClear: () => entry.rechargeExpiry.value = null,
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Helper class to manage form state for each contact entry.
class _ContactEntry {
  final String id;
  final TextEditingController phoneController;
  final TextEditingController labelController;
  final ValueNotifier<String> countryCode;
  final ValueNotifier<DateTime?> rechargeExpiry;
  String? currentHolderId;
  String? currentHolderName;
  double? rechargeCost;

  _ContactEntry({
    required this.id,
    required this.phoneController,
    required this.labelController,
    required this.countryCode,
    required this.rechargeExpiry,
    this.currentHolderId,
    this.currentHolderName,
    this.rechargeCost,
  });

  factory _ContactEntry.empty() {
    return _ContactEntry(
      id: const Uuid().v4(),
      phoneController: TextEditingController(),
      labelController: TextEditingController(),
      countryCode: ValueNotifier('+966'),
      rechargeExpiry: ValueNotifier(null),
    );
  }

  factory _ContactEntry.fromContact(EmployeeContact contact) {
    return _ContactEntry(
      id: contact.id,
      phoneController: TextEditingController(text: contact.phoneNumber),
      labelController: TextEditingController(text: contact.label),
      countryCode: ValueNotifier(contact.countryCode),
      rechargeExpiry: ValueNotifier(contact.rechargeExpiryDate),
      currentHolderId: contact.currentHolderId,
      currentHolderName: contact.currentHolderName,
      rechargeCost: contact.rechargeCost,
    );
  }

  EmployeeContact toContact() {
    return EmployeeContact(
      id: id,
      phoneNumber: phoneController.text.trim(),
      countryCode: countryCode.value,
      label: labelController.text.trim(),
      rechargeExpiryDate: rechargeExpiry.value,
      rechargeCost: rechargeCost,
      currentHolderId: currentHolderId,
      currentHolderName: currentHolderName,
    );
  }
}
