import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../features/vehicle/domain/entities/vehicle_settings_entity.dart';
import '../features/vehicle/presentation/providers/vehicle_provider.dart';

class VehicleExpiryAlertSettingsScreen extends StatefulWidget {
  const VehicleExpiryAlertSettingsScreen({super.key});

  @override
  State<VehicleExpiryAlertSettingsScreen> createState() => _VehicleExpiryAlertSettingsScreenState();
}

class _VehicleExpiryAlertSettingsScreenState extends State<VehicleExpiryAlertSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _isthimaraController;
  late TextEditingController _fahasController;
  late TextEditingController _insuranceController;
  late TextEditingController _tafweedController;

  @override
  void initState() {
    super.initState();
    _isthimaraController = TextEditingController();
    _fahasController = TextEditingController();
    _insuranceController = TextEditingController();
    _tafweedController = TextEditingController();

    // Fetch settings on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VehicleProvider>().fetchVehicleSettings().then((_) {
        if (!mounted) return;
        final settings = context.read<VehicleProvider>().settings;
          if (settings != null) {
            _isthimaraController.text = settings.isthimaraAlertDays.toString();
            _fahasController.text = settings.fahasAlertDays.toString();
            _insuranceController.text = settings.insuranceAlertDays.toString();
            _tafweedController.text = settings.tafweedAlertDays.toString();
          }
      });
    });
  }

  @override
  void dispose() {
    _isthimaraController.dispose();
    _fahasController.dispose();
    _insuranceController.dispose();
    _tafweedController.dispose();
    super.dispose();
  }

  void _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      final provider = context.read<VehicleProvider>();
      final newSettings = VehicleSettingsEntity(
        isthimaraAlertDays: int.parse(_isthimaraController.text),
        fahasAlertDays: int.parse(_fahasController.text),
        insuranceAlertDays: int.parse(_insuranceController.text),
        tafweedAlertDays: int.parse(_tafweedController.text),
      );

      try {
        await provider.updateVehicleSettings(newSettings);
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
        title: const Text('Vehicle Alert Settings'),
        centerTitle: true,
      ),
      body: Consumer<VehicleProvider>(
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
                    'Set how many days before expiry you want to receive notifications. These settings apply to all vehicles unless overridden individually.',
                  ),
                  SizedBox(height: 32.h),
                  _buildSettingField(
                    label: 'Isthimara (Registration) Alert',
                    controller: _isthimaraController,
                    icon: Icons.assignment,
                    color: Colors.blue,
                  ),
                  SizedBox(height: 24.h),
                  _buildSettingField(
                    label: 'Fahas (Inspection) Alert',
                    controller: _fahasController,
                    icon: Icons.fact_check,
                    color: Colors.orange,
                  ),
                  SizedBox(height: 24.h),
                  _buildSettingField(
                    label: 'Insurance Alert',
                    controller: _insuranceController,
                    icon: Icons.verified_user,
                    color: Colors.green,
                  ),
                  SizedBox(height: 24.h),
                  _buildSettingField(
                    label: 'Tafweed (Authorization) Alert',
                    controller: _tafweedController,
                    icon: Icons.admin_panel_settings,
                    color: Colors.purple,
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
