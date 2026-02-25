import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/employee_model.dart';

abstract class EmployeeRemoteDataSource {
  Future<List<EmployeeModel>> getAllEmployees();
  Future<void> insertEmployee(EmployeeModel employee);
  Future<void> updateEmployee(EmployeeModel employee);
  Future<void> deleteEmployee(String id);
  Future<String> uploadEmployeeImage(XFile image, String employeeId);
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

    if (kIsWeb) {
      await storageRef.putData(await image.readAsBytes());
    } else {
      await storageRef.putFile(File(image.path));
    }

    return await storageRef.getDownloadURL();
  }
}
