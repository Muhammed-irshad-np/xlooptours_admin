import 'package:image_picker/image_picker.dart';

import '../../domain/entities/vehicle_entity.dart';
import '../../domain/entities/vehicle_make_entity.dart';
import '../../domain/repositories/vehicle_repository.dart';
import '../datasources/vehicle_remote_data_source.dart';
import '../models/vehicle_model.dart';
import '../models/vehicle_make_model.dart';

class VehicleRepositoryImpl implements VehicleRepository {
  final VehicleRemoteDataSource remoteDataSource;

  VehicleRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<VehicleEntity>> getAllVehicles() async {
    return await remoteDataSource.getAllVehicles();
  }

  @override
  Future<void> insertVehicle(VehicleEntity vehicle) async {
    final vehicleModel = VehicleModel.fromEntity(vehicle);
    return await remoteDataSource.insertVehicle(vehicleModel);
  }

  @override
  Future<void> updateVehicle(VehicleEntity vehicle) async {
    final vehicleModel = VehicleModel.fromEntity(vehicle);
    return await remoteDataSource.updateVehicle(vehicleModel);
  }

  @override
  Future<void> deleteVehicle(String id) async {
    return await remoteDataSource.deleteVehicle(id);
  }

  @override
  Future<void> assignDriverToVehicle(String? vehicleId, String driverId) async {
    return await remoteDataSource.assignDriverToVehicle(vehicleId, driverId);
  }

  @override
  Future<String> uploadVehicleImage(XFile image, String vehicleId) async {
    return await remoteDataSource.uploadVehicleImage(image, vehicleId);
  }

  @override
  Future<String> uploadDocumentAttachment(
    XFile file,
    String vehicleId,
    String docType,
  ) async {
    return await remoteDataSource.uploadDocumentAttachment(
      file,
      vehicleId,
      docType,
    );
  }

  @override
  Future<List<VehicleMakeEntity>> getAllVehicleMakes() async {
    return await remoteDataSource.getAllVehicleMakes();
  }

  @override
  Future<void> insertVehicleMake(VehicleMakeEntity make) async {
    final makeModel = VehicleMakeModel.fromEntity(make);
    return await remoteDataSource.insertVehicleMake(makeModel);
  }

  @override
  Future<void> updateVehicleMake(VehicleMakeEntity make) async {
    final makeModel = VehicleMakeModel.fromEntity(make);
    return await remoteDataSource.updateVehicleMake(makeModel);
  }

  @override
  Future<void> deleteVehicleMake(String id) async {
    return await remoteDataSource.deleteVehicleMake(id);
  }
}
