import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/employee_entity.dart';
import '../models/employee_model.dart';
import '../models/employee_settings_model.dart';

abstract class EmployeeRemoteDataSource {
  Future<List<EmployeeModel>> getAllEmployees();

  /// Saves a new employee and issues its [EmployeeCode] in the same
  /// transaction, so two people adding at once never share a code.
  /// Returns the issued code.
  Future<String> insertEmployee(EmployeeModel employee);

  /// Issues a code to every employee that has none (records saved before
  /// codes existed, or by an older app build), oldest join date first.
  /// Safe to run repeatedly and from several devices at once.
  /// Returns how many employees were given a code.
  Future<int> assignMissingEmployeeCodes();
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

  DocumentReference<Map<String, dynamic>> get _codeCounter =>
      firestore.collection('counters').doc('employee_code');

  /// Number of the last code issued, held in the counter doc's `value`.
  int _lastIssuedNumber(DocumentSnapshot<Map<String, dynamic>> counter) =>
      (counter.data()?['value'] as num?)?.toInt() ??
      EmployeeCode.firstNumber - 1;

  @override
  Future<String> insertEmployee(EmployeeModel employee) async {
    final employeeRef = firestore.collection('employees').doc(employee.id);
    return firestore.runTransaction((txn) async {
      final counter = await txn.get(_codeCounter);
      final next = _lastIssuedNumber(counter) + 1;
      final code = EmployeeCode.format(next);
      txn.set(_codeCounter, {'value': next}, SetOptions(merge: true));
      txn.set(employeeRef, employee.copyWith(employeeCode: code).toJson());
      return code;
    });
  }

  @override
  Future<int> assignMissingEmployeeCodes() async {
    final snapshot = await firestore.collection('employees').get();

    // Guards against a missing or reset counter handing out a code that is
    // already in use.
    var highestInUse = EmployeeCode.firstNumber - 1;
    for (final doc in snapshot.docs) {
      final code = doc.data()['employeeCode'] as String?;
      final number = code != null && code.startsWith(EmployeeCode.prefix)
          ? int.tryParse(code.substring(EmployeeCode.prefix.length))
          : null;
      if (number != null && number > highestInUse) highestInUse = number;
    }

    DateTime? joinDateOf(QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
        DateTime.tryParse(doc.data()['joinDate'] as String? ?? '');
    String nameOf(QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
        (doc.data()['fullName'] as String? ?? '').toLowerCase();

    // Longest-serving staff get the lowest codes; anyone without a join date
    // goes last. Name breaks ties so the order is the same on every device.
    final missing = snapshot.docs
        .where((doc) => doc.data()['employeeCode'] == null)
        .toList()
      ..sort((a, b) {
        final da = joinDateOf(a);
        final db = joinDateOf(b);
        if (da != null && db != null && da != db) return da.compareTo(db);
        if (da != null && db == null) return -1;
        if (da == null && db != null) return 1;
        return nameOf(a).compareTo(nameOf(b));
      });

    // A transaction allows at most 500 writes, the counter included.
    const chunkSize = 400;
    var assigned = 0;
    for (var start = 0; start < missing.length; start += chunkSize) {
      final refs = missing
          .skip(start)
          .take(chunkSize)
          .map((doc) => doc.reference)
          .toList();
      assigned += await firestore.runTransaction((txn) async {
        final counter = await txn.get(_codeCounter);
        final fresh = await Future.wait(refs.map(txn.get));
        var last = _lastIssuedNumber(counter);
        if (last < highestInUse) last = highestInUse;
        var count = 0;
        for (final doc in fresh) {
          // Another device may have coded or deleted it since the query.
          if (!doc.exists || doc.data()?['employeeCode'] != null) continue;
          last++;
          txn.update(doc.reference, {
            'employeeCode': EmployeeCode.format(last),
          });
          count++;
        }
        if (count > 0) {
          txn.set(_codeCounter, {'value': last}, SetOptions(merge: true));
        }
        return count;
      });
    }
    return assigned;
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
}
