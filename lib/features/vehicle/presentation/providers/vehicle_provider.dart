import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/entities/vehicle_entity.dart';
import '../../domain/entities/vehicle_make_entity.dart';
import '../../domain/usecases/assign_driver_to_vehicle_usecase.dart';
import '../../domain/usecases/delete_vehicle_make_usecase.dart';
import '../../domain/usecases/delete_vehicle_usecase.dart';
import '../../domain/usecases/get_all_vehicle_makes_usecase.dart';
import '../../domain/usecases/get_all_vehicles_usecase.dart';
import '../../domain/usecases/insert_vehicle_make_usecase.dart';
import '../../domain/usecases/insert_vehicle_usecase.dart';
import '../../domain/usecases/update_vehicle_make_usecase.dart';
import '../../domain/usecases/update_vehicle_usecase.dart';
import '../../domain/usecases/upload_vehicle_image_usecase.dart';

class VehicleProvider extends ChangeNotifier {
  final GetAllVehiclesUseCase getAllVehiclesUseCase;
  final InsertVehicleUseCase insertVehicleUseCase;
  final UpdateVehicleUseCase updateVehicleUseCase;
  final DeleteVehicleUseCase deleteVehicleUseCase;
  final AssignDriverToVehicleUseCase assignDriverToVehicleUseCase;
  final UploadVehicleImageUseCase uploadVehicleImageUseCase;

  final GetAllVehicleMakesUseCase getAllVehicleMakesUseCase;
  final InsertVehicleMakeUseCase insertVehicleMakeUseCase;
  final UpdateVehicleMakeUseCase updateVehicleMakeUseCase;
  final DeleteVehicleMakeUseCase deleteVehicleMakeUseCase;

  List<VehicleEntity> _vehicles = [];
  List<VehicleMakeEntity> _vehicleMakes = [];
  bool _isLoading = false;
  String? _errorMessage;

  VehicleProvider({
    required this.getAllVehiclesUseCase,
    required this.insertVehicleUseCase,
    required this.updateVehicleUseCase,
    required this.deleteVehicleUseCase,
    required this.assignDriverToVehicleUseCase,
    required this.uploadVehicleImageUseCase,
    required this.getAllVehicleMakesUseCase,
    required this.insertVehicleMakeUseCase,
    required this.updateVehicleMakeUseCase,
    required this.deleteVehicleMakeUseCase,
  });

  List<VehicleEntity> get vehicles => _vehicles;
  List<VehicleMakeEntity> get vehicleMakes => _vehicleMakes;
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

  Future<void> deleteVehicle(String id) async {
    _setLoading(true);
    try {
      await deleteVehicleUseCase(id);
      await fetchAllVehicles();
    } catch (e) {
      _errorMessage = 'Failed to delete vehicle: \$e';
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

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
