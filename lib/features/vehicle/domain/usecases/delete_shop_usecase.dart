import '../repositories/vehicle_repository.dart';

class DeleteShopUseCase {
  final VehicleRepository repository;

  DeleteShopUseCase(this.repository);

  Future<void> call(String id) async {
    await repository.deleteShop(id);
  }
}
