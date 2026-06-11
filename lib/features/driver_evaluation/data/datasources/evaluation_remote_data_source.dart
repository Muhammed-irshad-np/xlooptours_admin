import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:xloop_invoice/core/error/exceptions.dart';
import 'package:xloop_invoice/features/driver_evaluation/data/models/evaluation_model.dart';

abstract class EvaluationRemoteDataSource {
  Future<String> generateEvaluationLink(String driverId, String driverName, String? vehicleId);
  Future<List<EvaluationModel>> getPendingEvaluations();
  Future<void> submitAdminScore(String evaluationId, Map<String, dynamic> scores);
  Future<void> submitDriverForm(String evaluationId, Map<String, dynamic> media);
  Future<EvaluationModel> getEvaluationById(String evaluationId);
  Future<void> deleteEvaluation(String evaluationId);
}

class EvaluationRemoteDataSourceImpl implements EvaluationRemoteDataSource {
  final FirebaseFirestore firestore;

  EvaluationRemoteDataSourceImpl({required this.firestore});

  @override
  Future<String> generateEvaluationLink(String driverId, String driverName, String? vehicleId) async {
    try {
      final docRef = await firestore.collection('evaluations').add({
        'driverId': driverId,
        'driverName': driverName,
        'vehicleId': vehicleId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      // Return the ID which will be used in the web link
      return docRef.id;
    } catch (e) {
      throw ServerException();
    }
  }

  @override
  Future<List<EvaluationModel>> getPendingEvaluations() async {
    try {
      final snapshot = await firestore
          .collection('evaluations')
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => EvaluationModel.fromJson(doc.data(), doc.id)).toList();
    } catch (e) {
      debugPrint('Error getting evaluations: $e');
      throw ServerException();
    }
  }

  @override
  Future<void> submitAdminScore(String evaluationId, Map<String, dynamic> scores) async {
    try {
      await firestore.collection('evaluations').doc(evaluationId).update({
        'scores': scores,
        'status': 'evaluated',
        'evaluatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ServerException();
    }
  }

  @override
  Future<void> submitDriverForm(String evaluationId, Map<String, dynamic> media) async {
    try {
      await firestore.collection('evaluations').doc(evaluationId).update({
        'media': media,
        'submittedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ServerException();
    }
  }

  @override
  Future<EvaluationModel> getEvaluationById(String evaluationId) async {
    try {
      final doc = await firestore.collection('evaluations').doc(evaluationId).get();
      if (doc.exists && doc.data() != null) {
        return EvaluationModel.fromJson(doc.data()!, doc.id);
      } else {
        throw ServerException();
      }
    } catch (e) {
      throw ServerException();
    }
  }

  @override
  Future<void> deleteEvaluation(String evaluationId) async {
    try {
      await firestore.collection('evaluations').doc(evaluationId).delete();
    } catch (e) {
      throw ServerException();
    }
  }
}