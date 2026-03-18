import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../features/employee/domain/entities/employee_entity.dart';
import '../features/employee/presentation/providers/employee_provider.dart';
import '../features/vehicle/domain/entities/vehicle_make_entity.dart';
import '../features/vehicle/domain/entities/vehicle_entity.dart';
import '../features/vehicle/domain/entities/vehicle_documents.dart';
import '../features/vehicle/presentation/providers/vehicle_provider.dart';
import '../widgets/custom_date_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../services/image_service.dart';

class VehicleFormScreen extends StatefulWidget {
  final VehicleEntity? vehicle;

  const VehicleFormScreen({super.key, this.vehicle});

  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  // Replaced controllers with selected value variables for Dropdowns
  final ValueNotifier<String?> _selectedMake = ValueNotifier(null);
  final ValueNotifier<String?> _selectedModel = ValueNotifier(null);
  final ValueNotifier<int?> _selectedYear = ValueNotifier(null);
  final ValueNotifier<String?> _selectedColor = ValueNotifier(null);

  // Controllers for free-text fields
  final _plateNumberController = TextEditingController();
  final _typeController = TextEditingController();

  // Document Dates
  final ValueNotifier<DateTime?> _insuranceExpiryDate = ValueNotifier(null);
  final ValueNotifier<DateTime?> _registrationExpiryDate = ValueNotifier(null);
  final ValueNotifier<DateTime?> _fahasExpiryDate = ValueNotifier(null);

  // Maintenance Records
  final ValueNotifier<DateTime?> _tyreChangeDate = ValueNotifier(null);
  final _tyreChangeKmController = TextEditingController();
  final ValueNotifier<DateTime?> _gearOilChangeDate = ValueNotifier(null);
  final _gearOilChangeKmController = TextEditingController();
  final ValueNotifier<DateTime?> _housingOilChangeDate = ValueNotifier(null);
  final _housingOilChangeKmController = TextEditingController();
  final ValueNotifier<DateTime?> _batteryChangeDate = ValueNotifier(null);
  final _batteryChangeKmController = TextEditingController();
  final ValueNotifier<DateTime?> _engineOilChangeDate = ValueNotifier(null);
  final _engineOilChangeKmController = TextEditingController();

  final ValueNotifier<String?> _assignedEmployeeId = ValueNotifier(null);
  final ValueNotifier<XFile?> _selectedImage = ValueNotifier(null);
  final ValueNotifier<String?> _currentImageUrl = ValueNotifier(null);
  final ValueNotifier<bool> _isLoading = ValueNotifier(false);
  final ValueNotifier<bool> _isUploadingImage = ValueNotifier(false);
  final ValueNotifier<double> _uploadProgress = ValueNotifier(0.0);
  final ValueNotifier<List<EmployeeEntity>> _employees = ValueNotifier([]);
  final ValueNotifier<XFile?> _isthimaraAttachment = ValueNotifier(null);
  final ValueNotifier<String?> _isthimaraAttachmentUrl = ValueNotifier(null);
  final ValueNotifier<bool> _isUploadingIsthimara = ValueNotifier(false);

  // Vehicle Master Data
  final ValueNotifier<List<VehicleMakeEntity>> _allMakes = ValueNotifier([]);
  final ValueNotifier<List<VehicleModelDetailEntity>> _availableModels =
      ValueNotifier([]);
  final ValueNotifier<List<int>> _availableYears = ValueNotifier([]);
  final ValueNotifier<List<String>> _availableColors = ValueNotifier([]);

  @override
  void dispose() {
    _selectedMake.dispose();
    _selectedModel.dispose();
    _selectedYear.dispose();
    _selectedColor.dispose();
    _assignedEmployeeId.dispose();
    _selectedImage.dispose();
    _currentImageUrl.dispose();
    _isLoading.dispose();
    _isUploadingImage.dispose();
    _uploadProgress.dispose();
    _employees.dispose();
    _allMakes.dispose();
    _availableModels.dispose();
    _availableYears.dispose();
    _availableColors.dispose();
    _plateNumberController.dispose();
    _typeController.dispose();

    _insuranceExpiryDate.dispose();
    _registrationExpiryDate.dispose();
    _fahasExpiryDate.dispose();

    _tyreChangeDate.dispose();
    _tyreChangeKmController.dispose();
    _gearOilChangeDate.dispose();
    _gearOilChangeKmController.dispose();
    _housingOilChangeDate.dispose();
    _housingOilChangeKmController.dispose();
    _batteryChangeDate.dispose();
    _batteryChangeKmController.dispose();
    _engineOilChangeDate.dispose();
    _engineOilChangeKmController.dispose();
    _isthimaraAttachment.dispose();
    _isthimaraAttachmentUrl.dispose();
    _isUploadingIsthimara.dispose();

    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadData(); // Combined loading
  }

