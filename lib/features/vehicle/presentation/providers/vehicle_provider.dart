import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/entities/vehicle_entity.dart';
import '../../domain/entities/vehicle_make_entity.dart';
import '../../domain/entities/maintenance_type_entity.dart';
import '../../domain/entities/vehicle_documents.dart';
import '../../domain/usecases/assign_driver_to_vehicle_usecase.dart';
import '../../domain/usecases/delete_vehicle_make_usecase.dart';
import '../../domain/usecases/delete_vehicle_usecase.dart';
import '../../domain/usecases/get_all_vehicle_makes_usecase.dart';
import '../../domain/usecases/get_all_vehicles_usecase.dart';
import '../../domain/usecases/insert_vehicle_make_usecase.dart';
import '../../domain/usecases/insert_vehicle_usecase.dart';
import '../../domain/usecases/update_vehicle_make_usecase.dart';
import '../../domain/usecases/update_vehicle_usecase.dart';
import '../../domain/usecases/upload_vehicle_document_usecase.dart';
import '../../domain/usecases/upload_vehicle_image_usecase.dart';
import '../../domain/usecases/get_all_maintenance_types_usecase.dart';
import '../../domain/usecases/insert_maintenance_type_usecase.dart';
import '../../domain/usecases/update_maintenance_type_usecase.dart';
import '../../domain/usecases/delete_maintenance_type_usecase.dart';

class VehicleProvider extends ChangeNotifier {
  final GetAllVehiclesUseCase getAllVehiclesUseCase;
  final InsertVehicleUseCase insertVehicleUseCase;
  final UpdateVehicleUseCase updateVehicleUseCase;
  final DeleteVehicleUseCase deleteVehicleUseCase;
  final AssignDriverToVehicleUseCase assignDriverToVehicleUseCase;
  final UploadVehicleImageUseCase uploadVehicleImageUseCase;
  final UploadVehicleDocumentUseCase uploadVehicleDocumentUseCase;

  final GetAllVehicleMakesUseCase getAllVehicleMakesUseCase;
  final InsertVehicleMakeUseCase insertVehicleMakeUseCase;
  final UpdateVehicleMakeUseCase updateVehicleMakeUseCase;
  final DeleteVehicleMakeUseCase deleteVehicleMakeUseCase;

  final GetAllMaintenanceTypesUseCase getAllMaintenanceTypesUseCase;
  final InsertMaintenanceTypeUseCase insertMaintenanceTypeUseCase;
  final UpdateMaintenanceTypeUseCase updateMaintenanceTypeUseCase;
  final DeleteMaintenanceTypeUseCase deleteMaintenanceTypeUseCase;

  List<VehicleEntity> _vehicles = [];
  List<VehicleMakeEntity> _vehicleMakes = [];
  List<MaintenanceTypeEntity> _maintenanceTypes = [];
  bool _isLoading = false;
  String? _errorMessage;

  VehicleProvider({
    required this.getAllVehiclesUseCase,
    required this.insertVehicleUseCase,
    required this.updateVehicleUseCase,
    required this.deleteVehicleUseCase,
    required this.assignDriverToVehicleUseCase,
    required this.uploadVehicleImageUseCase,
    required this.uploadVehicleDocumentUseCase,
    required this.getAllVehicleMakesUseCase,
    required this.insertVehicleMakeUseCase,
    required this.updateVehicleMakeUseCase,
    required this.deleteVehicleMakeUseCase,
    required this.getAllMaintenanceTypesUseCase,
    required this.insertMaintenanceTypeUseCase,
    required this.updateMaintenanceTypeUseCase,
    required this.deleteMaintenanceTypeUseCase,
  });

  List<VehicleEntity> get vehicles => _vehicles;
  List<VehicleMakeEntity> get vehicleMakes => _vehicleMakes;
  List<MaintenanceTypeEntity> get maintenanceTypes => _maintenanceTypes;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ======================
  // Vehicle Methods
  // ======================

