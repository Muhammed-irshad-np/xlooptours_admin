import '../entities/customer_entity.dart';
import '../repositories/customer_repository.dart';

class GetAllCustomersUseCase {
  final CustomerRepository repository;

  GetAllCustomersUseCase(this.repository);

  Future<List<CustomerEntity>> call() async {
    return await repository.getAllCustomers();
  }
}
