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
import '../features/vehicle/presentation/providers/vehicle_provider.dart';
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

  final ValueNotifier<String?> _assignedEmployeeId = ValueNotifier(null);
  final ValueNotifier<XFile?> _selectedImage = ValueNotifier(null);
  final ValueNotifier<String?> _currentImageUrl = ValueNotifier(null);
  final ValueNotifier<bool> _isLoading = ValueNotifier(false);
  final ValueNotifier<bool> _isUploadingImage = ValueNotifier(false);
  final ValueNotifier<double> _uploadProgress = ValueNotifier(0.0);
  final ValueNotifier<List<EmployeeEntity>> _employees = ValueNotifier([]);

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
