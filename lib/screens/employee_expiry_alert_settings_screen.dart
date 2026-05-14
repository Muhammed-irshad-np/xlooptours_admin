import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../features/employee/domain/entities/employee_settings_entity.dart';
import '../features/employee/presentation/providers/employee_provider.dart';

class EmployeeExpiryAlertSettingsScreen extends StatefulWidget {
  const EmployeeExpiryAlertSettingsScreen({super.key});

  @override
  State<EmployeeExpiryAlertSettingsScreen> createState() => _EmployeeExpiryAlertSettingsScreenState();
}

class _EmployeeExpiryAlertSettingsScreenState extends State<EmployeeExpiryAlertSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _iqamaController;
  late TextEditingController _drivingLicenseController;
  late TextEditingController _passportController;
  late TextEditingController _saudiVisaController;
  late TextEditingController _bahrainVisaController;
  late TextEditingController _bahrainResidenceController;
  late TextEditingController _dubaiVisaController;
  late TextEditingController _qatarVisaController;
  late TextEditingController _phoneRechargeController;
  late TextEditingController _healthInsuranceController;
  late TextEditingController _tafweedController;

  @override
  void initState() {
    super.initState();
    _iqamaController = TextEditingController();
    _drivingLicenseController = TextEditingController();
    _passportController = TextEditingController();
    _saudiVisaController = TextEditingController();
    _bahrainVisaController = TextEditingController();
    _bahrainResidenceController = TextEditingController();
    _dubaiVisaController = TextEditingController();
    _qatarVisaController = TextEditingController();
    _phoneRechargeController = TextEditingController();
    _healthInsuranceController = TextEditingController();
    _tafweedController = TextEditingController();

    // Fetch settings on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmployeeProvider>().fetchEmployeeSettings().then((_) {
        if (!mounted) return;
        final settings = context.read<EmployeeProvider>().settings;
          if (settings != null) {
            _iqamaController.text = settings.iqamaAlertDays.toString();
            _drivingLicenseController.text = settings.drivingLicenseAlertDays.toString();
            _passportController.text = settings.passportAlertDays.toString();
            _saudiVisaController.text = settings.saudiVisaAlertDays.toString();
            _bahrainVisaController.text = settings.bahrainVisaAlertDays.toString();
            _bahrainResidenceController.text = settings.bahrainResidenceAlertDays.toString();
            _dubaiVisaController.text = settings.dubaiVisaAlertDays.toString();
            _qatarVisaController.text = settings.qatarVisaAlertDays.toString();
            _phoneRechargeController.text = settings.phoneRechargeAlertDays.toString();
            _healthInsuranceController.text = settings.healthInsuranceAlertDays.toString();
            _tafweedController.text = settings.tafweedAlertDays.toString();
          }
      });
    });
  }

  @override
  void dispose() {
    _iqamaController.dispose();
    _drivingLicenseController.dispose();
    _passportController.dispose();
    _saudiVisaController.dispose();
    _bahrainVisaController.dispose();
    _bahrainResidenceController.dispose();
    _dubaiVisaController.dispose();
    _qatarVisaController.dispose();
    _phoneRechargeController.dispose();
    _healthInsuranceController.dispose();
    _tafweedController.dispose();
    super.dispose();
  }

  void _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      final provider = context.read<EmployeeProvider>();
      final newSettings = EmployeeSettingsEntity(
        iqamaAlertDays: int.parse(_iqamaController.text),
        drivingLicenseAlertDays: int.parse(_drivingLicenseController.text),
        passportAlertDays: int.parse(_passportController.text),
        saudiVisaAlertDays: int.parse(_saudiVisaController.text),
        bahrainVisaAlertDays: int.parse(_bahrainVisaController.text),
        bahrainResidenceAlertDays: int.parse(_bahrainResidenceController.text),
        dubaiVisaAlertDays: int.parse(_dubaiVisaController.text),
        qatarVisaAlertDays: int.parse(_qatarVisaController.text),
        phoneRechargeAlertDays: int.parse(_phoneRechargeController.text),
        healthInsuranceAlertDays: int.parse(_healthInsuranceController.text),
        tafweedAlertDays: int.parse(_tafweedController.text),
      );

      try {
        await provider.updateEmployeeSettings(newSettings);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Alert settings updated successfully')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update settings: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Alert Settings'),
        centerTitle: true,
      ),
      body: Consumer<EmployeeProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.settings == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(24.w),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildHeader(
                    'Global Expiry Alerts',
                    'Set how many days before expiry you want to receive notifications. These settings apply to all employees.',
                  ),
                  SizedBox(height: 32.h),
                  _buildSettingField(
                    label: 'Iqama Alert',
                    controller: _iqamaController,
                    icon: Icons.badge,
                    color: Colors.blue,
                  ),
                  SizedBox(height: 24.h),
                  _buildSettingField(
                    label: 'Health Insurance Alert',
                    controller: _healthInsuranceController,
                    icon: Icons.health_and_safety,
                    color: Colors.pink,
                  ),
                  SizedBox(height: 24.h),
                  _buildSettingField(
                    label: 'Tafweed (Authorization) Alert',
                    controller: _tafweedController,
                    icon: Icons.assignment_turned_in,
                    color: Colors.deepPurple,
                  ),
                  SizedBox(height: 24.h),
                  _buildSettingField(
                    label: 'Driving License Alert',
                    controller: _drivingLicenseController,
                    icon: Icons.drive_eta,
                    color: Colors.orange,
                  ),
                  SizedBox(height: 24.h),
                  _buildSettingField(
                    label: 'Passport Alert',
                    controller: _passportController,
                    icon: Icons.book,
                    color: Colors.green,
                  ),
                  SizedBox(height: 24.h),
                  _buildSettingField(
                    label: 'Saudi Visa Alert',
                    controller: _saudiVisaController,
                    icon: Icons.airplane_ticket,
                    color: Colors.purple,
                  ),
                  SizedBox(height: 24.h),
                  _buildSettingField(
                    label: 'Bahrain Visa Alert',
                    controller: _bahrainVisaController,
                    icon: Icons.airplane_ticket_outlined,
                    color: Colors.teal,
                  ),
                  SizedBox(height: 24.h),
                  _buildSettingField(
                    label: 'Bahrain Residence Alert',
                    controller: _bahrainResidenceController,
                    icon: Icons.contact_mail,
                    color: Colors.indigoAccent,
                  ),
                  SizedBox(height: 24.h),
                  _buildSettingField(
                    label: 'Dubai Visa Alert',
                    controller: _dubaiVisaController,
                    icon: Icons.flight_takeoff,
                    color: Colors.amber,
                  ),
                  SizedBox(height: 24.h),
                  _buildSettingField(
                    label: 'Qatar Visa Alert',
                    controller: _qatarVisaController,
                    icon: Icons.flight,
                    color: Colors.indigo,
                  ),
                  SizedBox(height: 24.h),
                  _buildSettingField(
                    label: 'Phone Recharge Alert',
                    controller: _phoneRechargeController,
                    icon: Icons.phone_android,
                    color: Colors.redAccent,
                  ),

                  SizedBox(height: 48.h),
                  SizedBox(
                    width: double.infinity,
                    height: 50.h,
                    child: ElevatedButton(
                      onPressed: provider.isLoading ? null : _saveSettings,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: provider.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              'Save Settings',
                              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
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

  Widget _buildHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 22.sp,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14.sp,
            color: Colors.black54,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 12.h),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: color),
            suffixText: 'days before',
            hintText: 'e.g. 30',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
            filled: true,
            fillColor: color.withValues(alpha: 0.05),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a value';
            }
            if (int.tryParse(value) == null) {
              return 'Please enter a valid number';
            }
            return null;
          },
        ),
      ],
    );
  }
}
