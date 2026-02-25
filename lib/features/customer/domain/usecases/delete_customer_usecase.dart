import '../repositories/customer_repository.dart';

class DeleteCustomerUseCase {
  final CustomerRepository repository;

  DeleteCustomerUseCase(this.repository);

  Future<void> call(String id) async {
    return await repository.deleteCustomer(id);
  }
}
