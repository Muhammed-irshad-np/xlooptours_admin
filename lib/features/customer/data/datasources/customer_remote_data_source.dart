import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/customer_model.dart';

abstract class CustomerRemoteDataSource {
  Future<List<CustomerModel>> getAllCustomers();
  Future<List<CustomerModel>> getCustomersForCompany(String companyId);
  Future<void> insertCustomer(CustomerModel customer);
  Future<void> updateCustomer(CustomerModel customer);
  Future<void> deleteCustomer(String id);
}

class CustomerRemoteDataSourceImpl implements CustomerRemoteDataSource {
  final FirebaseFirestore firestore;

  CustomerRemoteDataSourceImpl({required this.firestore});

  // Note: the collection was renamed to 'travelers' to avoid conflict with legacy 'customers'
  // which meant 'companies' in the old logic.

  @override
  Future<List<CustomerModel>> getAllCustomers() async {
    final snapshot = await firestore
        .collection('travelers')
        .orderBy('name')
        .get();

    return snapshot.docs
        .map((doc) => CustomerModel.fromJson(doc.data()))
        .toList();
  }

  @override
  Future<List<CustomerModel>> getCustomersForCompany(String companyId) async {
    final snapshot = await firestore
        .collection('travelers')
        .where('companyId', isEqualTo: companyId)
        .orderBy('name')
        .get();

    return snapshot.docs
        .map((doc) => CustomerModel.fromJson(doc.data()))
        .toList();
  }

  @override
  Future<void> insertCustomer(CustomerModel customer) async {
    await firestore
        .collection('travelers')
        .doc(customer.id)
        .set(customer.toJson());
  }

  @override
  Future<void> updateCustomer(CustomerModel customer) async {
    await firestore
        .collection('travelers')
        .doc(customer.id)
        .update(customer.toJson());
  }

  @override
  Future<void> deleteCustomer(String id) async {
    await firestore.collection('travelers').doc(id).delete();
  }
}
