import '../entities/customer_entity.dart';
import '../repositories/customer_repository.dart';

class GetCustomersForCompanyUseCase {
  final CustomerRepository repository;

  GetCustomersForCompanyUseCase(this.repository);

  Future<List<CustomerEntity>> call(String companyId) async {
    return await repository.getCustomersForCompany(companyId);
  }
}
