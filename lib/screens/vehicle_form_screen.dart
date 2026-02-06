import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/employee_model.dart';
import '../models/vehicle_make_model.dart'; // Added
import '../models/vehicle_model.dart';
import '../services/database_service.dart';
import '../services/image_service.dart';

class VehicleFormScreen extends StatefulWidget {
  final VehicleModel? vehicle;

  const VehicleFormScreen({super.key, this.vehicle});

  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  // Replaced controllers with selected value variables for Dropdowns
  String? _selectedMake;
  String? _selectedModel;
  int? _selectedYear;
  String? _selectedColor;

  // Controllers for free-text fields
  final _plateNumberController = TextEditingController();
  final _typeController = TextEditingController();

  String? _assignedDriverId;
  XFile? _selectedImage;
  String? _currentImageUrl;
  bool _isLoading = false;
  bool _isUploadingImage = false;
  double _uploadProgress = 0.0;
  List<EmployeeModel> _drivers = [];

  // Vehicle Master Data
  List<VehicleMakeModel> _allMakes = [];
  List<VehicleModelDetail> _availableModels = [];
  List<int> _availableYears = [];
  List<String> _availableColors = [];

  @override
  void initState() {
    super.initState();
    _loadData(); // Combined loading
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([_loadDrivers(), _loadVehicleMasterData()]);

      if (widget.vehicle != null) {
        _populateFormData();
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadVehicleMasterData() async {
    _allMakes = await DatabaseService.instance.getAllVehicleMakes();
  }

  Future<void> _loadDrivers() async {
    final employees = await DatabaseService.instance.getAllEmployees();
    _drivers = employees.where((e) {
      final isDriver =
          e.position.toLowerCase().contains('driver') ||
          (e.driverType != null && e.driverType!.isNotEmpty);
      return e.isActive && isDriver;
    }).toList();
  }

  void _populateFormData() {
    final v = widget.vehicle!;
    _selectedMake = v.make;
    _selectedModel = v.model;
    _selectedYear = v.year;
    _selectedColor = v.color;

    _plateNumberController.text = v.plateNumber;
    _typeController.text = v.type;
    _assignedDriverId = v.assignedDriverId;
    _currentImageUrl = v.imageUrl;

    // Trigger updates to available lists based on initial make
    _updateAvailableOptions(_selectedMake);
  }

  void _updateAvailableOptions(String? makeName) {
    if (makeName == null) {
      _availableModels = [];
      _availableYears = [];
      _availableColors = [];
      return;
    }

    final make = _allMakes.firstWhere(
      (m) => m.name == makeName,
      orElse: () =>
          VehicleMakeModel(id: '', name: '', models: [], years: [], colors: []),
    );

    _availableModels = make.models;
    _availableYears = make.years;
    _availableColors = make.colors;

    // Handle legacy/custom values not in the list
    if (_selectedModel != null) {
      final exists = _availableModels.any((m) => m.name == _selectedModel);
      if (!exists) {
        // Create a temporary entry for display if not found, assume default type
        _availableModels.add(
          VehicleModelDetail(name: _selectedModel!, type: 'Sedan'),
        );
      }
    }
    if (_selectedYear != null && !_availableYears.contains(_selectedYear)) {
      _availableYears.add(_selectedYear!);
    }
    if (_selectedColor != null && !_availableColors.contains(_selectedColor)) {
      _availableColors.add(_selectedColor!);
    }
  }

  Future<void> _pickImage() async {
    final image = await ImageService.instance.pickImage();
    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  Future<void> _saveVehicle() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _isUploadingImage = _selectedImage != null; // Set uploading flag
      _uploadProgress = 0.0;
    });
    debugPrint('VehicleFormScreen: Starting save process...');

    try {
      final vehicleId = widget.vehicle?.id ?? const Uuid().v4();
      String? imageUrl = _currentImageUrl;

      if (_selectedImage != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Uploading image... Please wait.')),
          );
        }
        debugPrint('VehicleFormScreen: Uploading image...');
        imageUrl = await ImageService.instance.uploadVehicleImage(
          _selectedImage!,
          vehicleId,
          onProgress: (progress) {
            if (mounted) {
              setState(() => _uploadProgress = progress);
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
        // Set uploading to false after image part is done
        if (mounted) {
          setState(() {
            _isUploadingImage = false;
          });
        }
      }

      final vehicle = VehicleModel(
        id: vehicleId,
        make: _selectedMake!,
        model: _selectedModel!,
        year: _selectedYear!,
        color: _selectedColor!,
        plateNumber: _plateNumberController.text,
        type: _typeController.text,
        assignedDriverId: _assignedDriverId,
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

      if (widget.vehicle != null) {
        await DatabaseService.instance.updateVehicle(vehicle);
      } else {
        await DatabaseService.instance.insertVehicle(vehicle);
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
      if (mounted) setState(() => _isLoading = false);
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
      body: _isLoading
          ? Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 40.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isUploadingImage) ...[
                      LinearProgressIndicator(value: _uploadProgress),
                      SizedBox(height: 16.h),
                      Text(
                        'Uploading Image: ${(_uploadProgress * 100).toInt()}%',
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
            ),
    );
  }

  Widget _buildMakeDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedMake,
      decoration: InputDecoration(
        labelText: 'Make',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
      ),
      items: _allMakes.map((make) {
        return DropdownMenuItem<String>(
          value: make.name,
          child: Text(make.name),
        );
      }).toList(),
      onChanged: (val) {
        setState(() {
          _selectedMake = val;
          _selectedModel = null;
          _selectedYear = null;
          _selectedColor = null;
          _updateAvailableOptions(val);
        });
      },
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
    );
  }

  Widget _buildModelDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedModel,
      decoration: InputDecoration(
        labelText: 'Model',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
        enabled: _selectedMake != null,
      ),
      items: _availableModels.map((model) {
        // Display generic 'Sedan' if type is missing, or show existing type
        final displayType = model.type.isNotEmpty ? model.type : '';
        final label = displayType.isNotEmpty
            ? '${model.name} ($displayType)'
            : model.name;

        return DropdownMenuItem<String>(value: model.name, child: Text(label));
      }).toList(),
      onChanged: _selectedMake == null
          ? null
          : (val) {
              setState(() {
                _selectedModel = val;
                // Auto-populate type
                if (val != null) {
                  final selectedModelDetail = _availableModels.firstWhere(
                    (m) => m.name == val,
                    orElse: () => VehicleModelDetail(name: val, type: ''),
                  );
                  if (selectedModelDetail.type.isNotEmpty) {
                    _typeController.text = selectedModelDetail.type;
                  }
                }
              });
            },
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
    );
  }

  Widget _buildYearDropdown() {
    return DropdownButtonFormField<int>(
      value: _selectedYear,
      decoration: InputDecoration(
        labelText: 'Year',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
        enabled: _selectedMake != null,
      ),
      items: _availableYears.map((year) {
        return DropdownMenuItem<int>(value: year, child: Text(year.toString()));
      }).toList(),
      onChanged: _selectedMake == null
          ? null
          : (val) {
              setState(() => _selectedYear = val);
            },
      validator: (v) => v == null ? 'Required' : null,
    );
  }

  Widget _buildColorDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedColor,
      decoration: InputDecoration(
        labelText: 'Color',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
        enabled: _selectedMake != null,
      ),
      items: _availableColors.map((color) {
        return DropdownMenuItem<String>(value: color, child: Text(color));
      }).toList(),
      onChanged: _selectedMake == null
          ? null
          : (val) {
              setState(() => _selectedColor = val);
            },
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
    );
  }

  // ... (ImagePicker, TextField, driverDropdown helpers essentially same as before but adjusted if needed)
  Widget _buildImagePicker() {
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
            image: _selectedImage != null
                ? DecorationImage(
                    image: kIsWeb
                        ? NetworkImage(_selectedImage!.path)
                        : FileImage(File(_selectedImage!.path))
                              as ImageProvider,
                    fit: BoxFit.cover,
                  )
                : _currentImageUrl != null
                ? DecorationImage(
                    image: NetworkImage(_currentImageUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: _selectedImage == null && _currentImageUrl == null
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
    return DropdownButtonFormField<String>(
      value: _assignedDriverId,
      decoration: InputDecoration(
        labelText: 'Assigned Driver',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
      ),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('None')),
        ..._drivers.map((employee) {
          final isInternal = employee.driverType == 'Internal';
          return DropdownMenuItem<String>(
            value: employee.id,
            child: Row(
              children: [
                Text(employee.fullName),
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: isInternal
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4.r),
                    border: Border.all(
                      color: isInternal ? Colors.green : Colors.orange,
                    ),
                  ),
                  child: Text(
                    employee.driverType ?? 'Unknown',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: isInternal ? Colors.green : Colors.orange,
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
        setState(() {
          _assignedDriverId = value;
        });
      },
    );
  }
}
