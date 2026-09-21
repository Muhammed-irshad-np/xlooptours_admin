import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/entities/odometer_reading_entity.dart';
import '../models/odometer_reading_model.dart';

abstract class OdometerRemoteDataSource {
  /// All readings for one vehicle, oldest first.
  Future<List<OdometerReadingModel>> getReadings(String vehicleId);

  /// Readings across the whole fleet that are awaiting review.
  Future<List<OdometerReadingModel>> getQuarantinedReadings();

  /// The most recent readings across the fleet, used for the fleet baseline.
  Future<List<OdometerReadingModel>> getRecentReadings({int limit = 500});

  /// Appends a reading. Readings are immutable once written.
  Future<void> insertReading(OdometerReadingModel reading);

  /// Updates only the review/supersede fields on an existing reading. The
  /// observation itself (value, readingAt, source, entrant) is never changed.
  Future<void> updateReadingReview(OdometerReadingModel reading);

  Future<String> uploadOdometerPhoto(XFile photo, String vehicleId, String readingId);
}

class OdometerRemoteDataSourceImpl implements OdometerRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;

  OdometerRemoteDataSourceImpl({required this.firestore, required this.storage});

  /// Readings live in a subcollection of the vehicle so that security rules,
  /// deletes and exports follow the vehicle naturally.
  CollectionReference<Map<String, dynamic>> _col(String vehicleId) => firestore
      .collection('vehicles')
      .doc(vehicleId)
      .collection('odometerReadings');

  @override
  Future<List<OdometerReadingModel>> getReadings(String vehicleId) async {
    final snap = await _col(vehicleId).orderBy('readingAt').get();
    return snap.docs.map((d) => OdometerReadingModel.fromJson(d.data())).toList();
  }

  @override
  Future<List<OdometerReadingModel>> getQuarantinedReadings() async {
    // Collection group query: one read for the whole fleet's review queue.
    final snap = await firestore
        .collectionGroup('odometerReadings')
        .where('status', isEqualTo: 'quarantined')
        .get();
    final list = snap.docs
        .map((d) => OdometerReadingModel.fromJson(d.data()))
        .toList();
    list.sort((a, b) => b.readingAt.compareTo(a.readingAt));
    return list;
  }

  @override
  Future<List<OdometerReadingModel>> getRecentReadings({int limit = 500}) async {
    final snap = await firestore
        .collectionGroup('odometerReadings')
        .where('status', isEqualTo: 'accepted')
        .orderBy('readingAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => OdometerReadingModel.fromJson(d.data())).toList();
  }

  @override
  Future<void> insertReading(OdometerReadingModel reading) async {
    await _col(reading.vehicleId).doc(reading.id).set(reading.toJson());
  }

  @override
  Future<void> updateReadingReview(OdometerReadingModel reading) async {
    await _col(reading.vehicleId).doc(reading.id).update({
      'status': reading.status.wireName,
      'supersededByReadingId': reading.supersededByReadingId,
      'reviewedByUid': reading.reviewedByUid,
      'reviewedByName': reading.reviewedByName,
      'reviewedAt': reading.reviewedAt?.toIso8601String(),
      'reviewNote': reading.reviewNote,
    });
  }

  @override
  Future<String> uploadOdometerPhoto(
    XFile photo,
    String vehicleId,
    String readingId,
  ) async {
    final ref = storage
        .ref()
        .child('odometer_readings')
        .child(vehicleId)
        .child('$readingId.jpg');

    final metadata = SettableMetadata(contentType: 'image/jpeg');

    if (kIsWeb) {
      await ref.putData(await photo.readAsBytes(), metadata);
    } else {
      await ref.putFile(File(photo.path), metadata);
    }
    return await ref.getDownloadURL();
  }
}