  Future<void> fetchAllVehicles() async {
    _setLoading(true);
    try {
      _vehicles = await getAllVehiclesUseCase();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to fetch vehicles: \$e';
      debugPrint(_errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addVehicle(VehicleEntity vehicle) async {
    _setLoading(true);
    try {
      await insertVehicleUseCase(vehicle);
      await fetchAllVehicles();
    } catch (e) {
      _errorMessage = 'Failed to add vehicle: \$e';
      debugPrint(_errorMessage);
      _setLoading(false);
      rethrow;
    }
  }

  Future<void> updateVehicle(VehicleEntity vehicle) async {
    _setLoading(true);
    try {
      await updateVehicleUseCase(vehicle);
      await fetchAllVehicles();
    } catch (e) {
      _errorMessage = 'Failed to update vehicle: \$e';
      debugPrint(_errorMessage);
      _setLoading(false);
      rethrow;
    }
  }

  Future<void> updateVehicleOdometer(String vehicleId, int newMileage) async {
    _setLoading(true);
    try {
      final vehicleIndex = _vehicles.indexWhere((v) => v.id == vehicleId);
      if (vehicleIndex != -1) {
        final updatedVehicle = _vehicles[vehicleIndex].copyWith(
          currentOdometer: newMileage,
          lastOdometerUpdateDate: DateTime.now(),
        );
        await updateVehicleUseCase(updatedVehicle);
        await fetchAllVehicles();
      }
    } catch (e) {
      _errorMessage = 'Failed to update odometer: \$e';
      debugPrint(_errorMessage);
      _setLoading(false);
      rethrow;
    }
  }

  Future<void> deleteVehicle(String id) async {
    _setLoading(true);
    try {
      await deleteVehicleUseCase(id);
      await fetchAllVehicles();
    } catch (e) {
      _errorMessage = 'Failed to delete vehicle: $e';
      debugPrint(_errorMessage);
      _setLoading(false);
      rethrow;
    }
  }

  Future<void> deleteMaintenanceRecord(
    VehicleEntity vehicle,
    MaintenanceRecord record,
  ) async {
    _setLoading(true);
    try {
      final List<MaintenanceRecord> updatedHistory = List.from(
        vehicle.maintenanceHistory ?? [],
      );
      updatedHistory.remove(record);

      final updatedVehicle = vehicle.copyWith(
        maintenanceHistory: updatedHistory,
      );

      await updateVehicleUseCase(updatedVehicle);
      await fetchAllVehicles();
    } catch (e) {
      _errorMessage = 'Failed to delete maintenance record: $e';
      debugPrint(_errorMessage);
      _setLoading(false);
      rethrow;
    }
  }

  Future<void> assignDriver(String? vehicleId, String driverId) async {
    _setLoading(true);
    try {
      await assignDriverToVehicleUseCase(vehicleId, driverId);
      await fetchAllVehicles();
    } catch (e) {
      _errorMessage = 'Failed to assign driver: \$e';
      debugPrint(_errorMessage);
      _setLoading(false);
      rethrow;
    }
  }

  Future<String> uploadVehicleImage(XFile image, String vehicleId) async {
    _setLoading(true);
    try {
      final url = await uploadVehicleImageUseCase(image, vehicleId);
      _setLoading(false);
      return url;
    } catch (e) {
      _errorMessage = 'Failed to upload image: \$e';
      debugPrint(_errorMessage);
      _setLoading(false);
      rethrow;
    }
  }

  Future<String> uploadVehicleDocument(
    XFile file,
    String vehicleId,
    String docType,
  ) async {
    _setLoading(true);
    try {
      final url = await uploadVehicleDocumentUseCase(file, vehicleId, docType);
      _setLoading(false);
      return url;
    } catch (e) {
      _errorMessage = 'Failed to upload document: \$e';
      debugPrint(_errorMessage);
      _setLoading(false);
      rethrow;
    }
  }

  // ======================
  // Vehicle Make Methods
  // ======================

  Future<void> fetchAllVehicleMakes() async {
    _setLoading(true);
    try {
      _vehicleMakes = await getAllVehicleMakesUseCase();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to fetch vehicle makes: \$e';
      debugPrint(_errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addVehicleMake(VehicleMakeEntity make) async {
    _setLoading(true);
    try {
      await insertVehicleMakeUseCase(make);
      await fetchAllVehicleMakes();
    } catch (e) {
      _errorMessage = 'Failed to add vehicle make: \$e';
      debugPrint(_errorMessage);
      _setLoading(false);
      rethrow;
    }
  }

  Future<void> updateVehicleMake(VehicleMakeEntity make) async {
    _setLoading(true);
    try {
      await updateVehicleMakeUseCase(make);
      await fetchAllVehicleMakes();
    } catch (e) {
      _errorMessage = 'Failed to update vehicle make: \$e';
      debugPrint(_errorMessage);
      _setLoading(false);
      rethrow;
    }
  }

  Future<void> deleteVehicleMake(String id) async {
    _setLoading(true);
    try {
      await deleteVehicleMakeUseCase(id);
      await fetchAllVehicleMakes();
    } catch (e) {
      _errorMessage = 'Failed to delete vehicle make: \$e';
      debugPrint(_errorMessage);
      _setLoading(false);
      rethrow;
    }
  }

  // ======================
  // Maintenance Type Methods
  // ======================

  Future<void> fetchAllMaintenanceTypes() async {
    _setLoading(true);
    try {
      _maintenanceTypes = await getAllMaintenanceTypesUseCase();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to fetch maintenance types: \$e';
      debugPrint(_errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addMaintenanceType(MaintenanceTypeEntity type) async {
    _setLoading(true);
    try {
      await insertMaintenanceTypeUseCase(type);
      await fetchAllMaintenanceTypes();
    } catch (e) {
      _errorMessage = 'Failed to add maintenance type: \$e';
      debugPrint(_errorMessage);
      _setLoading(false);
      rethrow;
    }
  }

  Future<void> updateMaintenanceType(MaintenanceTypeEntity type) async {
    _setLoading(true);
    try {
      await updateMaintenanceTypeUseCase(type);
      await fetchAllMaintenanceTypes();
    } catch (e) {
      _errorMessage = 'Failed to update maintenance type: \$e';
      debugPrint(_errorMessage);
      _setLoading(false);
      rethrow;
    }
  }

  Future<void> deleteMaintenanceType(String id) async {
    _setLoading(true);
    try {
      await deleteMaintenanceTypeUseCase(id);
      await fetchAllMaintenanceTypes();
    } catch (e) {
      _errorMessage = 'Failed to delete maintenance type: \$e';
      debugPrint(_errorMessage);
      _setLoading(false);
      rethrow;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
