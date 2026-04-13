import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xloop_invoice/features/employee/presentation/providers/employee_provider.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_entity.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_documents.dart';
import 'package:xloop_invoice/features/vehicle/presentation/providers/vehicle_provider.dart';
import 'package:xloop_invoice/widgets/custom_date_picker.dart';

class UpdateTafweedDialog extends StatefulWidget {
  final VehicleEntity vehicle;

  const UpdateTafweedDialog({super.key, required this.vehicle});

  @override
  State<UpdateTafweedDialog> createState() => _UpdateTafweedDialogState();
}

class _UpdateTafweedDialogState extends State<UpdateTafweedDialog> {
  DateTime? _selectedDate;
  String? _selectedDriverId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = null;
    _selectedDriverId = null;

    // Fetch employees if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final empProvider = context.read<EmployeeProvider>();
      if (empProvider.employees.isEmpty) {
        empProvider.fetchAllEmployees();
      }
    });
  }

  Future<void> _saveTafweed() async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an expiry date for Tafweed'),
        ),
      );
      return;
    }

    if (_selectedDriverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an authorized driver')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final vehicleProvider = context.read<VehicleProvider>();

      // Enforce Business Rule: One Driver -> One Vehicle
      // Check if current driver is already assigned to another vehicle
      final existingVehicles = vehicleProvider.vehicles
          .where(
            (v) =>
                v.id != widget.vehicle.id &&
                (v.tafweeds?.any((t) => t.driverId == _selectedDriverId) ??
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
                  'This driver is currently authorized for ${existingVehicles.first.make} ${existingVehicles.first.model} (${existingVehicles.first.plateNumber}). Do you want to swap the driver to this vehicle? They will be removed from the other vehicle\'s authorization.',
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
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      // Remove driver from other vehicles if swapping
      for (final otherVehicle in existingVehicles) {
        final updatedOtherTafweeds = List<TafweedRecord>.from(
          otherVehicle.tafweeds ?? [],
        )..removeWhere((t) => t.driverId == _selectedDriverId);
        final updatedOtherVehicle = otherVehicle.copyWith(
          tafweeds: updatedOtherTafweeds,
        );
        await vehicleProvider.updateVehicle(updatedOtherVehicle);
      }

      List<TafweedRecord> currentTafweeds = List.from(
        widget.vehicle.tafweeds ?? [],
      );

      final index = currentTafweeds.indexWhere(
        (t) => t.driverId == _selectedDriverId,
      );
      final attachmentUrl = index != -1
          ? currentTafweeds[index].attachmentUrl
          : null;
      final notificationDays = index != -1
          ? currentTafweeds[index].notificationDays
          : null;

      final updatedRecord = TafweedRecord(
        driverId: _selectedDriverId!,
        expiryDate: _selectedDate!,
        attachmentUrl: attachmentUrl,
        notificationDays: notificationDays,
      );

      if (index != -1) {
        currentTafweeds[index] = updatedRecord;
      } else {
        currentTafweeds.add(updatedRecord);
      }

      final updatedVehicle = widget.vehicle.copyWith(tafweeds: currentTafweeds);

      await vehicleProvider.updateVehicle(updatedVehicle);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tafweed updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update Tafweed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update Tafweed Authorization'),
      content: Consumer<EmployeeProvider>(
        builder: (context, empProvider, child) {
          if (empProvider.isLoading && empProvider.employees.isEmpty) {
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
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Authorized Driver',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedDriverId,
                  items: empProvider.employees.map((e) {
                    return DropdownMenuItem(
                      value: e.id,
                      child: Text(e.fullName),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedDriverId = val;
                      if (val != null) {
                        final existing = widget.vehicle.tafweeds
                            ?.where((t) => t.driverId == val)
                            .firstOrNull;
                        if (existing != null) {
                          _selectedDate = existing.expiryDate;
                        }
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                CustomDatePicker(
                  label: 'Tafweed Expiry Date',
                  date: _selectedDate,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDate: DateTime.now().add(
                        const Duration(days: 365 * 5),
                      ),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDate = picked;
                      });
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
              : const Text('Save'),
        ),
      ],
    );
  }
}
