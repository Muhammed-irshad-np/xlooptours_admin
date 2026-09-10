import 'package:image_picker/image_picker.dart';

import '../../domain/entities/work_order_entity.dart';
import '../../domain/repositories/work_order_repository.dart';
import '../datasources/work_order_remote_data_source.dart';
import '../models/work_order_model.dart';

class WorkOrderRepositoryImpl implements WorkOrderRepository {
  final WorkOrderRemoteDataSource remoteDataSource;

  WorkOrderRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<WorkOrderEntity>> getWorkOrders({int limit = 300}) =>
      remoteDataSource.getWorkOrders(limit: limit);

  @override
  Future<List<WorkOrderEntity>> getWorkOrdersForVehicle(String vehicleId) =>
      remoteDataSource.getWorkOrdersForVehicle(vehicleId);

  @override
  Future<List<WorkOrderEntity>> getOpenWorkOrders() =>
      remoteDataSource.getOpenWorkOrders();

  @override
  Future<WorkOrderEntity?> getWorkOrderById(String id) =>
      remoteDataSource.getWorkOrderById(id);

  @override
  Future<void> insertWorkOrder(WorkOrderEntity workOrder) =>
      remoteDataSource.insertWorkOrder(WorkOrderModel.fromEntity(workOrder));

  @override
  Future<void> updateWorkOrder(WorkOrderEntity workOrder) =>
      remoteDataSource.updateWorkOrder(WorkOrderModel.fromEntity(workOrder));

  @override
  Future<void> deleteWorkOrder(String id) =>
      remoteDataSource.deleteWorkOrder(id);

  @override
  Future<String> generateWorkOrderNumber() =>
      remoteDataSource.generateWorkOrderNumber();

  @override
  Future<String> uploadAttachment(
    XFile file,
    String workOrderId,
    String kind,
  ) =>
      remoteDataSource.uploadAttachment(file, workOrderId, kind);
}
