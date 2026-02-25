import '../entities/customer_entity.dart';

abstract class CustomerRepository {
  Future<List<CustomerEntity>> getAllCustomers();
  Future<List<CustomerEntity>> getCustomersForCompany(String companyId);
  Future<void> insertCustomer(CustomerEntity customer);
  Future<void> updateCustomer(CustomerEntity customer);
  Future<void> deleteCustomer(String id);
}
