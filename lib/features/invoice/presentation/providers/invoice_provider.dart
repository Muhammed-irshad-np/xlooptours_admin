import 'package:flutter/foundation.dart';
import '../../domain/entities/invoice_entity.dart';
import '../../domain/usecases/insert_invoice_usecase.dart';
import '../../domain/usecases/get_all_invoices_usecase.dart';
import '../../domain/usecases/update_invoice_usecase.dart';
import '../../domain/usecases/delete_invoice_usecase.dart';
import '../../domain/usecases/generate_invoice_number_usecase.dart';

class InvoiceProvider extends ChangeNotifier {
  final InsertInvoiceUseCase insertInvoiceUseCase;
  final GetAllInvoicesUseCase getAllInvoicesUseCase;
  final UpdateInvoiceUseCase updateInvoiceUseCase;
  final DeleteInvoiceUseCase deleteInvoiceUseCase;
  final GenerateInvoiceNumberUseCase generateInvoiceNumberUseCase;

  List<InvoiceEntity> _invoices = [];
  bool _isLoading = false;
  String? _errorMessage;

  InvoiceProvider({
    required this.insertInvoiceUseCase,
    required this.getAllInvoicesUseCase,
    required this.updateInvoiceUseCase,
    required this.deleteInvoiceUseCase,
    required this.generateInvoiceNumberUseCase,
  });

  List<InvoiceEntity> get invoices => _invoices;
  bool get isLoading => _isLoading;
  String? get error => _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> fetchAllInvoices({int? month, int? year}) async {
    _setLoading(true);
    try {
      _invoices = await getAllInvoicesUseCase(month: month, year: year);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to fetch invoices: \$e';
      debugPrint(_errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addInvoice(InvoiceEntity invoice) async {
    _setLoading(true);
    try {
      await insertInvoiceUseCase(invoice);
      await fetchAllInvoices();
    } catch (e) {
      _errorMessage = 'Failed to add invoice: \$e';
      debugPrint(_errorMessage);
      _setLoading(false);
      rethrow;
    }
  }

  Future<void> updateInvoice(InvoiceEntity invoice) async {
    _setLoading(true);
    try {
      await updateInvoiceUseCase(invoice);
      await fetchAllInvoices();
    } catch (e) {
      _errorMessage = 'Failed to update invoice: \$e';
      debugPrint(_errorMessage);
      _setLoading(false);
      rethrow;
    }
  }

  Future<void> deleteInvoice(String id) async {
    _setLoading(true);
    try {
      await deleteInvoiceUseCase(id);
      await fetchAllInvoices();
    } catch (e) {
      _errorMessage = 'Failed to delete invoice: \$e';
      debugPrint(_errorMessage);
      _setLoading(false);
      rethrow;
    }
  }

  Future<String> generateInvoiceNumber() async {
    _setLoading(true);
    try {
      final number = await generateInvoiceNumberUseCase();
      _setLoading(false);
      return number;
    } catch (e) {
      _errorMessage = 'Failed to generate invoice number: \$e';
      debugPrint(_errorMessage);
      _setLoading(false);
      rethrow;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
