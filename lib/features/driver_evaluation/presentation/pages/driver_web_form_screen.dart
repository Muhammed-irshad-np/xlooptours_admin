import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xloop_invoice/features/driver_evaluation/presentation/providers/driver_form_provider.dart';
import 'package:intl/intl.dart';

class DriverWebFormScreen extends StatefulWidget {
  final String evaluationId;

  const DriverWebFormScreen({super.key, required this.evaluationId});

  @override
  State<DriverWebFormScreen> createState() => _DriverWebFormScreenState();
}

class _DriverWebFormScreenState extends State<DriverWebFormScreen> {
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DriverFormProvider>().loadEvaluation(widget.evaluationId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Consumer<DriverFormProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading && provider.evaluation == null) {
                return const Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Loading evaluation…',
                  ),
                );
              }

              if (provider.errorMessage != null && provider.evaluation == null) {
                return _ErrorState(message: provider.errorMessage!);
              }

              final evaluation = provider.evaluation;
              if (evaluation == null) {
                return const _ErrorState(message: 'Evaluation not found.');
              }

              if (evaluation.status != 'pending' || evaluation.submittedAt != null) {
                return const _SuccessState(message: 'This evaluation has already been submitted.');
              }

              return SafeArea(
                child: Card(
                  margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: Colors.white,
                  child: Column(
                    children: [
                      // Form Header
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(
                          color: Color(0xFF13B1F2),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Driver Evaluation Form',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Complete all steps to submit vehicle and grooming details.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Progress Stepper indicator
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildStepDot(0, 'Details'),
                            _buildStepConnector(0),
                            _buildStepDot(1, 'Appearance'),
                            _buildStepConnector(1),
                            _buildStepDot(2, 'Vehicle'),
                          ],
                        ),
                      ),
                      const Divider(height: 32),
                      // Step Content
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          child: _buildStepContent(provider),
                        ),
                      ),
                      const Divider(height: 1),
                      // Form Footer Actions
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (_currentStep > 0)
                              OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    _currentStep--;
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Back'),
                              )
                            else
                              const SizedBox.shrink(),
                            const Spacer(),
                            ElevatedButton(
                              onPressed: provider.isLoading ? null : () => _handleNext(provider),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF13B1F2),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              child: provider.isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(_currentStep == 2 ? 'Submit' : 'Next'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStepDot(int step, String label) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? const Color(0xFF13B1F2)
                : (isCompleted ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : const Color(0xFF64748B),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector(int step) {
    final isCompleted = _currentStep > step;
    return Container(
      width: 60,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8).copyWith(bottom: 15),
      color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
    );
  }

  Widget _buildStepContent(DriverFormProvider provider) {
    switch (_currentStep) {
      case 0:
        return _buildDetailsStep(provider);
      case 1:
        return _buildAppearanceStep(provider);
      case 2:
        return _buildVehicleStep(provider);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDetailsStep(DriverFormProvider provider) {
    final evaluation = provider.evaluation!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Verification Details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 16),
        _buildInfoTile('Driver Name', evaluation.driverName, Icons.person),
        _buildInfoTile('Date of Evaluation', DateFormat('dd MMMM yyyy').format(DateTime.now()), Icons.calendar_today),
        _buildInfoTile(
          'Vehicle info',
          evaluation.vehicleId != null
              ? (provider.vehicleInfo != null
                  ? '${provider.vehicleInfo!['make']} ${provider.vehicleInfo!['model']} (${provider.vehicleInfo!['plateNumber']})'
                  : 'Loading vehicle details…')
              : 'No Vehicle Assigned',
          Icons.directions_car,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBAE6FD)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Color(0xFF0284C7)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Instructions:\nYou are required to take photos of yourself and the vehicle. Gallery uploads are disabled, so please ensure you are with the vehicle and have your uniform on before starting.',
                  style: TextStyle(color: Color(0xFF0369A1), fontSize: 13, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppearanceStep(DriverFormProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 2: Grooming & Uniform',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 8),
        const Text(
          'Please snap photos for your appearance evaluation.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
        ),
        const SizedBox(height: 20),
        _buildCaptureTile(
          provider,
          fieldKey: 'full_body',
          title: 'Full Body Photo',
          description: 'Stand straight showing your complete uniform.',
        ),
        const SizedBox(height: 16),
        _buildCaptureTile(
          provider,
          fieldKey: 'shoes',
          title: 'Shoes Photo',
          description: 'Snap a clear photo of your shoes.',
        ),
      ],
    );
  }

  Widget _buildVehicleStep(DriverFormProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 3: Vehicle Condition',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 8),
        const Text(
          'Please take photos of the vehicle condition, interior, and exterior.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
        ),
        const SizedBox(height: 20),
        _buildCaptureTile(provider, fieldKey: 'vehicle_front', title: 'Vehicle Front', description: 'Clear shot of the front side.'),
        const SizedBox(height: 16),
        _buildCaptureTile(provider, fieldKey: 'vehicle_back', title: 'Vehicle Back', description: 'Clear shot of the rear side.'),
        const SizedBox(height: 16),
        _buildCaptureTile(provider, fieldKey: 'vehicle_left', title: 'Vehicle Left', description: 'Clear shot of the driver side.'),
        const SizedBox(height: 16),
        _buildCaptureTile(provider, fieldKey: 'vehicle_right', title: 'Vehicle Right', description: 'Clear shot of the passenger side.'),
        const SizedBox(height: 16),
        _buildCaptureTile(provider, fieldKey: 'cabin_front', title: 'Front Cabin Interior', description: 'Show clean dashboard, seat, and console.'),
        const SizedBox(height: 16),
        _buildCaptureTile(provider, fieldKey: 'cabin_rear', title: 'Rear Cabin Interior', description: 'Show clean rear passenger seats and carpet.'),
        if (provider.errorMessage != null) ...[
          const SizedBox(height: 24),
          Center(
            child: Text(
              provider.errorMessage!,
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF64748B), size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureTile(
    DriverFormProvider provider, {
    required String fieldKey,
    required String title,
    required String description,
  }) {
    final uploadState = provider.mediaUploads[fieldKey];
    final isUploading = uploadState?.isUploading ?? false;
    final url = uploadState?.url;
    final error = uploadState?.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: url != null ? const Color(0xFF10B981) : (error != null ? Colors.red : const Color(0xFFE2E8F0)),
          width: url != null ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                if (error != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Error: $error',
                    style: const TextStyle(color: Colors.red, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Upload visual button / thumbnail
          if (isUploading)
            const SizedBox(
              width: 60,
              height: 60,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (url != null)
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: NetworkImage(url),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: const Icon(Icons.check, color: Colors.white, size: 12),
                  ),
                ),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: Tooltip(
                      message: 'Recapture photo for $title',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => provider.captureAndUploadImage(fieldKey),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Tooltip(
              message: 'Capture photo for $title',
              child: ElevatedButton(
                onPressed: () => provider.captureAndUploadImage(fieldKey),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF0F9FF),
                  foregroundColor: const Color(0xFF0284C7),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: const Icon(Icons.camera_alt),
              ),
            )
        ],
      ),
    );
  }

  void _handleNext(DriverFormProvider provider) async {
    if (_currentStep == 0) {
      setState(() {
        _currentStep = 1;
      });
    } else if (_currentStep == 1) {
      // Validate appearance step
      final fullBody = provider.mediaUploads['full_body']?.url;
      final shoes = provider.mediaUploads['shoes']?.url;
      if (fullBody == null || shoes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload both appearance photos before continuing.')),
        );
      } else {
        setState(() {
          _currentStep = 2;
        });
      }
    } else if (_currentStep == 2) {
      // Submit form
      final success = await provider.submitForm();
      if (success && mounted) {
        // Form provider will automatically update status, triggering UI success state
      }
    }
  }
}

class _SuccessState extends StatelessWidget {
  final String message;

  const _SuccessState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 72),
              const SizedBox(height: 24),
              const Text(
                'Submission Successful',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 15, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 72),
              const SizedBox(height: 24),
              const Text(
                'Submission Error',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 15, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}