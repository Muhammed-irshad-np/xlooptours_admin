import '../entities/customer_entity.dart';
import '../repositories/customer_repository.dart';

class UpdateCustomerUseCase {
  final CustomerRepository repository;

  UpdateCustomerUseCase(this.repository);

  Future<void> call(CustomerEntity customer) async {
    return await repository.updateCustomer(customer);
  }
}
