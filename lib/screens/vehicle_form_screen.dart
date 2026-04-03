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
import '../core/widgets/modern_app_bar.dart';
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
  // Maintenance Intervals (Dynamic) - REMOVED

  // Vehicle Master Data
  final ValueNotifier<List<VehicleMakeEntity>> _allMakes = ValueNotifier([]);
  final ValueNotifier<List<VehicleModelDetailEntity>> _availableModels =
      ValueNotifier([]);
  final ValueNotifier<List<int>> _availableYears = ValueNotifier([]);
  final ValueNotifier<List<String>> _availableColors = ValueNotifier([]);

  // Restored state variables
  final ValueNotifier<bool> _isLoading = ValueNotifier(false);
  final ValueNotifier<bool> _isUploadingImage = ValueNotifier(false);
  final ValueNotifier<double> _uploadProgress = ValueNotifier(0.0);
  final ValueNotifier<XFile?> _selectedImage = ValueNotifier(null);
  final ValueNotifier<String?> _currentImageUrl = ValueNotifier(null);

  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _vinNumberController = TextEditingController();
  final TextEditingController _engineNumberController = TextEditingController();
  final TextEditingController _gvwrController = TextEditingController();
  final TextEditingController _tireSizeController = TextEditingController();
  final TextEditingController _purchasePriceController =
      TextEditingController();
  final TextEditingController _currentOdometerController =
      TextEditingController();

  final ValueNotifier<DateTime?> _purchaseDate = ValueNotifier(null);

  final ValueNotifier<XFile?> _isthimaraAttachment = ValueNotifier(null);
  final ValueNotifier<String?> _isthimaraAttachmentUrl = ValueNotifier(null);
  final ValueNotifier<bool> _isUploadingIsthimara = ValueNotifier(false);

  final ValueNotifier<String?> _assignedEmployeeId = ValueNotifier(null);
  final ValueNotifier<List<EmployeeEntity>> _employees = ValueNotifier([]);

  final ValueNotifier<String?> _fuelType = ValueNotifier(null);
  final ValueNotifier<String?> _transmission = ValueNotifier(null);
  final ValueNotifier<String> _status = ValueNotifier<String>('Active');

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

    _departmentController.dispose();
    _vinNumberController.dispose();
    _engineNumberController.dispose();
    _gvwrController.dispose();
    _tireSizeController.dispose();
    _purchasePriceController.dispose();
    _currentOdometerController.dispose();

    _purchaseDate.dispose();
    _isthimaraAttachment.dispose();
    _isthimaraAttachmentUrl.dispose();
    _isUploadingIsthimara.dispose();
    _fuelType.dispose();
    _transmission.dispose();
    _status.dispose();

    _insuranceExpiryDate.dispose();
    _registrationExpiryDate.dispose();
    _fahasExpiryDate.dispose();

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
    // Intervals removed from here

    _vinNumberController.text = v.vinNumber ?? '';
    _engineNumberController.text = v.engineNumber ?? '';
    _fuelType.value = v.fuelType;
    _transmission.value = v.transmission;
    _purchaseDate.value = v.purchaseDate;
    _purchasePriceController.text = v.purchasePrice?.toString() ?? '';
    _currentOdometerController.text = v.currentOdometer?.toString() ?? '';
    _gvwrController.text = v.gvwr?.toString() ?? '';
    _tireSizeController.text = v.tireSize ?? '';
    _departmentController.text = v.department ?? '';
    _status.value = v.status ?? 'Active';

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
      final url = await context.read<VehicleProvider>().uploadVehicleDocument(
        file,
        vehicleId,
        'registration',
      );
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
        final url = await _uploadIsthimara(
          _isthimaraAttachment.value!,
          vehicleId,
        );
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
        maintenance: null,
        vinNumber: _vinNumberController.text.isNotEmpty
            ? _vinNumberController.text
            : null,
        engineNumber: _engineNumberController.text.isNotEmpty
            ? _engineNumberController.text
            : null,
        fuelType: _fuelType.value,
        transmission: _transmission.value,
        purchaseDate: _purchaseDate.value,
        purchasePrice: double.tryParse(_purchasePriceController.text),
        currentOdometer: int.tryParse(_currentOdometerController.text),
        gvwr: _gvwrController.text.isNotEmpty ? _gvwrController.text : null,
        tireSize: _tireSizeController.text.isNotEmpty
            ? _tireSizeController.text
            : null,
        department: _departmentController.text.isNotEmpty
            ? _departmentController.text
            : null,

        status: _status.value,
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
      appBar: ModernAppBar(
        title: widget.vehicle != null ? 'Edit Vehicle' : 'Add New Vehicle',
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
                        Row(
                          children: [
                            Expanded(child: _buildDriverDropdown()),
                            SizedBox(width: 16.w),
                            Expanded(child: _buildStatusDropdown()),
                          ],
                        ),
                        SizedBox(height: 16.h),
                        _buildTextField(
                          'Department',
                          _departmentController,
                          required: false,
                        ),

                        SizedBox(height: 32.h),
                        _buildSectionHeader('Vehicle Specifications'),
                        SizedBox(height: 16.h),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                'VIN Number',
                                _vinNumberController,
                                required: false,
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: _buildTextField(
                                'Engine Number',
                                _engineNumberController,
                                required: false,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16.h),
                        Row(
                          children: [
                            Expanded(child: _buildFuelTypeDropdown()),
                            SizedBox(width: 16.w),
                            Expanded(child: _buildTransmissionDropdown()),
                          ],
                        ),
                        SizedBox(height: 16.h),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                'GVWR',
                                _gvwrController,
                                required: false,
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: _buildTextField(
                                'Tire Size',
                                _tireSizeController,
                                required: false,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 32.h),
                        _buildSectionHeader('Purchase Information'),
                        SizedBox(height: 16.h),
                        ValueListenableBuilder<DateTime?>(
                          valueListenable: _purchaseDate,
                          builder: (context, date, _) {
                            return CustomDatePicker(
                              label: 'Purchase Date',
                              date: date,
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: date ?? DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  _purchaseDate.value = picked;
                                }
                              },
                              onClear: () => _purchaseDate.value = null,
                            );
                          },
                        ),
                        SizedBox(height: 16.h),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                'Purchase Price',
                                _purchasePriceController,
                                isNumber: true,
                                required: false,
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: _buildTextField(
                                'Current Odometer',
                                _currentOdometerController,
                                isNumber: true,
                                required: false,
                              ),
                            ),
                          ],
                        ),

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
                              onClear: () => _insuranceExpiryDate.value = null,
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
          // ignore: deprecated_member_use
          value: _assignedEmployeeId.value,
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

  Widget _buildFuelTypeDropdown() {
    return ValueListenableBuilder<String?>(
      valueListenable: _fuelType,
      builder: (context, val, _) {
        return DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: val,
          decoration: InputDecoration(
            labelText: 'Fuel Type',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
          items: ['Petrol', 'Diesel', 'Electric', 'Hybrid', 'LPG', 'CNG']
              .map((type) => DropdownMenuItem(value: type, child: Text(type)))
              .toList(),
          onChanged: (v) => _fuelType.value = v,
        );
      },
    );
  }

  Widget _buildTransmissionDropdown() {
    return ValueListenableBuilder<String?>(
      valueListenable: _transmission,
      builder: (context, val, _) {
        return DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: val,
          decoration: InputDecoration(
            labelText: 'Transmission',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
          items: ['Manual', 'Automatic']
              .map((type) => DropdownMenuItem(value: type, child: Text(type)))
              .toList(),
          onChanged: (v) => _transmission.value = v,
        );
      },
    );
  }

  Widget _buildStatusDropdown() {
    return ValueListenableBuilder<String>(
      valueListenable: _status,
      builder: (context, val, _) {
        return DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: val,
          decoration: InputDecoration(
            labelText: 'Status',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
          items: ['Active', 'In-Shop', 'Out-of-Service', 'Retired']
              .map(
                (status) =>
                    DropdownMenuItem(value: status, child: Text(status)),
              )
              .toList(),
          onChanged: (v) => _status.value = v ?? 'Active',
        );
      },
    );
  }
}
