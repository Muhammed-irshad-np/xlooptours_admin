import 'package:image_picker/image_picker.dart';

import '../entities/work_order_entity.dart';

abstract class WorkOrderRepository {
  Future<List<WorkOrderEntity>> getWorkOrders({int limit});
  Future<List<WorkOrderEntity>> getWorkOrdersForVehicle(String vehicleId);
  Future<List<WorkOrderEntity>> getOpenWorkOrders();
  Future<WorkOrderEntity?> getWorkOrderById(String id);
  Future<void> insertWorkOrder(WorkOrderEntity workOrder);
  Future<void> updateWorkOrder(WorkOrderEntity workOrder);
  Future<void> deleteWorkOrder(String id);
  Future<String> generateWorkOrderNumber();
  Future<String> uploadAttachment(
    XFile file,
    String workOrderId,
    String kind,
  );
}
