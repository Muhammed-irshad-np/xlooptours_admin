import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cross_file/cross_file.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:xloop_invoice/core/utils/file_upload_helper.dart';
import '../models/employee_model.dart';
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
    // Read bytes and detect true file type via magic bytes.
    final bytes = await file.readAsBytes();
    final info = FileUploadHelper.getUploadInfo(bytes, file.name);

    // Use detected extension so the storage path always has a proper extension.
    final nameWithoutExt = path.basenameWithoutExtension(file.name).isNotEmpty
        ? path.basenameWithoutExtension(file.name)
        : docType;
    final storageRef = storage
        .ref()
        .child('employee_documents')
        .child(employeeId)
        .child('${nameWithoutExt}_${DateTime.now().millisecondsSinceEpoch}${info.extension}');

    final metadata = SettableMetadata(
      contentType: info.mimeType,
      customMetadata: {'originalName': file.name, 'docType': docType},
    );

    if (kIsWeb) {
      await storageRef.putData(bytes, metadata);
    } else {
      await storageRef.putData(bytes, metadata);
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
}
