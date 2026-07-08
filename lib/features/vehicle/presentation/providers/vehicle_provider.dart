import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/entities/vehicle_entity.dart';
import '../../domain/entities/vehicle_make_entity.dart';
import '../../domain/entities/maintenance_type_entity.dart';
import '../../domain/entities/vehicle_documents.dart';
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
import '../../domain/usecases/get_vehicle_settings_usecase.dart';
import '../../domain/usecases/update_vehicle_settings_usecase.dart';
import '../../domain/entities/vehicle_settings_entity.dart';
import '../../domain/usecases/extend_vehicle_maintenance_usecase.dart';

class VehicleProvider extends ChangeNotifier {
  final GetAllVehiclesUseCase getAllVehiclesUseCase;
  final InsertVehicleUseCase insertVehicleUseCase;
  final UpdateVehicleUseCase updateVehicleUseCase;
  final DeleteVehicleUseCase deleteVehicleUseCase;
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

  final GetVehicleSettingsUseCase getVehicleSettingsUseCase;
  final UpdateVehicleSettingsUseCase updateVehicleSettingsUseCase;
  final ExtendVehicleMaintenanceUseCase extendVehicleMaintenanceUseCase;

  List<VehicleEntity> _vehicles = [];
  List<VehicleMakeEntity> _vehicleMakes = [];
  List<MaintenanceTypeEntity> _maintenanceTypes = [];
  VehicleSettingsEntity? _settings;
  bool _isLoading = false;
  String? _errorMessage;

  VehicleProvider({
    required this.getAllVehiclesUseCase,
    required this.insertVehicleUseCase,
    required this.updateVehicleUseCase,
    required this.deleteVehicleUseCase,
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
    required this.getVehicleSettingsUseCase,
    required this.updateVehicleSettingsUseCase,
    required this.extendVehicleMaintenanceUseCase,
  });

