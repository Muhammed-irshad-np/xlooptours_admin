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
    _selectedDate = widget.vehicle.tafweed?.expiryDate;
    _selectedDriverId = widget.vehicle.currentTafweedDriverId;
    
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
        const SnackBar(content: Text('Please select an expiry date for Tafweed')),
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
      
      final updatedTafweed = widget.vehicle.tafweed != null 
          ? VehicleDocument(
              expiryDate: _selectedDate!,
              attachmentUrl: widget.vehicle.tafweed!.attachmentUrl,
              notificationDays: widget.vehicle.tafweed!.notificationDays,
            )
          : VehicleDocument(expiryDate: _selectedDate!);

      final updatedVehicle = widget.vehicle.copyWith(
        tafweed: updatedTafweed,
        currentTafweedDriverId: _selectedDriverId,
      );

      await vehicleProvider.updateVehicle(updatedVehicle);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tafweed updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update Tafweed: $e')),
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
              : const Text('Save'),
        ),
      ],
    );
  }
}
