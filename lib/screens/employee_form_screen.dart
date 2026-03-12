import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../features/employee/domain/entities/employee_documents.dart';
import '../features/employee/domain/entities/employee_entity.dart';
import '../features/employee/presentation/providers/employee_provider.dart';
import '../features/vehicle/domain/entities/vehicle_entity.dart';
import '../features/vehicle/presentation/providers/vehicle_provider.dart';

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

  final ValueNotifier<String> _selectedPosition = ValueNotifier('Driver');
  final ValueNotifier<String> _selectedIdType = ValueNotifier('Iqama');
  final ValueNotifier<String> _selectedGender = ValueNotifier('Male');
  final ValueNotifier<String> _selectedDriverType = ValueNotifier('Internal');
  final ValueNotifier<DateTime?> _joinDate = ValueNotifier(null);
  final ValueNotifier<DateTime?> _birthDate = ValueNotifier(null);
  final ValueNotifier<bool> _isActive = ValueNotifier(true);
  final ValueNotifier<String?> _currentImageUrl = ValueNotifier(null);
  final ValueNotifier<XFile?> _pickedImage = ValueNotifier(null);
  final ImagePicker _picker = ImagePicker();

  // Document Specific Controllers
  late TextEditingController _iqamaNumberController;
  final ValueNotifier<DateTime?> _iqamaExpiryDate = ValueNotifier(null);
  final ValueNotifier<DateTime?> _insuranceExpiryDate = ValueNotifier(null);

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

  final ValueNotifier<DateTime?> _phoneRechargeDate = ValueNotifier(null);

  // Attachment file pickers (one per document)
  final ValueNotifier<XFile?> _iqamaAttachment = ValueNotifier(null);
  final ValueNotifier<String?> _iqamaAttachmentUrl = ValueNotifier(null);

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
  final ValueNotifier<List<VehicleEntity>> _availableVehicles = ValueNotifier(
    [],
  );
  final ValueNotifier<String?> _selectedVehicleId = ValueNotifier(null);

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
  final List<String> _driverTypes = ['Internal', 'External'];

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    _nameController = TextEditingController(text: e?.fullName ?? '');
    _emailController = TextEditingController(text: e?.email ?? '');
    _phoneController = TextEditingController(text: e?.phoneNumber ?? '');
    _idNumberController = TextEditingController(text: e?.idNumber ?? '');
    _nationalityController = TextEditingController(text: e?.nationality ?? '');

    _iqamaNumberController = TextEditingController(
      text: e?.iqama?.number ?? '',
    );
    _iqamaExpiryDate.value = e?.iqama?.expiryDate;
    _insuranceExpiryDate.value = e?.iqama?.insuranceExpiryDate;

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

    _phoneRechargeDate.value = e?.phoneRechargeDate;

    // Pre-populate attachment URLs from existing employee
    _iqamaAttachmentUrl.value = e?.iqama?.attachmentUrl;
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

      if (e.driverType != null && _driverTypes.contains(e.driverType)) {
        _selectedDriverType.value = e.driverType!;
      }

      _joinDate.value = e.joinDate;
      _birthDate.value = e.birthDate;
      _isActive.value = e.isActive;
      _currentImageUrl.value = e.imageUrl;
    }
    _loadVehicles(); // Load vehicles
  }

  // Added method to load vehicles
  Future<void> _loadVehicles() async {
    try {
      if (mounted) {
        await context.read<VehicleProvider>().fetchAllVehicles();
        if (!mounted) return;
        final vehicles = context.read<VehicleProvider>().vehicles;
        _availableVehicles.value = vehicles;
        // If editing, find the vehicle assigned to this driver
        if (widget.employee != null) {
          final assignedVehicle = vehicles
              .where((v) => v.assignedDriverId == widget.employee!.id)
              .firstOrNull;
          _selectedVehicleId.value = assignedVehicle?.id;
        }
      }
    } catch (e) {
      debugPrint('Error loading vehicles: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _idNumberController.dispose();
    _nationalityController.dispose();
    _selectedPosition.dispose();
    _selectedIdType.dispose();
    _selectedGender.dispose();
    _selectedDriverType.dispose();
    _joinDate.dispose();
    _birthDate.dispose();
    _isActive.dispose();
    _currentImageUrl.dispose();
    _pickedImage.dispose();

    _iqamaNumberController.dispose();
    _iqamaExpiryDate.dispose();
    _insuranceExpiryDate.dispose();
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
    _phoneRechargeDate.dispose();

    _isSaving.dispose();
    _availableVehicles.dispose();
    _selectedVehicleId.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isJoinDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isJoinDate
          ? (_joinDate.value ?? DateTime.now())
          : (_birthDate.value ?? DateTime(1990)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  Future<void> _saveEmployee() async {
    if (!_formKey.currentState!.validate()) return;

    _isSaving.value = true;

    try {
      final id = widget.employee?.id ?? const Uuid().v4();
      final provider = context.read<EmployeeProvider>();

      // Upload profile image if changed
      String? imageUrl = _currentImageUrl.value;
      if (_pickedImage.value != null && mounted) {
        imageUrl = await provider.uploadEmployeeImage(_pickedImage.value!, id);
      }

      // Upload document attachments if new files were picked
      String? iqamaUrl = _iqamaAttachmentUrl.value;
      if (_iqamaAttachment.value != null && mounted) {
        iqamaUrl = await provider.uploadDocumentAttachment(
          _iqamaAttachment.value!,
          id,
          'iqama',
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

      final newEmployee = EmployeeEntity(
        id: id,
        fullName: _nameController.text.trim(),
        position: _selectedPosition.value,
        email: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        nationality: _nationalityController.text.trim(),
        idType: _selectedIdType.value,
        idNumber: _idNumberController.text.trim(),
        joinDate: _joinDate.value,
        birthDate: _birthDate.value,
        gender: _selectedGender.value,
        driverType: _selectedPosition.value == 'Driver'
            ? _selectedDriverType.value
            : null,
        isActive: _isActive.value,
        imageUrl: imageUrl,
        iqama:
            _iqamaNumberController.text.isNotEmpty &&
                _iqamaExpiryDate.value != null
            ? IqamaDocument(
                number: _iqamaNumberController.text.trim(),
                expiryDate: _iqamaExpiryDate.value!,
                insuranceExpiryDate: _insuranceExpiryDate.value,
                attachmentUrl: iqamaUrl,
              )
            : null,
        passport:
            _passportNumberController.text.isNotEmpty &&
                _passportExpiryDate.value != null
            ? PassportDocument(
                nameOnPassport: _passportNameController.text.trim(),
                number: _passportNumberController.text.trim(),
                expiryDate: _passportExpiryDate.value!,
                attachmentUrl: passportUrl,
              )
            : null,
        saudiVisa:
            _saudiVisaNumberController.text.isNotEmpty &&
                _saudiVisaExpiryDate.value != null
            ? VisaDocument(
                number: _saudiVisaNumberController.text.trim(),
                expiryDate: _saudiVisaExpiryDate.value!,
                type: _selectedSaudiVisaType.value,
                attachmentUrl: saudiVisaUrl,
              )
            : null,
        bahrainVisa:
            _bahrainVisaNumberController.text.isNotEmpty &&
                _bahrainVisaExpiryDate.value != null
            ? VisaDocument(
                number: _bahrainVisaNumberController.text.trim(),
                expiryDate: _bahrainVisaExpiryDate.value!,
                type: _selectedBahrainVisaType.value,
                attachmentUrl: bahrainVisaUrl,
              )
            : null,
        dubaiVisa:
            _dubaiVisaNumberController.text.isNotEmpty &&
                _dubaiVisaExpiryDate.value != null
            ? VisaDocument(
                number: _dubaiVisaNumberController.text.trim(),
                expiryDate: _dubaiVisaExpiryDate.value!,
                type: _selectedDubaiVisaType.value,
                attachmentUrl: dubaiVisaUrl,
              )
            : null,
        qatarVisa:
            _qatarVisaNumberController.text.isNotEmpty &&
                _qatarVisaExpiryDate.value != null
            ? VisaDocument(
                number: _qatarVisaNumberController.text.trim(),
                expiryDate: _qatarVisaExpiryDate.value!,
                type: _selectedQatarVisaType.value,
                attachmentUrl: qatarVisaUrl,
              )
            : null,
        drivingLicense:
            _licenseNumberController.text.isNotEmpty &&
                _licenseExpiryDate.value != null
            ? DrivingLicenseDocument(
                countryOfOrigin: _licenseCountryController.text.trim(),
                number: _licenseNumberController.text.trim(),
                expiryDate: _licenseExpiryDate.value!,
                type: _selectedLicenseType.value,
                attachmentUrl: licenseUrl,
              )
            : null,
        phoneRechargeDate: _phoneRechargeDate.value,
      );

      if (mounted) {
        if (widget.employee == null) {
          await provider.addEmployee(newEmployee);
        } else {
          await provider.updateEmployee(newEmployee);
        }
      }

      // Handle Vehicle Assignment
      if (mounted) {
        await context.read<VehicleProvider>().assignDriver(
          _selectedVehicleId.value,
          id,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Employee saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving employee: $e')));
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
      appBar: AppBar(
        title: Text(
          widget.employee == null ? 'Add New Employee' : 'Edit Employee',
        ),
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
                                            ? CachedNetworkImageProvider(currentImageUrl)
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
                  ValueListenableBuilder<String>(
                    valueListenable: _selectedPosition,
                    builder: (context, selectedPosition, _) {
                      if (selectedPosition == 'Driver') {
                        return Column(
                          children: [
                            SizedBox(height: 16.h),
                            ValueListenableBuilder<String>(
                              valueListenable: _selectedDriverType,
                              builder: (context, selectedDriverType, _) {
                                return _buildDropdown(
                                  label: 'Driver Type',
                                  value: selectedDriverType,
                                  items: _driverTypes,
                                  onChanged: (val) =>
                                      _selectedDriverType.value = val!,
                                );
                              },
                            ),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  SizedBox(height: 16.h),
                  ValueListenableBuilder<List<VehicleEntity>>(
                    valueListenable: _availableVehicles,
                    builder: (context, availableVehicles, _) {
                      return ValueListenableBuilder<String?>(
                        valueListenable: _selectedVehicleId,
                        builder: (context, selectedVehicleId, _) {
                          return DropdownButtonFormField<String>(
                            initialValue: selectedVehicleId,
                            decoration: InputDecoration(
                              labelText: 'Assign Vehicle',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('No Vehicle Assigned'),
                              ),
                              ...availableVehicles.map((v) {
                                final isAssigned =
                                    v.assignedDriverId != null &&
                                    v.assignedDriverId != widget.employee?.id;
                                return DropdownMenuItem(
                                  value: v.id,
                                  child: Text(
                                    '${v.make} ${v.model} (${v.plateNumber})${isAssigned ? " [Assigned]" : ""}',
                                    style: TextStyle(
                                      color: isAssigned ? Colors.orange : null,
                                    ),
                                  ),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              _selectedVehicleId.value = val;
                            },
                          );
                        },
                      );
                    },
                  ),
                  SizedBox(height: 16.h),

                  // Contact Info
                  _buildSectionTitle('Contact Information'),
                  SizedBox(height: 16.h),
                  ValueListenableBuilder<String>(
                    valueListenable: _selectedPosition,
                    builder: (context, selectedPosition, _) {
                      return ValueListenableBuilder<String>(
                        valueListenable: _selectedDriverType,
                        builder: (context, selectedDriverType, _) {
                          return Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _phoneController,
                                  label: 'Phone Number',
                                  icon: Icons.phone,
                                  validator: (v) => v!.isEmpty
                                      ? 'Please enter phone number'
                                      : null,
                                ),
                              ),
                              if (!(selectedPosition == 'Driver' &&
                                  selectedDriverType == 'External')) ...[
                                SizedBox(width: 16.w),
                                Expanded(
                                  child: _buildTextField(
                                    controller: _emailController,
                                    label: 'Email',
                                    icon: Icons.email,
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      );
                    },
                  ),
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
                  ValueListenableBuilder<String>(
                    valueListenable: _selectedPosition,
                    builder: (context, selectedPosition, _) {
                      return ValueListenableBuilder<String>(
                        valueListenable: _selectedDriverType,
                        builder: (context, selectedDriverType, _) {
                          if (!(selectedPosition == 'Driver' &&
                              selectedDriverType == 'External')) {
                            return Column(
                              children: [
                                SizedBox(height: 16.h),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ValueListenableBuilder<DateTime?>(
                                        valueListenable: _birthDate,
                                        builder: (context, birthDate, _) {
                                          return _buildDatePicker(
                                            label: 'Birth Date',
                                            date: birthDate,
                                            onTap: () =>
                                                _selectDate(context, false),
                                          );
                                        },
                                      ),
                                    ),
                                    SizedBox(width: 16.w),
                                    Expanded(
                                      child: ValueListenableBuilder<DateTime?>(
                                        valueListenable: _joinDate,
                                        builder: (context, joinDate, _) {
                                          return _buildDatePicker(
                                            label: 'Join Date',
                                            date: joinDate,
                                            onTap: () =>
                                                _selectDate(context, true),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      );
                    },
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
                                  return _buildDatePicker(
                                    label: 'Iqama Expiry',
                                    date: date,
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate:
                                            date ??
                                            DateTime.now().add(
                                              const Duration(days: 365),
                                            ),
                                        firstDate: DateTime.now().subtract(
                                          const Duration(days: 365 * 5),
                                        ),
                                        lastDate: DateTime.now().add(
                                          const Duration(days: 365 * 10),
                                        ),
                                      );
                                      if (picked != null) {
                                        _iqamaExpiryDate.value = picked;
                                      }
                                    },
                                  );
                                },
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: ValueListenableBuilder<DateTime?>(
                                valueListenable: _insuranceExpiryDate,
                                builder: (context, date, _) {
                                  return _buildDatePicker(
                                    label: 'Health Ins. Expiry',
                                    date: date,
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate:
                                            date ??
                                            DateTime.now().add(
                                              const Duration(days: 365),
                                            ),
                                        firstDate: DateTime.now().subtract(
                                          const Duration(days: 365 * 5),
                                        ),
                                        lastDate: DateTime.now().add(
                                          const Duration(days: 365 * 10),
                                        ),
                                      );
                                      if (picked != null) {
                                        _insuranceExpiryDate.value = picked;
                                      }
                                    },
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
                                  return _buildDatePicker(
                                    label: 'Expiry',
                                    date: date,
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate:
                                            date ??
                                            DateTime.now().add(
                                              const Duration(days: 365),
                                            ),
                                        firstDate: DateTime.now().subtract(
                                          const Duration(days: 365 * 5),
                                        ),
                                        lastDate: DateTime.now().add(
                                          const Duration(days: 365 * 10),
                                        ),
                                      );
                                      if (picked != null) {
                                        _passportExpiryDate.value = picked;
                                      }
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16.h),
                        _buildTextField(
                          controller: _passportNameController,
                          label: 'Name on Passport',
                          icon: Icons.person,
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
                                  return _buildDatePicker(
                                    label: 'Expiry',
                                    date: date,
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate:
                                            date ??
                                            DateTime.now().add(
                                              const Duration(days: 365),
                                            ),
                                        firstDate: DateTime.now().subtract(
                                          const Duration(days: 365 * 5),
                                        ),
                                        lastDate: DateTime.now().add(
                                          const Duration(days: 365 * 10),
                                        ),
                                      );
                                      if (picked != null) {
                                        _saudiVisaExpiryDate.value = picked;
                                      }
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16.h),
                        ValueListenableBuilder<VisaType>(
                          valueListenable: _selectedSaudiVisaType,
                          builder: (context, type, _) {
                            return _buildDropdown(
                              label: 'Visa Type',
                              value: type.toString().split('.').last,
                              items: VisaType.values
                                  .map((e) => e.toString().split('.').last)
                                  .toList(),
                              onChanged: (val) {
                                _selectedSaudiVisaType.value = VisaType.values
                                    .firstWhere(
                                      (e) =>
                                          e.toString().split('.').last == val,
                                    );
                              },
                            );
                          },
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
                                  return _buildDatePicker(
                                    label: 'Expiry',
                                    date: date,
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate:
                                            date ??
                                            DateTime.now().add(
                                              const Duration(days: 365),
                                            ),
                                        firstDate: DateTime.now().subtract(
                                          const Duration(days: 365 * 5),
                                        ),
                                        lastDate: DateTime.now().add(
                                          const Duration(days: 365 * 10),
                                        ),
                                      );
                                      if (picked != null) {
                                        _bahrainVisaExpiryDate.value = picked;
                                      }
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16.h),
                        ValueListenableBuilder<VisaType>(
                          valueListenable: _selectedBahrainVisaType,
                          builder: (context, type, _) {
                            return _buildDropdown(
                              label: 'Visa Type',
                              value: type.toString().split('.').last,
                              items: VisaType.values
                                  .map((e) => e.toString().split('.').last)
                                  .toList(),
                              onChanged: (val) {
                                _selectedBahrainVisaType.value = VisaType.values
                                    .firstWhere(
                                      (e) =>
                                          e.toString().split('.').last == val,
                                    );
                              },
                            );
                          },
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
                                  return _buildDatePicker(
                                    label: 'Expiry',
                                    date: date,
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate:
                                            date ??
                                            DateTime.now().add(
                                              const Duration(days: 365),
                                            ),
                                        firstDate: DateTime.now().subtract(
                                          const Duration(days: 365 * 5),
                                        ),
                                        lastDate: DateTime.now().add(
                                          const Duration(days: 365 * 10),
                                        ),
                                      );
                                      if (picked != null) {
                                        _dubaiVisaExpiryDate.value = picked;
                                      }
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16.h),
                        ValueListenableBuilder<VisaType>(
                          valueListenable: _selectedDubaiVisaType,
                          builder: (context, type, _) {
                            return _buildDropdown(
                              label: 'Visa Type',
                              value: type.toString().split('.').last,
                              items: VisaType.values
                                  .map((e) => e.toString().split('.').last)
                                  .toList(),
                              onChanged: (val) {
                                _selectedDubaiVisaType.value = VisaType.values
                                    .firstWhere(
                                      (e) =>
                                          e.toString().split('.').last == val,
                                    );
                              },
                            );
                          },
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
                                  return _buildDatePicker(
                                    label: 'Expiry',
                                    date: date,
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate:
                                            date ??
                                            DateTime.now().add(
                                              const Duration(days: 365),
                                            ),
                                        firstDate: DateTime.now().subtract(
                                          const Duration(days: 365 * 5),
                                        ),
                                        lastDate: DateTime.now().add(
                                          const Duration(days: 365 * 10),
                                        ),
                                      );
                                      if (picked != null) {
                                        _qatarVisaExpiryDate.value = picked;
                                      }
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16.h),
                        ValueListenableBuilder<VisaType>(
                          valueListenable: _selectedQatarVisaType,
                          builder: (context, type, _) {
                            return _buildDropdown(
                              label: 'Visa Type',
                              value: type.toString().split('.').last,
                              items: VisaType.values
                                  .map((e) => e.toString().split('.').last)
                                  .toList(),
                              onChanged: (val) {
                                _selectedQatarVisaType.value = VisaType.values
                                    .firstWhere(
                                      (e) =>
                                          e.toString().split('.').last == val,
                                    );
                              },
                            );
                          },
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

                  // Phone Recharge Date
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ValueListenableBuilder<DateTime?>(
                        valueListenable: _phoneRechargeDate,
                        builder: (context, date, _) {
                          return _buildDatePicker(
                            label: 'Mobile Recharge Expiry',
                            date: date,
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate:
                                    date ??
                                    DateTime.now().add(
                                      const Duration(days: 30),
                                    ),
                                firstDate: DateTime.now().subtract(
                                  const Duration(days: 365),
                                ),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365 * 2),
                                ),
                              );
                              if (picked != null) {
                                _phoneRechargeDate.value = picked;
                              }
                            },
                          );
                        },
                      ),
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
                                  return _buildDatePicker(
                                    label: 'Expiry',
                                    date: date,
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate:
                                            date ??
                                            DateTime.now().add(
                                              const Duration(days: 365),
                                            ),
                                        firstDate: DateTime.now().subtract(
                                          const Duration(days: 365 * 5),
                                        ),
                                        lastDate: DateTime.now().add(
                                          const Duration(days: 365 * 10),
                                        ),
                                      );
                                      if (picked != null) {
                                        _licenseExpiryDate.value = picked;
                                      }
                                    },
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
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
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

  Widget _buildDatePicker({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today, size: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        child: Text(
          date != null ? DateFormat('yyyy-MM-dd').format(date) : 'Select Date',
          style: TextStyle(color: date != null ? Colors.black : Colors.grey),
        ),
      ),
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
                          pickedFileNotifier.value = XFile(platformFile.path!);
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
}
