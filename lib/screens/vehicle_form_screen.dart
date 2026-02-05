import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/employee_model.dart';
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
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();
  final _plateNumberController = TextEditingController();
  final _typeController = TextEditingController();
  final _contactCardController = TextEditingController();

  String? _assignedDriverId;
  XFile? _selectedImage;
  String? _currentImageUrl;
  bool _isLoading = false;
  List<EmployeeModel> _drivers = [];

  @override
  void initState() {
    super.initState();
    _loadDrivers();
    if (widget.vehicle != null) {
      _makeController.text = widget.vehicle!.make;
      _modelController.text = widget.vehicle!.model;
      _yearController.text = widget.vehicle!.year.toString();
      _colorController.text = widget.vehicle!.color;
      _plateNumberController.text = widget.vehicle!.plateNumber;
      _typeController.text = widget.vehicle!.type;
      _contactCardController.text = widget.vehicle!.contactCardReference ?? '';
      _assignedDriverId = widget.vehicle!.assignedDriverId;
      _currentImageUrl = widget.vehicle!.imageUrl;
    }
  }

  Future<void> _loadDrivers() async {
    try {
      final employees = await DatabaseService.instance.getAllEmployees();
      // Filter for drivers if there's a specific type, otherwise show all or filter by job title
      // For now, listing all active employees
      setState(() {
        _drivers = employees.where((e) {
          final isDriver =
              e.position.toLowerCase().contains('driver') ||
              (e.driverType != null && e.driverType!.isNotEmpty);
          return e.isActive && isDriver;
        }).toList();
      });
    } catch (e) {
      debugPrint('Error loading drivers: $e');
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

    setState(() => _isLoading = true);

    try {
      final vehicleId = widget.vehicle?.id ?? const Uuid().v4();
      String? imageUrl = _currentImageUrl;

      if (_selectedImage != null) {
        imageUrl = await ImageService.instance.uploadVehicleImage(
          _selectedImage!,
          vehicleId,
        );
      }

      final vehicle = VehicleModel(
        id: vehicleId,
        make: _makeController.text,
        model: _modelController.text,
        year: int.tryParse(_yearController.text) ?? DateTime.now().year,
        color: _colorController.text,
        plateNumber: _plateNumberController.text,
        type: _typeController.text,
        assignedDriverId: _assignedDriverId,
        contactCardReference: _contactCardController.text.isNotEmpty
            ? _contactCardController.text
            : null,
        imageUrl: imageUrl,
        isActive: true,
      );

      if (widget.vehicle != null) {
        await DatabaseService.instance.updateVehicle(vehicle);
      } else {
        await DatabaseService.instance.insertVehicle(vehicle);
      }

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
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(24.w),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildImagePicker(),
                    SizedBox(height: 24.h),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField('Make', _makeController),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: _buildTextField('Model', _modelController),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            'Year',
                            _yearController,
                            isNumber: true,
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: _buildTextField('Color', _colorController),
                        ),
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
                    _buildTextField(
                      'Contact Card Reference',
                      _contactCardController,
                      required: false,
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
          return DropdownMenuItem<String>(
            value: employee.id,
            child: Text(employee.fullName),
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