  Future<void> _loadData() async {
    _isLoading.value = true;
    try {
      await Future.wait([_loadDrivers(), _loadVehicleMasterData()]);

      if (widget.vehicle != null) {
        _populateFormData();
      }

      if (mounted) _isLoading.value = false;
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) _isLoading.value = false;
    }
  }

  Future<void> _loadVehicleMasterData() async {
    final provider = context.read<VehicleProvider>();
    await provider.fetchAllVehicleMakes();
    if (mounted) {
      _allMakes.value = provider.vehicleMakes;
    }
  }

  Future<void> _loadDrivers() async {
    final provider = context.read<EmployeeProvider>();
    await provider.fetchAllEmployees();
    if (mounted) {
      // Show all active employees so any employee can be assigned a vehicle
      _employees.value = provider.employees.where((e) => e.isActive).toList();
    }
  }

  void _populateFormData() {
    final v = widget.vehicle!;
    _selectedMake.value = v.make;
    _selectedModel.value = v.model;
    _selectedYear.value = v.year;
    _selectedColor.value = v.color;

    _plateNumberController.text = v.plateNumber;
    _typeController.text = v.type;
    _assignedEmployeeId.value = v.assignedDriverId;
    _currentImageUrl.value = v.imageUrl;

    _insuranceExpiryDate.value = v.insurance?.expiryDate;
    _registrationExpiryDate.value = v.registration?.expiryDate;
    _fahasExpiryDate.value = v.fahas?.expiryDate;

    _isthimaraAttachmentUrl.value = v.registration?.attachmentUrl;

    if (v.maintenance != null) {
      final m = v.maintenance!;
      _tyreChangeDate.value = m.tyreChange?.date;
      _tyreChangeKmController.text = m.tyreChange?.mileage.toString() ?? '';
      _gearOilChangeDate.value = m.gearOil?.date;
      _gearOilChangeKmController.text = m.gearOil?.mileage.toString() ?? '';
      _housingOilChangeDate.value = m.housingOil?.date;
      _housingOilChangeKmController.text = m.housingOil?.mileage.toString() ?? '';
      _batteryChangeDate.value = m.batteryChange?.date;
      _batteryChangeKmController.text = m.batteryChange?.mileage.toString() ?? '';
      _engineOilChangeDate.value = m.engineOil?.date;
      _engineOilChangeKmController.text = m.engineOil?.mileage.toString() ?? '';
    }

    // Trigger updates to available lists based on initial make
    _updateAvailableOptions(_selectedMake.value);
  }

  void _updateAvailableOptions(String? makeName) {
    if (makeName == null) {
      _availableModels.value = [];
      _availableYears.value = [];
      _availableColors.value = [];
      return;
    }

    final make = _allMakes.value.firstWhere(
      (m) => m.name == makeName,
      orElse: () => VehicleMakeEntity(
        id: '',
        name: '',
        models: [],
        years: [],
        colors: [],
      ),
    );

    List<VehicleModelDetailEntity> tempModels = List.from(make.models);
    List<int> tempYears = List.from(make.years);
    List<String> tempColors = List.from(make.colors);

    // Handle legacy/custom values not in the list
    if (_selectedModel.value != null) {
      final exists = tempModels.any((m) => m.name == _selectedModel.value);
      if (!exists) {
        // Create a temporary entry for display if not found, assume default type
        tempModels.add(
          VehicleModelDetailEntity(name: _selectedModel.value!, type: 'Sedan'),
        );
      }
    }
    if (_selectedYear.value != null &&
        !tempYears.contains(_selectedYear.value)) {
      tempYears.add(_selectedYear.value!);
    }
    if (_selectedColor.value != null &&
        !tempColors.contains(_selectedColor.value)) {
      tempColors.add(_selectedColor.value!);
    }

    _availableModels.value = tempModels;
    _availableYears.value = tempYears;
    _availableColors.value = tempColors;
  }

  Future<void> _pickImage() async {
    final image = await ImageService.instance.pickImage();
    if (image != null) {
      _selectedImage.value = image;
    }
  }

  Future<String?> _uploadIsthimara(XFile file, String vehicleId) async {
    try {
      _isUploadingIsthimara.value = true;
      final url = await context.read<VehicleProvider>().uploadVehicleDocument(file, vehicleId, 'registration');
      _isUploadingIsthimara.value = false;
      return url;
    } catch (e) {
      debugPrint('Error uploading isthimara: $e');
      _isUploadingIsthimara.value = false;
      return null;
    }
  }

  Future<void> _saveVehicle() async {
    if (!_formKey.currentState!.validate()) return;

    _isLoading.value = true;
    _isUploadingImage.value =
        _selectedImage.value != null; // Set uploading flag
    _uploadProgress.value = 0.0;
    debugPrint('VehicleFormScreen: Starting save process...');

    try {
      final vehicleId = widget.vehicle?.id ?? const Uuid().v4();
      String? imageUrl = _currentImageUrl.value;

      if (_selectedImage.value != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Uploading image... Please wait.')),
          );
        }
        debugPrint('VehicleFormScreen: Uploading image...');
        imageUrl = await ImageService.instance.uploadVehicleImage(
          _selectedImage.value!,
          vehicleId,
          onProgress: (progress) {
            if (mounted) {
              _uploadProgress.value = progress;
            }
          },
        );
        debugPrint('VehicleFormScreen: Image upload finished. URL: $imageUrl');

        if (imageUrl == null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image upload failed. Saving without new image.'),
            ),
          );
        }
        if (mounted) {
          _isUploadingImage.value = false;
        }
      }

      // Upload Isthimara if picked
      String? registrationUrl = _isthimaraAttachmentUrl.value;
      if (_isthimaraAttachment.value != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Uploading Isthimara...')),
          );
        }
        final url = await _uploadIsthimara(_isthimaraAttachment.value!, vehicleId);
        if (url != null) {
          registrationUrl = url;
        }
      }

      final vehicle = VehicleEntity(
        id: vehicleId,
        make: _selectedMake.value!,
        model: _selectedModel.value!,
        year: _selectedYear.value!,
        color: _selectedColor.value!,
        plateNumber: _plateNumberController.text,
        type: _typeController.text,
        assignedDriverId: _assignedEmployeeId.value,
        imageUrl: imageUrl,
        isActive: true,
        insurance: _insuranceExpiryDate.value != null
            ? VehicleDocument(
                expiryDate: _insuranceExpiryDate.value!,
                attachmentUrl: widget.vehicle?.insurance?.attachmentUrl,
              )
            : null,
        registration: _registrationExpiryDate.value != null
            ? VehicleDocument(
                expiryDate: _registrationExpiryDate.value!,
                attachmentUrl: registrationUrl,
              )
            : null,
        fahas: _fahasExpiryDate.value != null
            ? VehicleDocument(
                expiryDate: _fahasExpiryDate.value!,
                attachmentUrl: widget.vehicle?.fahas?.attachmentUrl,
              )
            : null,
        maintenance: VehicleMaintenance(
          engineOil: _engineOilChangeDate.value != null
              ? MaintenanceRecord(
                  date: _engineOilChangeDate.value!,
                  mileage: int.tryParse(_engineOilChangeKmController.text) ?? 0,
                  attachmentUrl: widget.vehicle?.maintenance?.engineOil?.attachmentUrl,
                )
              : null,
          gearOil: _gearOilChangeDate.value != null
              ? MaintenanceRecord(
                  date: _gearOilChangeDate.value!,
                  mileage: int.tryParse(_gearOilChangeKmController.text) ?? 0,
                  attachmentUrl: widget.vehicle?.maintenance?.gearOil?.attachmentUrl,
                )
              : null,
          housingOil: _housingOilChangeDate.value != null
              ? MaintenanceRecord(
                  date: _housingOilChangeDate.value!,
                  mileage: int.tryParse(_housingOilChangeKmController.text) ?? 0,
                  attachmentUrl: widget.vehicle?.maintenance?.housingOil?.attachmentUrl,
                )
              : null,
          tyreChange: _tyreChangeDate.value != null
              ? MaintenanceRecord(
                  date: _tyreChangeDate.value!,
                  mileage: int.tryParse(_tyreChangeKmController.text) ?? 0,
                  attachmentUrl: widget.vehicle?.maintenance?.tyreChange?.attachmentUrl,
                )
              : null,
          batteryChange: _batteryChangeDate.value != null
              ? MaintenanceRecord(
                  date: _batteryChangeDate.value!,
                  mileage: int.tryParse(_batteryChangeKmController.text) ?? 0,
                  attachmentUrl: widget.vehicle?.maintenance?.batteryChange?.attachmentUrl,
                )
              : null,
        ),
      );

      debugPrint('VehicleFormScreen: Saving vehicle data to Firestore...');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saving vehicle details...')),
        );
      }

      if (!mounted) return;
      final provider = context.read<VehicleProvider>();
      if (widget.vehicle != null) {
        await provider.updateVehicle(vehicle);
      } else {
        await provider.addVehicle(vehicle);
      }
      debugPrint('VehicleFormScreen: Save complete.');

      if (mounted) {
        context.pop(true);
      }
    } catch (e) {
      debugPrint('Error saving vehicle: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving vehicle: $e')));
      }
    } finally {
      debugPrint('VehicleFormScreen: _isLoading = false');
      if (mounted) _isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.vehicle != null ? 'Edit Vehicle' : 'Add New Vehicle',
        ),
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: _isLoading,
        builder: (context, isLoading, _) {
          return isLoading
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40.w),
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _isUploadingImage,
                        _uploadProgress,
                      ]),
                      builder: (context, _) {
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isUploadingImage.value) ...[
                              LinearProgressIndicator(
                                value: _uploadProgress.value,
                              ),
                              SizedBox(height: 16.h),
                              Text(
                                'Uploading Image: ${(_uploadProgress.value * 100).toInt()}%',
                                style: TextStyle(fontSize: 16.sp),
                              ),
                            ] else ...[
                              const CircularProgressIndicator(),
                              SizedBox(height: 16.h),
                              Text(
                                'Saving details...',
                                style: TextStyle(fontSize: 16.sp),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(24.w),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildImagePicker(),
                        SizedBox(height: 24.h),
                        _buildSectionHeader('Basic Details'),
                        SizedBox(height: 16.h),
                        // Make & Model Row
                        Row(
                          children: [
                            Expanded(child: _buildMakeDropdown()),
                            SizedBox(width: 16.w),
                            Expanded(child: _buildModelDropdown()),
                          ],
                        ),
                        SizedBox(height: 16.h),
                        // Year & Color Row
                        Row(
                          children: [
                            Expanded(child: _buildYearDropdown()),
                            SizedBox(width: 16.w),
                            Expanded(child: _buildColorDropdown()),
                          ],
                        ),
                        SizedBox(height: 16.h),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                'Plate Number',
                                _plateNumberController,
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: _buildTextField(
                                'Type (e.g. SUV)',
                                _typeController,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16.h),
                        _buildDriverDropdown(),

                        SizedBox(height: 32.h),
                        _buildSectionHeader('Documents (Expiry Dates)'),
                        SizedBox(height: 16.h),
                        ValueListenableBuilder<DateTime?>(
                          valueListenable: _registrationExpiryDate,
                          builder: (context, date, _) {
                            return CustomDatePicker(
                              label: 'Isthimara (Registration) Expiry',
                              date: date,
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: date ?? DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2050),
                                );
                                if (picked != null) {
                                  _registrationExpiryDate.value = picked;
                                }
                              },
                              onClear: () =>
                                  _registrationExpiryDate.value = null,
                            );
                          },
                        ),
                        SizedBox(height: 16.h),
                        _buildAttachmentPicker(
                          label: 'Isthimara Scan / Copy',
                          pickedFileNotifier: _isthimaraAttachment,
                          existingUrlNotifier: _isthimaraAttachmentUrl,
                        ),
                        SizedBox(height: 16.h),
                        ValueListenableBuilder<DateTime?>(
                          valueListenable: _insuranceExpiryDate,
                          builder: (context, date, _) {
                            return CustomDatePicker(
                              label: 'Insurance Expiry',
                              date: date,
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: date ?? DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2050),
                                );
                                if (picked != null) {
                                  _insuranceExpiryDate.value = picked;
                                }
                              },
                              onClear: () =>
                                  _insuranceExpiryDate.value = null,
                            );
                          },
                        ),
                        SizedBox(height: 16.h),
                        ValueListenableBuilder<DateTime?>(
                          valueListenable: _fahasExpiryDate,
                          builder: (context, date, _) {
                            return CustomDatePicker(
                              label: 'Fahas Inspection Expiry',
                              date: date,
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: date ?? DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2050),
                                );
                                if (picked != null) {
                                  _fahasExpiryDate.value = picked;
                                }
                              },
                              onClear: () => _fahasExpiryDate.value = null,
                            );
                          },
                        ),

                        SizedBox(height: 32.h),
                        _buildSectionHeader('Maintenance Records'),
                        SizedBox(height: 16.h),
                        // Engine Oil
                        _buildMaintenanceRow(
                          'Engine Oil',
                          _engineOilChangeDate,
                          _engineOilChangeKmController,
                        ),
                        SizedBox(height: 16.h),
                        // Gear Oil
                        _buildMaintenanceRow(
                          'Gear Oil',
                          _gearOilChangeDate,
                          _gearOilChangeKmController,
                        ),
                        SizedBox(height: 16.h),
                        // Housing Oil
                        _buildMaintenanceRow(
                          'Housing (Diff) Oil',
                          _housingOilChangeDate,
                          _housingOilChangeKmController,
                        ),
                        SizedBox(height: 16.h),
                        // Tyre Change
                        _buildMaintenanceRow(
                          'Tyre Change',
                          _tyreChangeDate,
                          _tyreChangeKmController,
                        ),
                        SizedBox(height: 16.h),
                        // Battery Change
                        _buildMaintenanceRow(
                          'Battery Change',
                          _batteryChangeDate,
                          _batteryChangeKmController,
                        ),

                        SizedBox(height: 32.h),
                        SizedBox(
                          width: double.infinity,
                          height: 50.h,
                          child: ElevatedButton(
                            onPressed: _saveVehicle,
                            child: Text(
                              'Save Vehicle',
                              style: TextStyle(fontSize: 16.sp),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        Divider(thickness: 1.h),
      ],
    );
  }

  Widget _buildMaintenanceRow(
    String label,
    ValueNotifier<DateTime?> dateNotifier,
    TextEditingController kmController,
  ) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: ValueListenableBuilder<DateTime?>(
            valueListenable: dateNotifier,
            builder: (context, date, _) {
              return CustomDatePicker(
                label: '$label Date',
                date: date,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2050),
                  );
                  if (picked != null) {
                    dateNotifier.value = picked;
                  }
                },
                onClear: () => dateNotifier.value = null,
              );
            },
          ),
        ),
        SizedBox(width: 16.w),
        Expanded(
          flex: 1,
          child: _buildTextField('$label KM', kmController, isNumber: true, required: false),
        ),
      ],
    );
  }

  /// A reusable widget that lets the user optionally pick a document scan/image.
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
                    if (hasPicked || hasExisting)
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 16.sp,
                          color: Colors.white.withValues(alpha: 0.9),
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
                      // Logic to view existing scan if needed
                    },
                  ),
                SizedBox(height: 6.h),
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

  Widget _buildMakeDropdown() {
    return AnimatedBuilder(
      animation: Listenable.merge([_selectedMake, _allMakes]),
      builder: (context, _) {
        return DropdownButtonFormField<String>(
          initialValue: _selectedMake.value,
          decoration: InputDecoration(
            labelText: 'Make',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
          items: _allMakes.value.map((make) {
            return DropdownMenuItem<String>(
              value: make.name,
              child: Text(make.name),
            );
          }).toList(),
          onChanged: (val) {
            _selectedMake.value = val;
            _selectedModel.value = null;
            _selectedYear.value = null;
            _selectedColor.value = null;
            _updateAvailableOptions(val);
          },
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        );
      },
    );
  }

  Widget _buildModelDropdown() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _selectedMake,
        _selectedModel,
        _availableModels,
      ]),
      builder: (context, _) {
        return DropdownButtonFormField<String>(
          initialValue: _selectedModel.value,
          decoration: InputDecoration(
            labelText: 'Model',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
            enabled: _selectedMake.value != null,
          ),
          items: _availableModels.value.map((model) {
            // Display generic 'Sedan' if type is missing, or show existing type
            final displayType = model.type.isNotEmpty ? model.type : '';
            final label = displayType.isNotEmpty
                ? '${model.name} ($displayType)'
                : model.name;

            return DropdownMenuItem<String>(
              value: model.name,
              child: Text(label),
            );
          }).toList(),
          onChanged: _selectedMake.value == null
              ? null
              : (val) {
                  _selectedModel.value = val;
                  // Auto-populate type
                  if (val != null) {
                    final selectedModelDetail = _availableModels.value
                        .firstWhere(
                          (m) => m.name == val,
                          orElse: () =>
                              VehicleModelDetailEntity(name: val, type: ''),
                        );
                    if (selectedModelDetail.type.isNotEmpty) {
                      _typeController.text = selectedModelDetail.type;
                    }
                  }
                },
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        );
      },
    );
  }

  Widget _buildYearDropdown() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _selectedMake,
        _selectedYear,
        _availableYears,
      ]),
      builder: (context, _) {
        return DropdownButtonFormField<int>(
          initialValue: _selectedYear.value,
          decoration: InputDecoration(
            labelText: 'Year',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
            enabled: _selectedMake.value != null,
          ),
          items: _availableYears.value.map((year) {
            return DropdownMenuItem<int>(
              value: year,
              child: Text(year.toString()),
            );
          }).toList(),
          onChanged: _selectedMake.value == null
              ? null
              : (val) {
                  _selectedYear.value = val;
                },
          validator: (v) => v == null ? 'Required' : null,
        );
      },
    );
  }

  Widget _buildColorDropdown() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _selectedMake,
        _selectedColor,
        _availableColors,
      ]),
      builder: (context, _) {
        return DropdownButtonFormField<String>(
          initialValue: _selectedColor.value,
          decoration: InputDecoration(
            labelText: 'Color',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
            enabled: _selectedMake.value != null,
          ),
          items: _availableColors.value.map((color) {
            return DropdownMenuItem<String>(value: color, child: Text(color));
          }).toList(),
          onChanged: _selectedMake.value == null
              ? null
              : (val) {
                  _selectedColor.value = val;
                },
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        );
      },
    );
  }

  // ... (ImagePicker, TextField, driverDropdown helpers essentially same as before but adjusted if needed)
  Widget _buildImagePicker() {
    return AnimatedBuilder(
      animation: Listenable.merge([_selectedImage, _currentImageUrl]),
      builder: (context, _) {
        return Center(
          child: GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 150.w,
              height: 150.w,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.grey[400]!),
                image: _selectedImage.value != null
                    ? DecorationImage(
                        image: kIsWeb
                            ? NetworkImage(_selectedImage.value!.path)
                            : FileImage(File(_selectedImage.value!.path))
                                  as ImageProvider,
                        fit: BoxFit.cover,
                      )
                    : _currentImageUrl.value != null
                    ? DecorationImage(
                        image: NetworkImage(_currentImageUrl.value!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child:
                  _selectedImage.value == null && _currentImageUrl.value == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt,
                          size: 40.sp,
                          color: Colors.grey[600],
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'Upload Image',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
      ),
      validator: required
          ? (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter $label';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildDriverDropdown() {
    return AnimatedBuilder(
      animation: Listenable.merge([_assignedEmployeeId, _employees]),
      builder: (context, _) {
        return DropdownButtonFormField<String>(
          initialValue: _assignedEmployeeId.value,
          decoration: InputDecoration(
            labelText: 'Assigned Employee',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
          items: [
            const DropdownMenuItem<String>(value: null, child: Text('None')),
            ..._employees.value.map((employee) {
              return DropdownMenuItem<String>(
                value: employee.id,
                child: Row(
                  children: [
                    Text(employee.fullName),
                    SizedBox(width: 8.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4.r),
                        border: Border.all(color: Colors.blue),
                      ),
                      child: Text(
                        employee.position,
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          onChanged: (value) {
            _assignedEmployeeId.value = value;
          },
        );
      },
    );
  }
}
