import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:xloop_invoice/features/employee/presentation/providers/employee_provider.dart';
import 'package:xloop_invoice/features/employee/domain/entities/employee_entity.dart';
import 'package:xloop_invoice/features/customer/presentation/providers/customer_provider.dart';
import '../../domain/entities/feedback_entity.dart';
import '../providers/feedback_provider.dart';

class FeedbackFormScreen extends StatefulWidget {
  final String? prefilledClientName;
  final String? prefilledCompanyName;
  final String? prefilledDriverName;

  const FeedbackFormScreen({
    super.key,
    this.prefilledClientName,
    this.prefilledCompanyName,
    this.prefilledDriverName,
  });

  @override
  State<FeedbackFormScreen> createState() => _FeedbackFormScreenState();
}

class _FeedbackFormScreenState extends State<FeedbackFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Trip Details
  DateTime? _dateOfTrip;
  final _driverNameController = TextEditingController();
  final _caseCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmployeeProvider>().fetchAllEmployees();
      context.read<CustomerProvider>().fetchAllCustomers();
    });
    if (widget.prefilledDriverName != null) {
      _driverNameController.text = widget.prefilledDriverName!;
    }
    if (widget.prefilledClientName != null) {
      _clientNameController.text = widget.prefilledClientName!;
    }
    if (widget.prefilledCompanyName != null) {
      _submitterNameController.text = widget.prefilledCompanyName!;
    }
  }

  // Ratings
  int _safetyRating = 0;
  int _professionalismRating = 0;
  int _communicationRating = 0;
  int _punctualityRating = 0;
  int _vehicleConditionRating = 0;

  // Open-ended
  final _excellenceController = TextEditingController();
  final _improvementController = TextEditingController();

  // Incident
  bool _incidentReported = false;
  final _incidentDescriptionController = TextEditingController();

  // Submitted By
  final _clientNameController = TextEditingController();
  final _submitterNameController = TextEditingController();

  // Brand colors matching the image
  final Color _bgColor = const Color(0xFFF7F6F2);
  final Color _primaryGreen = const Color(0xFF1C9E73);
  final Color _darkGreenText = const Color(0xFF1B4E41);

  @override
  void dispose() {
    _driverNameController.dispose();
    _caseCodeController.dispose();
    _excellenceController.dispose();
    _improvementController.dispose();
    _incidentDescriptionController.dispose();
    _clientNameController.dispose();
    _submitterNameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_safetyRating == 0 ||
        _professionalismRating == 0 ||
        _communicationRating == 0 ||
        _punctualityRating == 0 ||
        _vehicleConditionRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide all service ratings.')),
      );
      return;
    }

    if (_dateOfTrip == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select the date of your trip.')),
      );
      return;
    }

    // Strict Case Code Validation in SnackBar
    final enteredCode = _caseCodeController.text.trim();
    final clientName = _clientNameController.text.trim();

    if (enteredCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Case code is required.')),
      );
      return;
    }

    if (clientName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer name is required.')),
      );
      return;
    }

    final customerProvider = context.read<CustomerProvider>();
    if (customerProvider.isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verifying records, please wait...')),
      );
      return;
    }

    final matchingCustomers = customerProvider.customers.where(
      (c) => c.name.toLowerCase() == clientName.toLowerCase(),
    );

    if (matchingCustomers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer record not found. Please contact support.')),
      );
      return;
    }

    final customer = matchingCustomers.first;
    if (customer.assignedCaseCodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No assigned case codes found. Please contact support.')),
      );
      return;
    }

    final isValid = customer.assignedCaseCodes.any(
      (code) => code.toLowerCase() == enteredCode.toLowerCase(),
    );

    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid case code entered.')),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      final feedback = FeedbackEntity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        dateOfTrip: _dateOfTrip!,
        driverName: _driverNameController.text.trim(),
        caseCode: enteredCode,
        safetyRating: _safetyRating,
        professionalismRating: _professionalismRating,
        communicationRating: _communicationRating,
        punctualityRating: _punctualityRating,
        vehicleConditionRating: _vehicleConditionRating,
        areasOfExcellence: _excellenceController.text.trim().isNotEmpty
            ? _excellenceController.text.trim()
            : null,
        areasOfImprovement: _improvementController.text.trim().isNotEmpty
            ? _improvementController.text.trim()
            : null,
        incidentReported: _incidentReported,
        incidentDescription: _incidentReported && _incidentDescriptionController.text.trim().isNotEmpty
            ? _incidentDescriptionController.text.trim()
            : null,
        clientName: clientName,
        submitterName: _submitterNameController.text.trim().isNotEmpty
            ? _submitterNameController.text.trim()
            : null,
        createdAt: DateTime.now(),
      );

      context.read<FeedbackProvider>().submitFeedback(feedback);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfTrip ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryGreen,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateOfTrip = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Consumer<FeedbackProvider>(
          builder: (context, provider, child) {
            if (provider.isSuccess) {
              return _buildSuccessScreen();
            }

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 40),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header Badge
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: _primaryGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                  color: _primaryGreen.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.access_time_filled,
                                    color: _darkGreenText, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Driver Feedback',
                                  style: GoogleFonts.merriweather(
                                    color: _darkGreenText,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Main Title
                        Text(
                          'How was your trip?',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.merriweather(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Subtitle
                        Text(
                          'Your feedback helps us maintain high service standards.\nAll fields marked * are required.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.notoSans(
                            fontSize: 14,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 40),

                        // TRIP DETAILS
                        _buildSectionCard(
                          icon: Icons.calendar_today_outlined,
                          title: 'TRIP DETAILS',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildFieldLabel('Date of trip *'),
                              GestureDetector(
                                onTap: _pickDate,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 16),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.white,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _dateOfTrip == null
                                            ? 'dd-mm-yyyy'
                                            : DateFormat('dd-MM-yyyy')
                                                .format(_dateOfTrip!),
                                        style: TextStyle(
                                          color: _dateOfTrip == null
                                              ? Colors.grey[500]
                                              : Colors.black87,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Icon(Icons.calendar_today,
                                          color: Colors.grey[600], size: 20),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildFieldLabel('Driver\'s name *'),
                              Consumer<EmployeeProvider>(
                                builder: (context, employeeProvider, _) {
                                  final allEmployees = employeeProvider.employees;
                                  final drivers = allEmployees.where((e) =>
                                      e.isActive &&
                                      (e.position.toLowerCase().contains('driver') ||
                                          e.driverType != null)).toList();

                                  return _buildTextField(
                                    controller: _driverNameController,
                                    hintText: employeeProvider.isLoading
                                        ? "Loading drivers..."
                                        : "Select driver from list",
                                    readOnly: true,
                                    suffixIcon: widget.prefilledDriverName != null
                                        ? const Icon(Icons.lock_outline, color: Colors.grey)
                                        : const Icon(Icons.arrow_drop_down_rounded, color: Colors.grey, size: 28),
                                    onTap: widget.prefilledDriverName != null
                                        ? null
                                        : () => _showDriverSearchBottomSheet(drivers),
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                            ? 'Driver name is required'
                                            : null,
                                  );
                                },
                              ),
                              const SizedBox(height: 20),
                              _buildFieldLabel('Case Code *'),
                              Consumer<CustomerProvider>(
                                builder: (context, customerProvider, _) {
                                  return _buildTextField(
                                    controller: _caseCodeController,
                                    hintText: "Enter case code",
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // SERVICE RATINGS
                        _buildSectionCard(
                          icon: Icons.star_border,
                          title: 'SERVICE RATINGS',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildRatingRow(
                                title: 'Safety',
                                subtitle:
                                    'Adherence to traffic rules, smooth driving',
                                icon: Icons.shield_outlined,
                                value: _safetyRating,
                                onChanged: (val) =>
                                    setState(() => _safetyRating = val),
                              ),
                              const Divider(),
                              _buildRatingRow(
                                title: 'Professionalism',
                                subtitle: 'Appearance, attitude, and conduct',
                                icon: Icons.person_outline,
                                value: _professionalismRating,
                                onChanged: (val) => setState(
                                    () => _professionalismRating = val),
                              ),
                              const Divider(),
                              _buildRatingRow(
                                title: 'Communication',
                                subtitle: 'Clarity, courtesy, and responsiveness',
                                icon: Icons.chat_bubble_outline,
                                value: _communicationRating,
                                onChanged: (val) =>
                                    setState(() => _communicationRating = val),
                              ),
                              const Divider(),
                              _buildRatingRow(
                                title: 'Punctuality',
                                subtitle: 'On-time pickup and efficient route',
                                icon: Icons.access_time,
                                value: _punctualityRating,
                                onChanged: (val) =>
                                    setState(() => _punctualityRating = val),
                              ),
                              const Divider(),
                              _buildRatingRow(
                                title: 'Vehicle Condition & Cleanliness',
                                subtitle: 'Comfort, tidiness, and maintenance',
                                icon: Icons.directions_car_outlined,
                                value: _vehicleConditionRating,
                                onChanged: (val) => setState(
                                    () => _vehicleConditionRating = val),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // OPEN-ENDED FEEDBACK
                        _buildSectionCard(
                          icon: Icons.description_outlined,
                          title: 'OPEN-ENDED FEEDBACK',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.star,
                                      color: Color(0xFF1B4E41), size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Areas of Excellence',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _darkGreenText,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildTextField(
                                controller: _excellenceController,
                                hintText:
                                    'What did the driver do particularly well? (route knowledge, helpfulness, attitude...)',
                                maxLines: 4,
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded,
                                      color: Colors.red[800], size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Areas of Improvement',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red[800],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildTextField(
                                controller: _improvementController,
                                hintText:
                                    'What could be done better next time? (punctuality, communication, driving style...)',
                                maxLines: 4,
                                borderColor: _primaryGreen.withOpacity(0.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // INCIDENT REPORTING
                        _buildSectionCard(
                          icon: Icons.error_outline,
                          title: 'INCIDENT REPORTING',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Report an incident during this trip',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                  Switch(
                                    value: _incidentReported,
                                    activeColor: _primaryGreen,
                                    onChanged: (val) {
                                      setState(() {
                                        _incidentReported = val;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              if (_incidentReported) ...[
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded,
                                        color: Colors.red[800], size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'What incident occurred? *',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red[800],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildTextField(
                                  controller: _incidentDescriptionController,
                                  hintText:
                                      'Please describe the incident in detail (safety concern, route deviation, accident, driver behavior...)',
                                  maxLines: 4,
                                  borderColor: Colors.red[300],
                                  validator: (value) {
                                    if (_incidentReported && (value == null || value.trim().isEmpty)) {
                                      return 'Please describe the incident';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // SUBMITTED BY
                        _buildSectionCard(
                          icon: Icons.person_outline,
                          title: 'SUBMITTED BY',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildFieldLabel('Customer name *'),
                              _buildTextField(
                                controller: _clientNameController,
                                hintText: 'Enter your name',
                                readOnly: widget.prefilledClientName != null,
                                suffixIcon: widget.prefilledClientName != null
                                    ? const Icon(Icons.lock_outline, color: Colors.grey)
                                    : null,
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                        ? 'Customer name is required'
                                        : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Submit Button
                        if (provider.errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              provider.errorMessage!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        ElevatedButton.icon(
                          onPressed: provider.isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          icon: provider.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send_outlined),
                          label: Text(
                            provider.isLoading
                                ? 'Submitting...'
                                : 'Submit Feedback',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSuccessScreen() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _primaryGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_circle_outline,
                      color: _primaryGreen, size: 80),
                ),
                const SizedBox(height: 32),
                Text(
                  'Thank You!',
                  style: GoogleFonts.merriweather(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: _darkGreenText,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Your feedback has been successfully submitted and helps us improve our services.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSans(
                    fontSize: 16,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                OutlinedButton(
                  onPressed: () {
                    // Reset form and provider state
                    context.read<FeedbackProvider>().resetState();
                    setState(() {
                      _formKey.currentState?.reset();
                      _dateOfTrip = null;
                      _driverNameController.clear();
                      _caseCodeController.clear();
                      _safetyRating = 0;
                      _professionalismRating = 0;
                      _communicationRating = 0;
                      _punctualityRating = 0;
                      _vehicleConditionRating = 0;
                      _excellenceController.clear();
                      _improvementController.clear();
                      _incidentReported = false;
                      _incidentDescriptionController.clear();
                      _clientNameController.clear();
                      _submitterNameController.clear();
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryGreen,
                    side: BorderSide(color: _primaryGreen),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Submit Another Response'),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(icon, color: _darkGreenText, size: 20),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.notoSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: _darkGreenText,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey[200]),
          Padding(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[800],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
    String? Function(String?)? validator,
    Color? borderColor,
    bool readOnly = false,
    Widget? suffixIcon,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey[400]),
        filled: true,
        fillColor: readOnly ? Colors.grey[100] : Colors.white,
        suffixIcon: suffixIcon,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor ?? Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor ?? Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _primaryGreen),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildRatingRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (index) {
              return GestureDetector(
                onTap: () => onChanged(index + 1),
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    index < value ? Icons.star : Icons.star_border,
                    color: index < value ? Colors.amber[600] : Colors.grey[300],
                    size: 28,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  void _showDriverSearchBottomSheet(List<EmployeeEntity> drivers) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _DriverSearchBottomSheet(
          drivers: drivers,
          onSelected: (driver) {
            setState(() {
              _driverNameController.text = driver.fullName;
            });
          },
        );
      },
    );
  }
}

class _DriverSearchBottomSheet extends StatefulWidget {
  final List<EmployeeEntity> drivers;
  final ValueChanged<EmployeeEntity> onSelected;

  const _DriverSearchBottomSheet({
    required this.drivers,
    required this.onSelected,
  });

  @override
  State<_DriverSearchBottomSheet> createState() => _DriverSearchBottomSheetState();
}

class _DriverSearchBottomSheetState extends State<_DriverSearchBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredDrivers = widget.drivers.where((driver) {
      return driver.fullName.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Select Driver',
            style: GoogleFonts.inter(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1B4E41),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Search Field
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7F6F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.search, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search driver by name...',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: (val) {
                      setState(() {
                        _query = val.trim();
                      });
                    },
                  ),
                ),
                if (_query.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() {
                        _query = '';
                      });
                    },
                    child: Icon(Icons.close, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Drivers list
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: filteredDrivers.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_off_outlined, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text(
                          'No drivers found',
                          style: TextStyle(color: Colors.grey[600], fontSize: 15),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: filteredDrivers.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final driver = filteredDrivers[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF1C9E73).withOpacity(0.1),
                          backgroundImage: driver.imageUrl != null && driver.imageUrl!.isNotEmpty
                              ? NetworkImage(driver.imageUrl!)
                              : null,
                          child: driver.imageUrl == null || driver.imageUrl!.isEmpty
                              ? Text(
                                  driver.fullName.isNotEmpty ? driver.fullName[0].toUpperCase() : 'D',
                                  style: const TextStyle(
                                    color: Color(0xFF1B4E41),
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        title: Text(
                          driver.fullName,
                          style: GoogleFonts.inter(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        subtitle: Text(
                          driver.phoneNumber,
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                        onTap: () {
                          widget.onSelected(driver);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
