import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models/work_order_model.dart';

abstract class WorkOrderRemoteDataSource {
  Future<List<WorkOrderModel>> getWorkOrders({int limit});
  Future<List<WorkOrderModel>> getWorkOrdersForVehicle(String vehicleId);

  /// Live work orders only (not closed / rejected / cancelled). Drives alert
  /// suppression and the "needs action" badge.
  Future<List<WorkOrderModel>> getOpenWorkOrders();

  Future<WorkOrderModel?> getWorkOrderById(String id);
  Future<void> insertWorkOrder(WorkOrderModel workOrder);
  Future<void> updateWorkOrder(WorkOrderModel workOrder);
  Future<void> deleteWorkOrder(String id);

  /// Reserves the next sequential work order number, e.g. `WO-2026-0042`.
  Future<String> generateWorkOrderNumber();

  Future<String> uploadAttachment(XFile file, String workOrderId, String kind);
}

class WorkOrderRemoteDataSourceImpl implements WorkOrderRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;

  WorkOrderRemoteDataSourceImpl({
    required this.firestore,
    required this.storage,
  });

  CollectionReference<Map<String, dynamic>> get _workOrders =>
      firestore.collection('work_orders');

  CollectionReference<Map<String, dynamic>> get _counters =>
      firestore.collection('counters');

  static const List<String> _openStatuses = [
    'reported',
    'pendingApproval',
    'approved',
    'inProgress',
    'completed',
    'onHold',
  ];

  @override
  Future<List<WorkOrderModel>> getWorkOrders({int limit = 300}) async {
    final snapshot = await _workOrders
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map((d) => WorkOrderModel.fromJson(d.data())).toList();
  }

  @override
  Future<List<WorkOrderModel>> getWorkOrdersForVehicle(
    String vehicleId,
  ) async {
    final snapshot = await _workOrders
        .where('vehicleId', isEqualTo: vehicleId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((d) => WorkOrderModel.fromJson(d.data())).toList();
  }

  @override
  Future<List<WorkOrderModel>> getOpenWorkOrders() async {
    // `whereIn` caps at 30 values; six statuses is well inside that.
    final snapshot =
        await _workOrders.where('status', whereIn: _openStatuses).get();
    final result =
        snapshot.docs.map((d) => WorkOrderModel.fromJson(d.data())).toList();
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  @override
  Future<WorkOrderModel?> getWorkOrderById(String id) async {
    final doc = await _workOrders.doc(id).get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    return WorkOrderModel.fromJson(data);
  }

  @override
  Future<void> insertWorkOrder(WorkOrderModel workOrder) async {
    await _workOrders.doc(workOrder.id).set(workOrder.toJson());
  }

  @override
  Future<void> updateWorkOrder(WorkOrderModel workOrder) async {
    await _workOrders.doc(workOrder.id).update(workOrder.toJson());
  }

  @override
  Future<void> deleteWorkOrder(String id) async {
    await _workOrders.doc(id).delete();
  }

  @override
  Future<String> generateWorkOrderNumber() async {
    final year = DateTime.now().year;
    final counterRef = _counters.doc('work_order_$year');
    return firestore.runTransaction((txn) async {
      final snap = await txn.get(counterRef);
      var next = 1;
      if (snap.exists) {
        next = ((snap.data()?['value'] as num?)?.toInt() ?? 0) + 1;
      }
      txn.set(counterRef, {'value': next}, SetOptions(merge: true));
      return 'WO-$year-${next.toString().padLeft(4, '0')}';
    });
  }

  @override
  Future<String> uploadAttachment(
    XFile file,
    String workOrderId,
    String kind,
  ) async {
    final ext = file.name.split('.').last;
    final ref = storage.ref(
      'work_orders/$workOrderId/${kind}_${DateTime.now().millisecondsSinceEpoch}.$ext',
    );
    final bytes = await file.readAsBytes();
    await ref.putData(bytes, SettableMetadata(contentType: _mimeType(ext)));
    return ref.getDownloadURL();
  }

  String _mimeType(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }
}
