import '../entities/invoice_entity.dart';

abstract class InvoiceRepository {
  Future<void> insertInvoice(InvoiceEntity invoice);
  Future<List<InvoiceEntity>> getAllInvoices({int? month, int? year});
  Future<void> updateInvoice(InvoiceEntity invoice);
  Future<void> deleteInvoice(String id);
  Future<String> generateNewInvoiceNumber();
}
