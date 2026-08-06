import '../entities/shop_entity.dart';
import '../repositories/vehicle_repository.dart';

class GetAllShopsUseCase {
  final VehicleRepository repository;

  GetAllShopsUseCase(this.repository);

  Future<List<ShopEntity>> call() async {
    return await repository.getAllShops();
  }
}
