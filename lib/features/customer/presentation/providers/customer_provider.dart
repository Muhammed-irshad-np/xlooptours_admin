import 'package:flutter/foundation.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/usecases/get_all_customers_usecase.dart';
import '../../domain/usecases/get_customers_for_company_usecase.dart';
import '../../domain/usecases/insert_customer_usecase.dart';
import '../../domain/usecases/update_customer_usecase.dart';
import '../../domain/usecases/delete_customer_usecase.dart';

class CustomerProvider with ChangeNotifier {
  final GetAllCustomersUseCase _getAllCustomersUseCase;
  final GetCustomersForCompanyUseCase _getCustomersForCompanyUseCase;
  final InsertCustomerUseCase _insertCustomerUseCase;
  final UpdateCustomerUseCase _updateCustomerUseCase;
  final DeleteCustomerUseCase _deleteCustomerUseCase;

  CustomerProvider({
    required GetAllCustomersUseCase getAllCustomersUseCase,
    required GetCustomersForCompanyUseCase getCustomersForCompanyUseCase,
    required InsertCustomerUseCase insertCustomerUseCase,
    required UpdateCustomerUseCase updateCustomerUseCase,
    required DeleteCustomerUseCase deleteCustomerUseCase,
  }) : _getAllCustomersUseCase = getAllCustomersUseCase,
       _getCustomersForCompanyUseCase = getCustomersForCompanyUseCase,
       _insertCustomerUseCase = insertCustomerUseCase,
       _updateCustomerUseCase = updateCustomerUseCase,
       _deleteCustomerUseCase = deleteCustomerUseCase;

  List<CustomerEntity> _customers = [];
  bool _isLoading = false;
  String? _error;

  // ── Cache timestamp ───────────────────────────────────────────────────────
  DateTime? _customersLastFetch;
  static const _cacheDuration = Duration(minutes: 5);

  /// Invalidates cached data, forcing a fresh fetch on next access.
  void invalidateCache() {
    _customersLastFetch = null;
  }

  List<CustomerEntity> get customers => _customers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchAllCustomers({bool forceRefresh = false}) async {
    if (!forceRefresh && _customersLastFetch != null && _customers.isNotEmpty &&
        DateTime.now().difference(_customersLastFetch!) < _cacheDuration) {
      return;
    }
    _setLoading(true);
    try {
      _customers = await _getAllCustomersUseCase();
      _customersLastFetch = DateTime.now();
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error fetching customers: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchCustomersForCompany(String companyId) async {
    _setLoading(true);
    try {
      _customers = await _getCustomersForCompanyUseCase(companyId);
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error fetching customers for company $companyId: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addCustomer(CustomerEntity customer) async {
    _setLoading(true);
    try {
      await _insertCustomerUseCase(customer);
      _customers.add(customer);
      // Re-sort the list if necessary, or just rely on the next fetch
      _customers.sort((a, b) => a.name.compareTo(b.name));
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error adding customer: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateCustomer(CustomerEntity customer) async {
    _setLoading(true);
    try {
      await _updateCustomerUseCase(customer);
      final index = _customers.indexWhere((c) => c.id == customer.id);
      if (index != -1) {
        _customers[index] = customer;
        _customers.sort((a, b) => a.name.compareTo(b.name));
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error updating customer: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteCustomer(String id) async {
    _setLoading(true);
    try {
      await _deleteCustomerUseCase(id);
      _customers.removeWhere((c) => c.id == id);
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error deleting customer: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
