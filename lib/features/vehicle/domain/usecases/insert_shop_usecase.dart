import '../entities/shop_entity.dart';
import '../repositories/vehicle_repository.dart';

class InsertShopUseCase {
  final VehicleRepository repository;

  InsertShopUseCase(this.repository);

  Future<void> call(ShopEntity shop) async {
    await repository.insertShop(shop);
  }
}
