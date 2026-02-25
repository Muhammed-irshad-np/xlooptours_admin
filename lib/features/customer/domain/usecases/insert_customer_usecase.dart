import '../entities/customer_entity.dart';
import '../repositories/customer_repository.dart';

class InsertCustomerUseCase {
  final CustomerRepository repository;

  InsertCustomerUseCase(this.repository);

  Future<void> call(CustomerEntity customer) async {
    return await repository.insertCustomer(customer);
  }
}
