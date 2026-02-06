import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/employee_model.dart';
import '../models/vehicle_model.dart'; // Added
import '../services/database_service.dart';

class EmployeeFormScreen extends StatefulWidget {
  // ... (rest of class)

  final EmployeeModel? employee;

  const EmployeeFormScreen({super.key, this.employee});

  @override
  State<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends State<EmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _databaseService = DatabaseService.instance;

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _idNumberController;
  late TextEditingController _nationalityController;

  String _selectedPosition = 'Driver'; // Default
  String _selectedIdType = 'Iqama';
  String _selectedGender = 'Male';
  String _selectedDriverType = 'Internal';
  DateTime? _joinDate;
  DateTime? _birthDate;
  bool _isActive = true;
  String? _currentImageUrl;
  XFile? _pickedImage;
  final ImagePicker _picker = ImagePicker();

  bool _isSaving = false;
  List<VehicleModel> _availableVehicles = []; // Added
  String? _selectedVehicleId; // Added

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

    if (e != null) {
      if (_positions.contains(e.position)) {
        _selectedPosition = e.position;
      } else {
        _selectedPosition = 'Other';
      }

      if (_idTypes.contains(e.idType)) {
        _selectedIdType = e.idType;
      }

      if (_genders.contains(e.gender)) {
        _selectedGender = e.gender;
      }

      if (e.driverType != null && _driverTypes.contains(e.driverType)) {
        _selectedDriverType = e.driverType!;
      }

      _joinDate = e.joinDate;
      _birthDate = e.birthDate;
      _isActive = e.isActive;
      _currentImageUrl = e.imageUrl;
    }
    _loadVehicles(); // Load vehicles
  }

  // Added method to load vehicles
  Future<void> _loadVehicles() async {
    try {
      final vehicles = await _databaseService.getAllVehicles();
      setState(() {
        _availableVehicles = vehicles;
        // If editing, find the vehicle assigned to this driver
        if (widget.employee != null) {
          final assignedVehicle = vehicles
              .where((v) => v.assignedDriverId == widget.employee!.id)
              .firstOrNull;
          _selectedVehicleId = assignedVehicle?.id;
        }
      });
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
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isJoinDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isJoinDate
          ? (_joinDate ?? DateTime.now())
          : (_birthDate ?? DateTime(1990)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isJoinDate) {
          _joinDate = picked;
        } else {
          _birthDate = picked;
        }
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _pickedImage = image;
        });
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

    setState(() {
      _isSaving = true;
    });

    try {
      final id = widget.employee?.id ?? const Uuid().v4();

      final newEmployee = EmployeeModel(
        id: id,
        fullName: _nameController.text.trim(),
        position: _selectedPosition,
        email: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        nationality: _nationalityController.text.trim(),
        idType: _selectedIdType,
        idNumber: _idNumberController.text.trim(),
        joinDate: _joinDate,
        birthDate: _birthDate,
        gender: _selectedGender,
        driverType: _selectedPosition == 'Driver' ? _selectedDriverType : null,
        isActive: _isActive,
      );

      if (widget.employee == null) {
        await _databaseService.insertEmployee(newEmployee);
      } else {
        await _databaseService.updateEmployee(newEmployee);
      }

      // Handle Vehicle Assignment
      if (_selectedPosition == 'Driver') {
        await _databaseService.assignDriverToVehicle(
          _selectedVehicleId,
          id, // The employee ID
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
        setState(() {
          _isSaving = false;
        });
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
                        CircleAvatar(
                          radius: 50.r,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: _pickedImage != null
                              ? (kIsWeb
                                    ? NetworkImage(_pickedImage!.path)
                                    : FileImage(File(_pickedImage!.path))
                                          as ImageProvider)
                              : (_currentImageUrl != null
                                    ? NetworkImage(_currentImageUrl!)
                                    : null),
                          child:
                              (_pickedImage == null && _currentImageUrl == null)
                              ? Icon(
                                  Icons.person,
                                  size: 50.sp,
                                  color: Colors.grey[400],
                                )
                              : null,
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
                        child: _buildDropdown(
                          label: 'Position',
                          value: _selectedPosition,
                          items: _positions,
                          onChanged: (val) {
                            setState(() {
                              _selectedPosition = val!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  if (_selectedPosition == 'Driver') ...[
                    SizedBox(height: 16.h),
                    _buildDropdown(
                      label: 'Driver Type',
                      value: _selectedDriverType,
                      items: _driverTypes,
                      onChanged: (val) =>
                          setState(() => _selectedDriverType = val!),
                    ),
                    SizedBox(height: 16.h),
                    DropdownButtonFormField<String>(
                      value: _selectedVehicleId,
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
                        ..._availableVehicles.map((v) {
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
                        setState(() {
                          _selectedVehicleId = val;
                        });
                      },
                    ),
                  ],
                  SizedBox(height: 16.h),

                  // Contact Info
                  _buildSectionTitle('Contact Information'),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _phoneController,
                          label: 'Phone Number',
                          icon: Icons.phone,
                          validator: (v) =>
                              v!.isEmpty ? 'Please enter phone number' : null,
                        ),
                      ),
                      if (!(_selectedPosition == 'Driver' &&
                          _selectedDriverType == 'External')) ...[
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
                  ),
                  SizedBox(height: 16.h),

                  // Personal Details
                  _buildSectionTitle('Personal Details'),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          label: 'Gender',
                          value: _selectedGender,
                          items: _genders,
                          onChanged: (val) =>
                              setState(() => _selectedGender = val!),
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
                        child: _buildDropdown(
                          label: 'ID Type',
                          value: _selectedIdType,
                          items: _idTypes,
                          onChanged: (val) =>
                              setState(() => _selectedIdType = val!),
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
                  if (!(_selectedPosition == 'Driver' &&
                      _selectedDriverType == 'External')) ...[
                    SizedBox(height: 16.h),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDatePicker(
                            label: 'Birth Date',
                            date: _birthDate,
                            onTap: () => _selectDate(context, false),
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: _buildDatePicker(
                            label: 'Join Date',
                            date: _joinDate,
                            onTap: () => _selectDate(context, true),
                          ),
                        ),
                      ],
                    ),
                  ],

                  SizedBox(height: 24.h),
                  Divider(),
                  SwitchListTile(
                    title: const Text('Active Employee'),
                    subtitle: const Text('Is this employee currently working?'),
                    value: _isActive,
                    onChanged: (val) => setState(() => _isActive = val),
                  ),

                  SizedBox(height: 32.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveEmployee,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue[800],
                        foregroundColor: Colors.white,
                      ),
                      child: _isSaving
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
  }) {
    return TextFormField(
      controller: controller,
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
      value: value,
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
}
