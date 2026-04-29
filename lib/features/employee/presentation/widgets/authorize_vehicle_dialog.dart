import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xloop_invoice/features/employee/domain/entities/employee_entity.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_documents.dart';
import 'package:xloop_invoice/features/vehicle/presentation/providers/vehicle_provider.dart';
import 'package:xloop_invoice/widgets/custom_date_picker.dart';

class AuthorizeVehicleDialog extends StatefulWidget {
  final EmployeeEntity employee;

  const AuthorizeVehicleDialog({super.key, required this.employee});

  @override
  State<AuthorizeVehicleDialog> createState() => _AuthorizeVehicleDialogState();
}

class _AuthorizeVehicleDialogState extends State<AuthorizeVehicleDialog> {
  DateTime? _issuedDate;
  DateTime? _expiryDate;
  String? _selectedVehicleId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _issuedDate = DateTime.now();

    // Fetch vehicles if not already loaded.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vehicleProvider = context.read<VehicleProvider>();
      if (vehicleProvider.vehicles.isEmpty) {
        vehicleProvider.fetchAllVehicles();
      }
    });
  }

  Future<void> _saveTafweed() async {
    if (_expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an expiry date for Tafweed'),
        ),
      );
      return;
    }

    if (_selectedVehicleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a vehicle')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final vehicleProvider = context.read<VehicleProvider>();
      final issuedDate = _issuedDate ?? DateTime.now();

      // Enforce Business Rule: One Driver → One Vehicle
      // Check if the current driver is already authorised on another vehicle.
      final existingVehicles = vehicleProvider.vehicles.where((v) =>
        v.id != _selectedVehicleId &&
        (v.tafweeds?.any((t) => t.driverId == widget.employee.id) ?? false),
      ).toList();

      bool confirmSwap = true;
      if (existingVehicles.isNotEmpty) {
        confirmSwap = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Driver Already Authorized'),
            content: Text(
              'This driver is currently authorized for '
              '${existingVehicles.first.make} ${existingVehicles.first.model} '
              '(${existingVehicles.first.plateNumber}). '
              'Do you want to swap the driver to the new vehicle? '
              'They will be removed from the other vehicle\'s authorization '
              'and that record will be saved to history.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Swap'),
              ),
            ],
          ),
        ) ?? false;
      }

      if (!confirmSwap) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Archive the old tafweed record (move to history instead of deleting).
      for (final otherVehicle in existingVehicles) {
        final recordToArchive = otherVehicle.tafweeds
            ?.where((t) => t.driverId == widget.employee.id)
            .firstOrNull;

        final updatedActiveTafweeds =
            List<TafweedRecord>.from(otherVehicle.tafweeds ?? [])
              ..removeWhere((t) => t.driverId == widget.employee.id);

        // Append the archived record to tafweedHistory.
        final updatedHistory =
            List<TafweedRecord>.from(otherVehicle.tafweedHistory ?? []);
        if (recordToArchive != null) {
          updatedHistory.add(recordToArchive);
        }

        final updatedOtherVehicle = otherVehicle.copyWith(
          tafweeds: updatedActiveTafweeds,
          tafweedHistory: updatedHistory,
        );
        await vehicleProvider.updateVehicle(updatedOtherVehicle);
      }

      // Add / update the driver on the selected vehicle.
      final selectedVehicle = vehicleProvider.vehicles.firstWhere(
        (v) => v.id == _selectedVehicleId,
      );
      List<TafweedRecord> currentTafweeds =
          List.from(selectedVehicle.tafweeds ?? []);

      final index = currentTafweeds.indexWhere(
        (t) => t.driverId == widget.employee.id,
      );
      final existingAttachmentUrl =
          index != -1 ? currentTafweeds[index].attachmentUrl : null;
      final existingNotificationDays =
          index != -1 ? currentTafweeds[index].notificationDays : null;

      final newRecord = TafweedRecord(
        driverId: widget.employee.id,
        issuedDate: issuedDate,
        expiryDate: _expiryDate!,
        attachmentUrl: existingAttachmentUrl,
        notificationDays: existingNotificationDays,
      );

      if (index != -1) {
        currentTafweeds[index] = newRecord;
      } else {
        currentTafweeds.add(newRecord);
      }

      final updatedVehicle = selectedVehicle.copyWith(
        tafweeds: currentTafweeds,
      );

      await vehicleProvider.updateVehicle(updatedVehicle);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle authorized successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to authorize vehicle: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Authorize Vehicle'),
      content: Consumer<VehicleProvider>(
        builder: (context, vehicleProvider, child) {
          if (vehicleProvider.isLoading && vehicleProvider.vehicles.isEmpty) {
            return const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vehicle selector
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Select Vehicle',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: _selectedVehicleId,
                  items: vehicleProvider.vehicles.map((v) {
                    return DropdownMenuItem(
                      value: v.id,
                      child: Text('${v.make} ${v.model} (${v.plateNumber})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedVehicleId = val;
                      if (val != null) {
                        final v = vehicleProvider.vehicles.firstWhere(
                          (v) => v.id == val,
                        );
                        final existing = v.tafweeds
                            ?.where((t) => t.driverId == widget.employee.id)
                            .firstOrNull;
                        if (existing != null) {
                          _issuedDate = existing.issuedDate;
                          _expiryDate = existing.expiryDate;
                        }
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Issued date picker
                CustomDatePicker(
                  label: 'Tafweed Issue Date',
                  date: _issuedDate,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _issuedDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(
                        const Duration(days: 365 * 5),
                      ),
                    );
                    if (picked != null) {
                      setState(() => _issuedDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                // Expiry date picker
                CustomDatePicker(
                  label: 'Tafweed Expiry Date',
                  date: _expiryDate,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _expiryDate ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDate: DateTime.now().add(
                        const Duration(days: 365 * 5),
                      ),
                    );
                    if (picked != null) {
                      setState(() => _expiryDate = picked);
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveTafweed,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Authorize'),
        ),
      ],
    );
  }
}
