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
  /// codes existed, or by an older app build), and renumbers everyone once
  /// when the numbering order changes. Safe to run repeatedly and from
  /// several devices at once. Returns how many employees were (re)coded.
  Future<int> ensureEmployeeCodes();
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

  /// Version of the numbering order, kept on the counter doc as `scheme`.
  /// Scheme 1 went by join date alone, which put leadership (no join date on
  /// record) mid-list. Raising it renumbers every employee once.
  static const int _codeScheme = 2;

  /// Leadership takes the first codes, in this order.
  static const List<String> _leadershipOrder = ['CEO', 'COO', 'CFO'];

  /// Order codes are issued in: [_leadershipOrder] first, then
  /// longest-serving, then anyone without a join date. Name breaks ties so
  /// every device agrees.
  @visibleForTesting
  static int compareForCodes(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    int rank(Map<String, dynamic> e) {
      final index = _leadershipOrder.indexOf(e['position'] as String? ?? '');
      return index == -1 ? _leadershipOrder.length : index;
    }

    final byRank = rank(a).compareTo(rank(b));
    if (byRank != 0) return byRank;

    final da = DateTime.tryParse(a['joinDate'] as String? ?? '');
    final db = DateTime.tryParse(b['joinDate'] as String? ?? '');
    if (da != null && db != null && da != db) return da.compareTo(db);
    if (da != null && db == null) return -1;
    if (da == null && db != null) return 1;

    final na = (a['fullName'] as String? ?? '').toLowerCase();
    final nb = (b['fullName'] as String? ?? '').toLowerCase();
    return na.compareTo(nb);
  }

  @override
  Future<int> ensureEmployeeCodes() async {
    final counterBefore = await _codeCounter.get();
    final snapshot = await firestore.collection('employees').get();
    final scheme = (counterBefore.data()?['scheme'] as num?)?.toInt() ?? 1;
    final renumber = scheme < _codeScheme;

    final docs = snapshot.docs
        .where((doc) => renumber || doc.data()['employeeCode'] == null)
        .toList()
      ..sort((a, b) => compareForCodes(a.data(), b.data()));
    if (docs.isEmpty && !renumber) return 0;
    final refs = docs.map((doc) => doc.reference).toList();

    // One transaction, so a renumber is all-or-nothing. Firestore allows 500
    // writes per transaction, far more than our headcount.
    return firestore.runTransaction((txn) async {
      final counter = await txn.get(_codeCounter);
      final issued = _lastIssuedNumber(counter);
      // An employee added since the query holds a number this renumber would
      // hand out again. Leave it to the next load, which will see them.
      if (renumber && issued != _lastIssuedNumber(counterBefore)) return 0;

      final fresh = await Future.wait(refs.map(txn.get));
      var last = renumber ? EmployeeCode.firstNumber - 1 : issued;
      var count = 0;
      for (final doc in fresh) {
        if (!doc.exists) continue;
        // Another device may have coded it since the query.
        if (!renumber && doc.data()?['employeeCode'] != null) continue;
        last++;
        txn.update(doc.reference, {'employeeCode': EmployeeCode.format(last)});
        count++;
      }
      txn.set(
        _codeCounter,
        {'value': last, 'scheme': _codeScheme},
        SetOptions(merge: true),
      );
      return count;
    });
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
