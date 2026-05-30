import '../../domain/entities/customer_entity.dart';
import '../../domain/repositories/customer_repository.dart';
import '../datasources/customer_remote_data_source.dart';
import '../models/customer_model.dart';

class CustomerRepositoryImpl implements CustomerRepository {
  final CustomerRemoteDataSource remoteDataSource;

  CustomerRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<CustomerEntity>> getAllCustomers() async {
    final models = await remoteDataSource.getAllCustomers();
    return List<CustomerEntity>.from(models);
  }

  @override
  Future<List<CustomerEntity>> getCustomersForCompany(String companyId) async {
    final models = await remoteDataSource.getCustomersForCompany(companyId);
    return List<CustomerEntity>.from(models);
  }

  @override
  Future<void> insertCustomer(CustomerEntity customer) async {
    final customerModel = CustomerModel.fromEntity(customer);
    await remoteDataSource.insertCustomer(customerModel);
  }

  @override
  Future<void> updateCustomer(CustomerEntity customer) async {
    final customerModel = CustomerModel.fromEntity(customer);
    await remoteDataSource.updateCustomer(customerModel);
  }

  @override
  Future<void> deleteCustomer(String id) async {
    await remoteDataSource.deleteCustomer(id);
  }
}
