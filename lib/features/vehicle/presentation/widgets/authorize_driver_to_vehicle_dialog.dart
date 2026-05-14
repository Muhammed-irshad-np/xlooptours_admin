import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xloop_invoice/features/employee/presentation/providers/employee_provider.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_documents.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_entity.dart';
import 'package:xloop_invoice/features/vehicle/presentation/providers/vehicle_provider.dart';
import 'package:xloop_invoice/widgets/custom_date_picker.dart';

class AuthorizeDriverToVehicleDialog extends StatefulWidget {
  final VehicleEntity vehicle;

  const AuthorizeDriverToVehicleDialog({super.key, required this.vehicle});

  @override
  State<AuthorizeDriverToVehicleDialog> createState() =>
      _AuthorizeDriverToVehicleDialogState();
}

class _AuthorizeDriverToVehicleDialogState
    extends State<AuthorizeDriverToVehicleDialog> {
  DateTime? _issuedDate;
  DateTime? _expiryDate;
  String? _selectedEmployeeId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _issuedDate = DateTime.now();

    // Fetch employees if not already loaded.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final employeeProvider = context.read<EmployeeProvider>();
      if (employeeProvider.employees.isEmpty) {
        employeeProvider.fetchAllEmployees();
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

    if (_selectedEmployeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an employee')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final vehicleProvider = context.read<VehicleProvider>();
      final issuedDate = _issuedDate ?? DateTime.now();

      // Ensure no active authorizations are currently on the vehicle.
      // (This should be handled by the UI since we hide the button, but check anyway)
      if (widget.vehicle.tafweeds != null &&
          widget.vehicle.tafweeds!.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please cancel the active authorization first.'),
            ),
          );
          Navigator.pop(context);
        }
        return;
      }

      // Check if the selected employee is already authorized on another vehicle.
      final existingVehicles = vehicleProvider.vehicles
          .where(
            (v) =>
                v.id != widget.vehicle.id &&
                (v.tafweeds?.any((t) => t.driverId == _selectedEmployeeId) ??
                    false),
          )
          .toList();

      bool confirmSwap = true;
      if (existingVehicles.isNotEmpty) {
        confirmSwap =
            await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Driver Already Authorized'),
                content: Text(
                  'This driver is currently authorized for '
                  '${existingVehicles.first.make} ${existingVehicles.first.model} '
                  '(${existingVehicles.first.plateNumber}). '
                  'Do you want to swap the driver to this vehicle? '
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
            ) ??
            false;
      }

      if (!confirmSwap) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Archive the old tafweed record from other vehicles
      for (final otherVehicle in existingVehicles) {
        final recordToArchive = otherVehicle.tafweeds
            ?.where((t) => t.driverId == _selectedEmployeeId)
            .firstOrNull;

        final updatedActiveTafweeds = List<TafweedRecord>.from(
          otherVehicle.tafweeds ?? [],
        )..removeWhere((t) => t.driverId == _selectedEmployeeId);

        final updatedHistory = List<TafweedRecord>.from(
          otherVehicle.tafweedHistory ?? [],
        );
        if (recordToArchive != null) {
          // Set expiry to now as it's been swapped
          updatedHistory.add(
            recordToArchive.copyWith(expiryDate: DateTime.now()),
          );
        }

        final updatedOtherVehicle = otherVehicle.copyWith(
          tafweeds: updatedActiveTafweeds,
          tafweedHistory: updatedHistory,
        );
        await vehicleProvider.updateVehicle(updatedOtherVehicle);
      }

      // Create new tafweed record for this vehicle
      final newRecord = TafweedRecord(
        driverId: _selectedEmployeeId!,
        issuedDate: issuedDate,
        expiryDate: _expiryDate!,
      );

      final updatedVehicle = widget.vehicle.copyWith(
        tafweeds: [newRecord], // We ensured it's empty above
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
      title: const Text('Authorize Driver'),
      content: Consumer<EmployeeProvider>(
        builder: (context, employeeProvider, child) {
          if (employeeProvider.isLoading &&
              employeeProvider.employees.isEmpty) {
            return const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final activeEmployees = employeeProvider.employees
              .where((e) => e.isActive)
              .toList();

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Employee selector
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Select Driver',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: _selectedEmployeeId,
                  items: activeEmployees.map((e) {
                    return DropdownMenuItem(
                      value: e.id,
                      child: Text(e.fullName),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedEmployeeId = val;
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
