import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/employee_model.dart';
import '../models/employee_role_model.dart';
import '../models/employee_settings_model.dart';

abstract class EmployeeRemoteDataSource {
  Future<List<EmployeeModel>> getAllEmployees();
  Future<void> insertEmployee(EmployeeModel employee);
  Future<void> updateEmployee(EmployeeModel employee);
  Future<void> deleteEmployee(String id);
  Future<String> uploadEmployeeImage(XFile image, String employeeId);

  /// Uploads a scanned document attachment to Firebase Storage.
  /// [docType] is a short label like 'iqama', 'passport', etc.
  Future<String> uploadDocumentAttachment(
    XFile file,
    String employeeId,
    String docType,
  );
  Future<EmployeeSettingsModel> getEmployeeSettings();
  Future<void> updateEmployeeSettings(EmployeeSettingsModel settings);

  /// Roles created from the master (stored in `employee_roles`); the
  /// built-in [EmployeeRoleEntity.defaults] are not stored.
  Future<List<EmployeeRoleModel>> getEmployeeRoles();
  Future<void> saveEmployeeRole(EmployeeRoleModel role, {String? previousName});
  Future<void> deleteEmployeeRole(String id);
}

class EmployeeRemoteDataSourceImpl implements EmployeeRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;

  EmployeeRemoteDataSourceImpl({
    required this.firestore,
    required this.storage,
  });

  @override
  Future<List<EmployeeModel>> getAllEmployees() async {
    final snapshot = await firestore
        .collection('employees')
        .orderBy('fullName')
        .get();

    return snapshot.docs
        .map((doc) => EmployeeModel.fromJson(doc.data()))
        .toList();
  }

  @override
  Future<void> insertEmployee(EmployeeModel employee) async {
    await firestore
        .collection('employees')
        .doc(employee.id)
        .set(employee.toJson());
  }

  @override
  Future<void> updateEmployee(EmployeeModel employee) async {
    await firestore
        .collection('employees')
        .doc(employee.id)
        .update(employee.toJson());
  }

  @override
  Future<void> deleteEmployee(String id) async {
    await firestore.collection('employees').doc(id).delete();
  }

  String _getMimeType(String ext) {
    switch (ext.toLowerCase().replaceAll('.', '')) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'application/octet-stream';
    }
  }

  @override
  Future<String> uploadEmployeeImage(XFile image, String employeeId) async {
    final storageRef = storage
        .ref()
        .child('employee_images')
        .child('$employeeId.jpg');

    final metadata = SettableMetadata(contentType: 'image/jpeg');

    if (kIsWeb) {
      await storageRef.putData(
        await image.readAsBytes(),
        metadata,
      );
    } else {
      await storageRef.putFile(File(image.path), metadata);
    }

    return await storageRef.getDownloadURL();
  }

  @override
  Future<String> uploadDocumentAttachment(
    XFile file,
    String employeeId,
    String docType,
  ) async {
    final ext = file.name.split('.').last.toLowerCase();
    final storageRef = storage
        .ref()
        .child('employee_documents')
        .child(employeeId)
        .child('$docType.$ext');

    final metadata = SettableMetadata(contentType: _getMimeType(ext));

    if (kIsWeb) {
      await storageRef.putData(
        await file.readAsBytes(),
        metadata,
      );
    } else {
      await storageRef.putFile(File(file.path), metadata);
    }

    return await storageRef.getDownloadURL();
  }

  @override
  Future<EmployeeSettingsModel> getEmployeeSettings() async {
    final doc = await firestore.collection('Settings').doc('employee_settings').get();
    if (doc.exists && doc.data() != null) {
      return EmployeeSettingsModel.fromJson(doc.data()!);
    }
    return const EmployeeSettingsModel();
  }

  @override
  Future<void> updateEmployeeSettings(EmployeeSettingsModel settings) async {
    await firestore
        .collection('Settings')
        .doc('employee_settings')
        .set(settings.toJson(), SetOptions(merge: true));
  }

  @override
  Future<List<EmployeeRoleModel>> getEmployeeRoles() async {
    final snapshot = await firestore
        .collection('employee_roles')
        .orderBy('name')
        .get();
    return snapshot.docs
        .map((doc) => EmployeeRoleModel.fromJson(doc.data()..['id'] = doc.id))
        .toList();
  }

  @override
  Future<void> saveEmployeeRole(
    EmployeeRoleModel role, {
    String? previousName,
  }) async {
    final batch = firestore.batch();
    batch.set(
      firestore.collection('employee_roles').doc(role.id),
      role.toJson(),
    );
    // Employees store the role name as their position, so carry a rename
    // over to everyone holding it.
    if (previousName != null && previousName != role.name) {
      final holders = await firestore
          .collection('employees')
          .where('position', isEqualTo: previousName)
          .get();
      for (final doc in holders.docs) {
        batch.update(doc.reference, {'position': role.name});
      }
    }
    await batch.commit();
  }

  @override
  Future<void> deleteEmployeeRole(String id) async {
    await firestore.collection('employee_roles').doc(id).delete();
  }
}