  List<VehicleEntity> get vehicles => _vehicles;
  List<VehicleMakeEntity> get vehicleMakes => _vehicleMakes;
  List<MaintenanceTypeEntity> get maintenanceTypes => _maintenanceTypes;
  VehicleSettingsEntity? get settings => _settings;
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
      final index = _vehicles.indexWhere((v) => v.id == vehicle.id);
      if (index != -1) {
        _vehicles[index] = vehicle;
      }
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to update vehicle: $e';
      debugPrint(_errorMessage);
      rethrow;
    } finally {
      _setLoading(false);
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
        _vehicles[vehicleIndex] = updatedVehicle;
      }
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to update odometer: $e';
      debugPrint(_errorMessage);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteVehicle(String id) async {
    _setLoading(true);
    try {
      await deleteVehicleUseCase(id);
      _vehicles.removeWhere((v) => v.id == id);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to delete vehicle: $e';
      debugPrint(_errorMessage);
      rethrow;
    } finally {
      _setLoading(false);
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
      
      VehicleMaintenance? updatedMaintenance = vehicle.maintenance;
      bool isAuditRecord = record.serviceType?.startsWith('Extension:') ?? false;

      if (isAuditRecord) {
        String category = record.serviceType!.replaceAll('Extension:', '').trim();
        
        // Find the most recent actual record for this category
        int actualIndex = updatedHistory.lastIndexWhere((r) => 
            r.serviceType != null &&
            _isMatchingCategory(r.serviceType!, category) &&
            !r.serviceType!.startsWith('Extension:')
        );

        if (actualIndex != -1) {
          var actualRecord = updatedHistory[actualIndex];
          if (actualRecord.isExtended == true && actualRecord.extendedMileage != null) {
            // Revert the extension
            var revertedRecord = actualRecord.copyWith(
               nextServiceMileage: (actualRecord.nextServiceMileage ?? 0) - actualRecord.extendedMileage!,
               clearExtension: true,
            );
            updatedHistory[actualIndex] = revertedRecord;
            
            // Also need to update `updatedMaintenance` typed field
            updatedMaintenance = _applyExtensionToTypedField(
              updatedMaintenance ?? const VehicleMaintenance(),
              category,
              revertedRecord,
            );
          }
        }
      }

      updatedHistory.remove(record);

      final updatedVehicle = vehicle.copyWith(
        maintenanceHistory: updatedHistory,
        maintenance: updatedMaintenance,
      );

      await updateVehicleUseCase(updatedVehicle);
      final index = _vehicles.indexWhere((v) => v.id == vehicle.id);
      if (index != -1) {
        _vehicles[index] = updatedVehicle;
      }
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to delete maintenance record: $e';
      debugPrint(_errorMessage);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteVehicleDocument(
    VehicleEntity vehicle,
    String documentType,
  ) async {
    _setLoading(true);
    try {
      VehicleEntity updatedVehicle;
      if (documentType == 'Insurance') {
        updatedVehicle = vehicle.copyWith(clearInsurance: true);
      } else if (documentType == 'Isthimara') {
        updatedVehicle = vehicle.copyWith(clearRegistration: true);
      } else if (documentType == 'Fahas') {
        updatedVehicle = vehicle.copyWith(clearFahas: true);
      } else if (documentType == 'Bahrain Insurance') {
        updatedVehicle = vehicle.copyWith(clearBahrainInsurance: true);
      } else {
        throw Exception('Unknown document type: $documentType');
      }

      await updateVehicleUseCase(updatedVehicle);
      final index = _vehicles.indexWhere((v) => v.id == vehicle.id);
      if (index != -1) {
        _vehicles[index] = updatedVehicle;
      }
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to delete document: $e';
      debugPrint(_errorMessage);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteTafweed(VehicleEntity vehicle, TafweedRecord record) async {
    _setLoading(true);
    try {
      final List<TafweedRecord> updatedTafweeds = List.from(vehicle.tafweeds ?? []);
      updatedTafweeds.remove(record);

      final List<TafweedRecord> updatedHistory = List.from(vehicle.tafweedHistory ?? []);
      updatedHistory.removeWhere((t) => t.driverId == record.driverId && t.issuedDate == record.issuedDate);

      final updatedVehicle = vehicle.copyWith(
        tafweeds: updatedTafweeds,
        tafweedHistory: updatedHistory,
      );

      await updateVehicleUseCase(updatedVehicle);
      final index = _vehicles.indexWhere((v) => v.id == vehicle.id);
      if (index != -1) {
        _vehicles[index] = updatedVehicle;
      }
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to delete Tafweed record: $e';
      debugPrint(_errorMessage);
      rethrow;
    } finally {
      _setLoading(false);
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
      _errorMessage = 'Failed to delete maintenance type: $e';
      debugPrint(_errorMessage);
      _setLoading(false);
      rethrow;
    }
  }

  // ======================
  // Settings Methods
  // ======================

  Future<void> fetchVehicleSettings() async {
    _setLoading(true);
    try {
      _settings = await getVehicleSettingsUseCase();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to fetch settings: $e';
      debugPrint(_errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateVehicleSettings(VehicleSettingsEntity settings) async {
    _setLoading(true);
    try {
      await updateVehicleSettingsUseCase(settings);
      _settings = settings;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to update settings: $e';
      debugPrint(_errorMessage);
      _setLoading(false);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> extendVehicleMaintenance({
    required VehicleEntity vehicle,
    required String category,
    required int extensionKm,
    required String reason,
    String? performedBy,
    int? baseOdometer,
  }) async {
    _setLoading(true);
    try {
      await extendVehicleMaintenanceUseCase(
        vehicle: vehicle,
        category: category,
        extensionKm: extensionKm,
        reason: reason,
        performedBy: performedBy,
        baseOdometer: baseOdometer,
      );
      await fetchAllVehicles();
    } catch (e) {
      _errorMessage = 'Failed to extend maintenance: $e';
      debugPrint(_errorMessage);
      _setLoading(false);
      rethrow;
    }
  }

  bool _isMatchingCategory(String serviceType, String category) {
    final s = serviceType.toLowerCase().trim();
    final c = category.toLowerCase().trim();
    if (s == c) return true;
    
    // Normalize engine oil variants
    final engineOilKeywords = ['engine oil', 'engine oil change', 'oil filter', 'engine oil & filter', 'engine_oil'];
    if (engineOilKeywords.contains(s) && engineOilKeywords.contains(c)) {
      return true;
    }
    
    // Normalize space vs underscore differences
    return s.replaceAll(' ', '_') == c.replaceAll(' ', '_');
  }

  VehicleMaintenance _applyExtensionToTypedField(
    VehicleMaintenance m,
    String category,
    MaintenanceRecord updatedRecord,
  ) {
    final norm = category.toLowerCase().trim();
    if (norm == 'engine oil' || norm == 'engine oil change' || norm == 'engine_oil' || norm.contains('engine oil') || norm == 'engine oil & filter') {
      return m.copyWith(engineOil: updatedRecord);
    }
    if (norm == 'gear oil' || norm == 'gear_oil') {
      return m.copyWith(gearOil: updatedRecord);
    }
    if (norm == 'housing oil' || norm == 'housing_oil') {
      return m.copyWith(housingOil: updatedRecord);
    }
    if (norm == 'tyre change' || norm == 'tyre_change') {
      return m.copyWith(tyreChange: updatedRecord);
    }
    if (norm == 'battery change' || norm == 'battery_change') {
      return m.copyWith(batteryChange: updatedRecord);
    }
    if (norm == 'brake pads' || norm == 'brake_pads') {
      return m.copyWith(brakePads: updatedRecord);
    }
    if (norm == 'air filter' || norm == 'air_filter') {
      return m.copyWith(airFilter: updatedRecord);
    }
    if (norm == 'ac service' || norm == 'ac_service') {
      return m.copyWith(acService: updatedRecord);
    }
    if (norm == 'wheel alignment' || norm == 'wheel_alignment') {
      return m.copyWith(wheelAlignment: updatedRecord);
    }
    if (norm == 'spark plugs' || norm == 'spark_plugs') {
      return m.copyWith(sparkPlugs: updatedRecord);
    }
    if (norm == 'coolant flush' || norm == 'coolant_flush') {
      return m.copyWith(coolantFlush: updatedRecord);
    }
    if (norm == 'wiper blades' || norm == 'wiper_blades') {
      return m.copyWith(wiperBlades: updatedRecord);
    }
    if (norm == 'timing belt' || norm == 'timing_belt') {
      return m.copyWith(timingBelt: updatedRecord);
    }
    if (norm == 'transmission fluid' || norm == 'transmission_fluid') {
      return m.copyWith(transmissionFluid: updatedRecord);
    }
    if (norm == 'brake fluid' || norm == 'brake_fluid') {
      return m.copyWith(brakeFluid: updatedRecord);
    }
    if (norm == 'fuel filter' || norm == 'fuel_filter') {
      return m.copyWith(fuelFilter: updatedRecord);
    }
    return m;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
