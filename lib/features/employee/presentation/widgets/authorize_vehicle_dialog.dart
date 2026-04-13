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
  DateTime? _selectedDate;
  String? _selectedVehicleId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = null;
    _selectedVehicleId = null;
    
    // Fetch vehicles if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vehicleProvider = context.read<VehicleProvider>();
      if (vehicleProvider.vehicles.isEmpty) {
        vehicleProvider.fetchAllVehicles();
      }
    });
  }

  Future<void> _saveTafweed() async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an expiry date for Tafweed')),
      );
      return;
    }

    if (_selectedVehicleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a vehicle')),
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
      final existingVehicles = vehicleProvider.vehicles.where((v) => 
        v.id != _selectedVehicleId && 
        (v.tafweeds?.any((t) => t.driverId == widget.employee.id) ?? false)
      ).toList();

      bool confirmSwap = true;
      if (existingVehicles.isNotEmpty) {
        confirmSwap = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Driver Already Authorized'),
            content: Text('This driver is currently authorized for ${existingVehicles.first.make} ${existingVehicles.first.model} (${existingVehicles.first.plateNumber}). Do you want to swap the driver to the new vehicle? They will be removed from the other vehicle\'s authorization.'),
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
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      // Remove driver from other vehicles if swapping
      for (final otherVehicle in existingVehicles) {
        final updatedOtherTafweeds = List<TafweedRecord>.from(otherVehicle.tafweeds ?? [])..removeWhere((t) => t.driverId == widget.employee.id);
        final updatedOtherVehicle = otherVehicle.copyWith(tafweeds: updatedOtherTafweeds);
        await vehicleProvider.updateVehicle(updatedOtherVehicle);
      }

      // Add driver to new vehicle
      final selectedVehicle = vehicleProvider.vehicles.firstWhere((v) => v.id == _selectedVehicleId);
      List<TafweedRecord> currentTafweeds = List.from(selectedVehicle.tafweeds ?? []);
      
      final index = currentTafweeds.indexWhere((t) => t.driverId == widget.employee.id);
      final attachmentUrl = index != -1 ? currentTafweeds[index].attachmentUrl : null;
      final notificationDays = index != -1 ? currentTafweeds[index].notificationDays : null;

      final updatedRecord = TafweedRecord(
        driverId: widget.employee.id,
        expiryDate: _selectedDate!,
        attachmentUrl: attachmentUrl,
        notificationDays: notificationDays,
      );

      if (index != -1) {
        currentTafweeds[index] = updatedRecord;
      } else {
        currentTafweeds.add(updatedRecord);
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
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Select Vehicle',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedVehicleId,
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
                        final v = vehicleProvider.vehicles.firstWhere((v) => v.id == val);
                        final existing = v.tafweeds?.where((t) => t.driverId == widget.employee.id).firstOrNull;
                        if (existing != null) {
                          _selectedDate = existing.expiryDate;
                        } else {
                          // Try to get setting default if possible or keep null
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
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
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
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
              : const Text('Authorize'),
        ),
      ],
    );
  }
}
