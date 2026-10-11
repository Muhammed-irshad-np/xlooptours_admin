import 'package:image_picker/image_picker.dart';
import '../entities/vehicle_entity.dart';
import '../entities/vehicle_make_entity.dart';
import '../entities/maintenance_type_entity.dart';
import '../entities/vehicle_settings_entity.dart';

import '../entities/shop_entity.dart';

abstract class VehicleRepository {
  // Vehicle Methods
  Future<List<VehicleEntity>> getAllVehicles();
  Future<void> insertVehicle(VehicleEntity vehicle);
  Future<void> updateVehicle(VehicleEntity vehicle);

  /// Applies [change] to the vehicle as currently stored and saves only the
  /// fields it changed, so edits other users made since this page loaded are
  /// kept. Returns the vehicle as saved. Use this for maintenance changes;
  /// [updateVehicle] does not write maintenance.
  Future<VehicleEntity> modifyVehicle(
    String vehicleId,
    VehicleEntity Function(VehicleEntity latest) change,
  );
  Future<void> deleteVehicle(String id);
  Future<String> uploadVehicleImage(XFile image, String vehicleId);
  Future<String> uploadDocumentAttachment(
    XFile file,
    String vehicleId,
    String docType,
  );

  // Vehicle Make Methods
  Future<List<VehicleMakeEntity>> getAllVehicleMakes();
  Future<void> insertVehicleMake(VehicleMakeEntity make);
  Future<void> updateVehicleMake(VehicleMakeEntity make);
  Future<void> deleteVehicleMake(String id);

  // Maintenance Types Methods
  Future<List<MaintenanceTypeEntity>> getAllMaintenanceTypes();
  Future<void> insertMaintenanceType(MaintenanceTypeEntity type);
  Future<void> updateMaintenanceType(MaintenanceTypeEntity type);
  Future<void> deleteMaintenanceType(String id);

  // Shop Methods
  Future<List<ShopEntity>> getAllShops();
  Future<void> insertShop(ShopEntity shop);
  Future<void> updateShop(ShopEntity shop);
  Future<void> deleteShop(String id);

  // Settings Methods
  Future<VehicleSettingsEntity> getVehicleSettings();
  Future<void> updateVehicleSettings(VehicleSettingsEntity settings);
}

