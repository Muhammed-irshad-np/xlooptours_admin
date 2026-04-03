import 'package:image_picker/image_picker.dart';
import '../entities/vehicle_entity.dart';
import '../entities/vehicle_make_entity.dart';
import '../entities/maintenance_type_entity.dart';

abstract class VehicleRepository {
  // Vehicle Methods
  Future<List<VehicleEntity>> getAllVehicles();
  Future<void> insertVehicle(VehicleEntity vehicle);
  Future<void> updateVehicle(VehicleEntity vehicle);
  Future<void> deleteVehicle(String id);
  Future<void> assignDriverToVehicle(String? vehicleId, String driverId);
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
}
