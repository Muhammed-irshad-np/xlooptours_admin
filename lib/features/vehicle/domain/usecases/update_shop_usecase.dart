import '../entities/shop_entity.dart';
import '../repositories/vehicle_repository.dart';

class UpdateShopUseCase {
  final VehicleRepository repository;

  UpdateShopUseCase(this.repository);

  Future<void> call(ShopEntity shop) async {
    await repository.updateShop(shop);
  }
}
