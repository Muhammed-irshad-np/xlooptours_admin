import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/vehicle_model.dart';
import '../models/vehicle_make_model.dart';

abstract class VehicleRemoteDataSource {
  // Vehicle
  Future<List<VehicleModel>> getAllVehicles();
  Future<void> insertVehicle(VehicleModel vehicle);
  Future<void> updateVehicle(VehicleModel vehicle);
  Future<void> deleteVehicle(String id);
  Future<void> assignDriverToVehicle(String? vehicleId, String driverId);
  Future<String> uploadVehicleImage(XFile image, String vehicleId);

  // Vehicle Make
  Future<List<VehicleMakeModel>> getAllVehicleMakes();
  Future<void> insertVehicleMake(VehicleMakeModel make);
  Future<void> updateVehicleMake(VehicleMakeModel make);
  Future<void> deleteVehicleMake(String id);
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
    // Enforce 1:1 Driver Assignment
    if (vehicle.assignedDriverId != null) {
      final batch = firestore.batch();
      final currentAssignments = await firestore
          .collection('vehicles')
          .where('assignedDriverId', isEqualTo: vehicle.assignedDriverId)
          .get();

      for (var doc in currentAssignments.docs) {
        if (doc.id != vehicle.id) {
          batch.update(doc.reference, {'assignedDriverId': null});
        }
      }
      await batch.commit();
    }
    await firestore
        .collection('vehicles')
        .doc(vehicle.id)
        .update(vehicle.toJson());
  }

  @override
  Future<void> deleteVehicle(String id) async {
    await firestore.collection('vehicles').doc(id).delete();
  }

  @override
  Future<void> assignDriverToVehicle(String? vehicleId, String driverId) async {
    final batch = firestore.batch();

    // 1. Find any OTHER vehicle currently assigned to this driver
    final currentAssignments = await firestore
        .collection('vehicles')
        .where('assignedDriverId', isEqualTo: driverId)
        .get();

    for (var doc in currentAssignments.docs) {
      if (doc.id != vehicleId) {
        // Unassign from old vehicle
        batch.update(doc.reference, {'assignedDriverId': null});
      }
    }

    // 2. Assign to new vehicle (if provided)
    if (vehicleId != null) {
      final vehicleRef = firestore.collection('vehicles').doc(vehicleId);
      batch.update(vehicleRef, {'assignedDriverId': driverId});
    }

    await batch.commit();
  }

  @override
  Future<String> uploadVehicleImage(XFile image, String vehicleId) async {
    final storageRef = storage
        .ref()
        .child('vehicle_images')
        .child('\$vehicleId.jpg');

    if (kIsWeb) {
      await storageRef.putData(await image.readAsBytes());
    } else {
      await storageRef.putFile(File(image.path));
    }

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
}
