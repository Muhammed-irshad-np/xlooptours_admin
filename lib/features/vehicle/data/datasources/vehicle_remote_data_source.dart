import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:xloop_invoice/core/utils/file_upload_helper.dart';
import 'package:xloop_invoice/features/vehicle/data/models/vehicle_settings_model.dart';

import '../models/vehicle_model.dart';
import '../models/vehicle_make_model.dart';
import '../models/maintenance_type_model.dart';
import '../models/shop_model.dart';

abstract class VehicleRemoteDataSource {
  // Vehicle
  Future<List<VehicleModel>> getAllVehicles();
  Future<void> insertVehicle(VehicleModel vehicle);
  Future<void> updateVehicle(VehicleModel vehicle);
  Future<void> deleteVehicle(String id);
  Future<String> uploadVehicleImage(XFile image, String vehicleId);

  // Vehicle Make
  Future<List<VehicleMakeModel>> getAllVehicleMakes();
  Future<void> insertVehicleMake(VehicleMakeModel make);
  Future<void> updateVehicleMake(VehicleMakeModel make);
  Future<void> deleteVehicleMake(String id);

  // Maintenance Types
  Future<List<MaintenanceTypeModel>> getAllMaintenanceTypes();
  Future<void> insertMaintenanceType(MaintenanceTypeModel type);
  Future<void> updateMaintenanceType(MaintenanceTypeModel type);
  Future<void> deleteMaintenanceType(String id);

  // Shops
  Future<List<ShopModel>> getAllShops();
  Future<void> insertShop(ShopModel shop);
  Future<void> updateShop(ShopModel shop);
  Future<void> deleteShop(String id);

  /// Uploads a scanned document attachment to Firebase Storage.
  Future<String> uploadDocumentAttachment(
    XFile file,
    String vehicleId,
    String docType,
  );

  // Settings
  Future<VehicleSettingsModel> getVehicleSettings();
  Future<void> updateVehicleSettings(VehicleSettingsModel settings);
}

class VehicleRemoteDataSourceImpl implements VehicleRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;

  VehicleRemoteDataSourceImpl({required this.firestore, required this.storage});

  @override
  Future<List<VehicleModel>> getAllVehicles() async {
    final snapshot = await firestore.collection('vehicles').get();
    return snapshot.docs
        .map((doc) => VehicleModel.fromJson(doc.data()))
        .toList();
  }

  @override
  Future<void> insertVehicle(VehicleModel vehicle) async {
    await firestore
        .collection('vehicles')
        .doc(vehicle.id)
        .set(vehicle.toJson());
  }

  @override
  Future<void> updateVehicle(VehicleModel vehicle) async {
    final Map<String, dynamic> vehicleData = vehicle.toJson();

    // Note: We no longer remove null values here. This allows explicitly setting fields
    // to null in Firestore (e.g., when deleting a document attachment or clearing a field).
    // The VehicleModel.toJson() provides a full representation of the entity.

    await firestore.collection('vehicles').doc(vehicle.id).update(vehicleData);
  }

  @override
  Future<void> deleteVehicle(String id) async {
    await firestore.collection('vehicles').doc(id).delete();
  }

  @override
  Future<String> uploadVehicleImage(XFile image, String vehicleId) async {
    final storageRef = storage
        .ref()
        .child('vehicle_images')
        .child('$vehicleId.jpg');

    final metadata = SettableMetadata(contentType: 'image/jpeg');

    if (kIsWeb) {
      await storageRef.putData(await image.readAsBytes(), metadata);
    } else {
      await storageRef.putFile(File(image.path), metadata);
    }

    return await storageRef.getDownloadURL();
  }

  @override
  Future<String> uploadDocumentAttachment(
    XFile file,
    String vehicleId,
    String docType,
  ) async {
    // Read bytes and detect true file type via magic bytes.
    final bytes = await file.readAsBytes();
    final info = FileUploadHelper.getUploadInfo(bytes, file.name);

    final nameWithoutExt = path.basenameWithoutExtension(file.name).isNotEmpty
        ? path.basenameWithoutExtension(file.name)
        : docType;
    final storageRef = storage
        .ref()
        .child('vehicle_documents')
        .child(vehicleId)
        .child('${nameWithoutExt}_${DateTime.now().millisecondsSinceEpoch}${info.extension}');

    final metadata = SettableMetadata(
      contentType: info.mimeType,
      customMetadata: {'originalName': file.name, 'docType': docType},
    );

    await storageRef.putData(bytes, metadata);
    return await storageRef.getDownloadURL();
  }

  @override
  Future<List<VehicleMakeModel>> getAllVehicleMakes() async {
    final snapshot = await firestore
        .collection('vehicle_makes')
        .orderBy('name')
        .get();
    return snapshot.docs
        .map((doc) => VehicleMakeModel.fromJson(doc.data()))
        .toList();
  }

  @override
  Future<void> insertVehicleMake(VehicleMakeModel make) async {
    await firestore.collection('vehicle_makes').doc(make.id).set(make.toJson());
  }

  @override
  Future<void> updateVehicleMake(VehicleMakeModel make) async {
    await firestore
        .collection('vehicle_makes')
        .doc(make.id)
        .update(make.toJson());
  }

  @override
  Future<void> deleteVehicleMake(String id) async {
    await firestore.collection('vehicle_makes').doc(id).delete();
  }

  @override
  Future<List<MaintenanceTypeModel>> getAllMaintenanceTypes() async {
    final snapshot = await firestore
        .collection('maintenance_types')
        .orderBy('name')
        .get();
    return snapshot.docs
        .map(
          (doc) => MaintenanceTypeModel.fromJson(
            doc.data()..['documentId'] = doc.id,
          ),
        )
        .toList();
  }

  @override
  Future<void> insertMaintenanceType(MaintenanceTypeModel type) async {
    await firestore
        .collection('maintenance_types')
        .doc(type.id)
        .set(type.toJson());
  }

  @override
  Future<void> updateMaintenanceType(MaintenanceTypeModel type) async {
    await firestore
        .collection('maintenance_types')
        .doc(type.id)
        .update(type.toJson());
  }

  @override
  Future<void> deleteMaintenanceType(String id) async {
    await firestore.collection('maintenance_types').doc(id).delete();
  }

  @override
  Future<List<ShopModel>> getAllShops() async {
    final snapshot = await firestore.collection('shops').orderBy('name').get();
    return snapshot.docs
        .map((doc) => ShopModel.fromJson(doc.data()..['id'] = doc.id))
        .toList();
  }

  @override
  Future<void> insertShop(ShopModel shop) async {
    await firestore.collection('shops').doc(shop.id).set(shop.toJson());
  }

  @override
  Future<void> updateShop(ShopModel shop) async {
    await firestore.collection('shops').doc(shop.id).update(shop.toJson());
  }

  @override
  Future<void> deleteShop(String id) async {
    await firestore.collection('shops').doc(id).delete();
  }

  @override
  Future<VehicleSettingsModel> getVehicleSettings() async {
    final doc = await firestore
        .collection('settings')
        .doc('vehicle_alerts')
        .get();
    if (doc.exists) {
      return VehicleSettingsModel.fromJson(doc.data()!);
    }
    return const VehicleSettingsModel();
  }

  @override
  Future<void> updateVehicleSettings(VehicleSettingsModel settings) async {
    await firestore
        .collection('settings')
        .doc('vehicle_alerts')
        .set(settings.toJson());
  }
}
