import '../entities/work_order_entity.dart';
import '../repositories/work_order_repository.dart';

class GetWorkOrdersUseCase {
  final WorkOrderRepository repository;

  GetWorkOrdersUseCase(this.repository);

  Future<List<WorkOrderEntity>> call({int limit = 300}) =>
      repository.getWorkOrders(limit: limit);
}

class GetWorkOrdersForVehicleUseCase {
  final WorkOrderRepository repository;

  GetWorkOrdersForVehicleUseCase(this.repository);

  Future<List<WorkOrderEntity>> call(String vehicleId) =>
      repository.getWorkOrdersForVehicle(vehicleId);
}

class GetOpenWorkOrdersUseCase {
  final WorkOrderRepository repository;

  GetOpenWorkOrdersUseCase(this.repository);

  Future<List<WorkOrderEntity>> call() => repository.getOpenWorkOrders();
}

class GetWorkOrderByIdUseCase {
  final WorkOrderRepository repository;

  GetWorkOrderByIdUseCase(this.repository);

  Future<WorkOrderEntity?> call(String id) => repository.getWorkOrderById(id);
}
