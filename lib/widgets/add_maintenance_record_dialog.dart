import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../features/vehicle/domain/entities/vehicle_entity.dart';
import '../features/vehicle/domain/entities/vehicle_documents.dart';
import '../features/vehicle/presentation/providers/vehicle_provider.dart';

class _MaintenanceEntry {
  String? maintenanceTypeId;
  final TextEditingController serviceKmController = TextEditingController();
  final TextEditingController costController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  void dispose() {
    serviceKmController.dispose();
    costController.dispose();
    notesController.dispose();
  }
}

class AddMaintenanceRecordDialog extends StatefulWidget {
  final VehicleEntity vehicle;

  const AddMaintenanceRecordDialog({super.key, required this.vehicle});

  @override
  State<AddMaintenanceRecordDialog> createState() =>
      _AddMaintenanceRecordDialogState();
}

class _AddMaintenanceRecordDialogState
    extends State<AddMaintenanceRecordDialog> {
  final _formKey = GlobalKey<FormState>();
  final List<_MaintenanceEntry> _entries = [_MaintenanceEntry()];
  bool _isSaving = false;

  @override
  void dispose() {
    for (var entry in _entries) {
      entry.dispose();
    }
    super.dispose();
  }

  void _addEntry() {
    setState(() {
      _entries.add(_MaintenanceEntry());
    });
  }

  void _removeEntry(int index) {
    setState(() {
      _entries[index].dispose();
      _entries.removeAt(index);
    });
  }

  Future<void> _saveRecords() async {
    if (!_formKey.currentState!.validate()) return;

    // Check if any types are null
    if (_entries.any((entry) => entry.maintenanceTypeId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a maintenance type for all entries.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final provider = context.read<VehicleProvider>();

      final recordsToAdd = _entries.map((entry) {
        // Find the maintenance type name based on ID
        final type = provider.maintenanceTypes.firstWhere(
          (t) => t.id == entry.maintenanceTypeId,
        );

        return (
          typeId: entry.maintenanceTypeId!,
          record: MaintenanceRecord(
            date: DateTime.now(),
            mileage: int.tryParse(entry.serviceKmController.text) ?? 0,
            cost: double.tryParse(entry.costController.text),
            serviceProvider: '',
            notes: entry.notesController.text,
            serviceType: type.name,
          ),
        );
      }).toList();

      // Append to flat history list
      final List<MaintenanceRecord> updatedHistory = List.from(
        widget.vehicle.maintenanceHistory ?? [],
      );
      for (final e in recordsToAdd) {
        updatedHistory.add(e.record);
      }

      // Also update the typed VehicleMaintenance fields so the alert checker
      // (GetVehicleMaintenanceAlertsUseCase) can find the latest service record.
      final existing = widget.vehicle.maintenance ?? const VehicleMaintenance();
      VehicleMaintenance updatedMaintenance = existing;
      for (final e in recordsToAdd) {
        updatedMaintenance = _applyTypedRecord(updatedMaintenance, e.typeId, e.record);
      }

      final updatedVehicle = widget.vehicle.copyWith(
        maintenanceHistory: updatedHistory,
        maintenance: updatedMaintenance,
      );

      await provider.updateVehicle(updatedVehicle);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maintenance record(s) added successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save records: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// Maps a [typeId] to the correct named field on [VehicleMaintenance].
  VehicleMaintenance _applyTypedRecord(
    VehicleMaintenance m,
    String typeId,
    MaintenanceRecord record,
  ) {
    switch (typeId) {
      case 'engine_oil':
        return VehicleMaintenance(
          engineOil: record, gearOil: m.gearOil, housingOil: m.housingOil,
          tyreChange: m.tyreChange, batteryChange: m.batteryChange,
          brakePads: m.brakePads, airFilter: m.airFilter, acService: m.acService,
          wheelAlignment: m.wheelAlignment, sparkPlugs: m.sparkPlugs,
          coolantFlush: m.coolantFlush, wiperBlades: m.wiperBlades,
          timingBelt: m.timingBelt, transmissionFluid: m.transmissionFluid,
          brakeFluid: m.brakeFluid, fuelFilter: m.fuelFilter,
        );
      case 'gear_oil':
        return VehicleMaintenance(
          engineOil: m.engineOil, gearOil: record, housingOil: m.housingOil,
          tyreChange: m.tyreChange, batteryChange: m.batteryChange,
          brakePads: m.brakePads, airFilter: m.airFilter, acService: m.acService,
          wheelAlignment: m.wheelAlignment, sparkPlugs: m.sparkPlugs,
          coolantFlush: m.coolantFlush, wiperBlades: m.wiperBlades,
          timingBelt: m.timingBelt, transmissionFluid: m.transmissionFluid,
          brakeFluid: m.brakeFluid, fuelFilter: m.fuelFilter,
        );
      case 'housing_oil':
        return VehicleMaintenance(
          engineOil: m.engineOil, gearOil: m.gearOil, housingOil: record,
          tyreChange: m.tyreChange, batteryChange: m.batteryChange,
          brakePads: m.brakePads, airFilter: m.airFilter, acService: m.acService,
          wheelAlignment: m.wheelAlignment, sparkPlugs: m.sparkPlugs,
          coolantFlush: m.coolantFlush, wiperBlades: m.wiperBlades,
          timingBelt: m.timingBelt, transmissionFluid: m.transmissionFluid,
          brakeFluid: m.brakeFluid, fuelFilter: m.fuelFilter,
        );
      case 'tyre_change':
        return VehicleMaintenance(
          engineOil: m.engineOil, gearOil: m.gearOil, housingOil: m.housingOil,
          tyreChange: record, batteryChange: m.batteryChange,
          brakePads: m.brakePads, airFilter: m.airFilter, acService: m.acService,
          wheelAlignment: m.wheelAlignment, sparkPlugs: m.sparkPlugs,
          coolantFlush: m.coolantFlush, wiperBlades: m.wiperBlades,
          timingBelt: m.timingBelt, transmissionFluid: m.transmissionFluid,
          brakeFluid: m.brakeFluid, fuelFilter: m.fuelFilter,
        );
      case 'battery_change':
        return VehicleMaintenance(
          engineOil: m.engineOil, gearOil: m.gearOil, housingOil: m.housingOil,
          tyreChange: m.tyreChange, batteryChange: record,
          brakePads: m.brakePads, airFilter: m.airFilter, acService: m.acService,
          wheelAlignment: m.wheelAlignment, sparkPlugs: m.sparkPlugs,
          coolantFlush: m.coolantFlush, wiperBlades: m.wiperBlades,
          timingBelt: m.timingBelt, transmissionFluid: m.transmissionFluid,
          brakeFluid: m.brakeFluid, fuelFilter: m.fuelFilter,
        );
      case 'brake_pads':
        return VehicleMaintenance(
          engineOil: m.engineOil, gearOil: m.gearOil, housingOil: m.housingOil,
          tyreChange: m.tyreChange, batteryChange: m.batteryChange,
          brakePads: record, airFilter: m.airFilter, acService: m.acService,
          wheelAlignment: m.wheelAlignment, sparkPlugs: m.sparkPlugs,
          coolantFlush: m.coolantFlush, wiperBlades: m.wiperBlades,
          timingBelt: m.timingBelt, transmissionFluid: m.transmissionFluid,
          brakeFluid: m.brakeFluid, fuelFilter: m.fuelFilter,
        );
      case 'air_filter':
        return VehicleMaintenance(
          engineOil: m.engineOil, gearOil: m.gearOil, housingOil: m.housingOil,
          tyreChange: m.tyreChange, batteryChange: m.batteryChange,
          brakePads: m.brakePads, airFilter: record, acService: m.acService,
          wheelAlignment: m.wheelAlignment, sparkPlugs: m.sparkPlugs,
          coolantFlush: m.coolantFlush, wiperBlades: m.wiperBlades,
          timingBelt: m.timingBelt, transmissionFluid: m.transmissionFluid,
          brakeFluid: m.brakeFluid, fuelFilter: m.fuelFilter,
        );
      case 'ac_service':
        return VehicleMaintenance(
          engineOil: m.engineOil, gearOil: m.gearOil, housingOil: m.housingOil,
          tyreChange: m.tyreChange, batteryChange: m.batteryChange,
          brakePads: m.brakePads, airFilter: m.airFilter, acService: record,
          wheelAlignment: m.wheelAlignment, sparkPlugs: m.sparkPlugs,
          coolantFlush: m.coolantFlush, wiperBlades: m.wiperBlades,
          timingBelt: m.timingBelt, transmissionFluid: m.transmissionFluid,
          brakeFluid: m.brakeFluid, fuelFilter: m.fuelFilter,
        );
      case 'wheel_alignment':
        return VehicleMaintenance(
          engineOil: m.engineOil, gearOil: m.gearOil, housingOil: m.housingOil,
          tyreChange: m.tyreChange, batteryChange: m.batteryChange,
          brakePads: m.brakePads, airFilter: m.airFilter, acService: m.acService,
          wheelAlignment: record, sparkPlugs: m.sparkPlugs,
          coolantFlush: m.coolantFlush, wiperBlades: m.wiperBlades,
          timingBelt: m.timingBelt, transmissionFluid: m.transmissionFluid,
          brakeFluid: m.brakeFluid, fuelFilter: m.fuelFilter,
        );
      case 'spark_plugs':
        return VehicleMaintenance(
          engineOil: m.engineOil, gearOil: m.gearOil, housingOil: m.housingOil,
          tyreChange: m.tyreChange, batteryChange: m.batteryChange,
          brakePads: m.brakePads, airFilter: m.airFilter, acService: m.acService,
          wheelAlignment: m.wheelAlignment, sparkPlugs: record,
          coolantFlush: m.coolantFlush, wiperBlades: m.wiperBlades,
          timingBelt: m.timingBelt, transmissionFluid: m.transmissionFluid,
          brakeFluid: m.brakeFluid, fuelFilter: m.fuelFilter,
        );
      case 'coolant_flush':
        return VehicleMaintenance(
          engineOil: m.engineOil, gearOil: m.gearOil, housingOil: m.housingOil,
          tyreChange: m.tyreChange, batteryChange: m.batteryChange,
          brakePads: m.brakePads, airFilter: m.airFilter, acService: m.acService,
          wheelAlignment: m.wheelAlignment, sparkPlugs: m.sparkPlugs,
          coolantFlush: record, wiperBlades: m.wiperBlades,
          timingBelt: m.timingBelt, transmissionFluid: m.transmissionFluid,
          brakeFluid: m.brakeFluid, fuelFilter: m.fuelFilter,
        );
      case 'wiper_blades':
        return VehicleMaintenance(
          engineOil: m.engineOil, gearOil: m.gearOil, housingOil: m.housingOil,
          tyreChange: m.tyreChange, batteryChange: m.batteryChange,
          brakePads: m.brakePads, airFilter: m.airFilter, acService: m.acService,
          wheelAlignment: m.wheelAlignment, sparkPlugs: m.sparkPlugs,
          coolantFlush: m.coolantFlush, wiperBlades: record,
          timingBelt: m.timingBelt, transmissionFluid: m.transmissionFluid,
          brakeFluid: m.brakeFluid, fuelFilter: m.fuelFilter,
        );
      case 'timing_belt':
        return VehicleMaintenance(
          engineOil: m.engineOil, gearOil: m.gearOil, housingOil: m.housingOil,
          tyreChange: m.tyreChange, batteryChange: m.batteryChange,
          brakePads: m.brakePads, airFilter: m.airFilter, acService: m.acService,
          wheelAlignment: m.wheelAlignment, sparkPlugs: m.sparkPlugs,
          coolantFlush: m.coolantFlush, wiperBlades: m.wiperBlades,
          timingBelt: record, transmissionFluid: m.transmissionFluid,
          brakeFluid: m.brakeFluid, fuelFilter: m.fuelFilter,
        );
      case 'transmission_fluid':
        return VehicleMaintenance(
          engineOil: m.engineOil, gearOil: m.gearOil, housingOil: m.housingOil,
          tyreChange: m.tyreChange, batteryChange: m.batteryChange,
          brakePads: m.brakePads, airFilter: m.airFilter, acService: m.acService,
          wheelAlignment: m.wheelAlignment, sparkPlugs: m.sparkPlugs,
          coolantFlush: m.coolantFlush, wiperBlades: m.wiperBlades,
          timingBelt: m.timingBelt, transmissionFluid: record,
          brakeFluid: m.brakeFluid, fuelFilter: m.fuelFilter,
        );
      case 'brake_fluid':
        return VehicleMaintenance(
          engineOil: m.engineOil, gearOil: m.gearOil, housingOil: m.housingOil,
          tyreChange: m.tyreChange, batteryChange: m.batteryChange,
          brakePads: m.brakePads, airFilter: m.airFilter, acService: m.acService,
          wheelAlignment: m.wheelAlignment, sparkPlugs: m.sparkPlugs,
          coolantFlush: m.coolantFlush, wiperBlades: m.wiperBlades,
          timingBelt: m.timingBelt, transmissionFluid: m.transmissionFluid,
          brakeFluid: record, fuelFilter: m.fuelFilter,
        );
      case 'fuel_filter':
        return VehicleMaintenance(
          engineOil: m.engineOil, gearOil: m.gearOil, housingOil: m.housingOil,
          tyreChange: m.tyreChange, batteryChange: m.batteryChange,
          brakePads: m.brakePads, airFilter: m.airFilter, acService: m.acService,
          wheelAlignment: m.wheelAlignment, sparkPlugs: m.sparkPlugs,
          coolantFlush: m.coolantFlush, wiperBlades: m.wiperBlades,
          timingBelt: m.timingBelt, transmissionFluid: m.transmissionFluid,
          brakeFluid: m.brakeFluid, fuelFilter: record,
        );
      default:
        return m; // Unknown type — leave unchanged
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VehicleProvider>();
    final types = provider.maintenanceTypes;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        width: 800.w, // Match screen size constraint or constraints
        padding: EdgeInsets.all(24.w),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Maintenance Record',
                style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8.h),
              Text(
                '${widget.vehicle.make} ${widget.vehicle.model} - ${widget.vehicle.plateNumber}',
                style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
              ),
              SizedBox(height: 24.h),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _entries.length,
                  separatorBuilder: (context, index) => Divider(height: 32.h),
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            // ignore: deprecated_member_use
                            value: entry.maintenanceTypeId,
                            decoration: InputDecoration(
                              labelText: 'Maintenance Type',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                            ),
                            items: types.map((t) {
                              return DropdownMenuItem(
                                value: t.id,
                                child: Text(t.name),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                entry.maintenanceTypeId = value;
                              });
                            },
                            validator: (v) => v == null ? 'Required' : null,
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: TextFormField(
                            controller: entry.serviceKmController,
                            decoration: InputDecoration(
                              labelText: 'Current Odometer',
                              suffixText: 'km',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              if (int.tryParse(v) == null) return 'Invalid';
                              return null;
                            },
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: TextFormField(
                            controller: entry.costController,
                            decoration: InputDecoration(
                              labelText: 'Cost (Optional)',
                              prefixText: '\$ ',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: TextFormField(
                            controller: entry.notesController,
                            decoration: InputDecoration(
                              labelText: 'Notes',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                            ),
                          ),
                        ),
                        if (_entries.length > 1)
                          Padding(
                            padding: EdgeInsets.only(left: 8.w, top: 4.h),
                            child: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () => _removeEntry(index),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              SizedBox(height: 16.h),
              TextButton.icon(
                onPressed: _addEntry,
                icon: const Icon(Icons.add),
                label: const Text('Add Another Entry'),
              ),
              SizedBox(height: 24.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  SizedBox(width: 16.w),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveRecords,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24.w,
                        vertical: 12.h,
                      ),
                    ),
                    child: _isSaving
                        ? SizedBox(
                            width: 20.w,
                            height: 20.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Save Records'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
