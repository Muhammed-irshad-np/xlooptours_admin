import '../entities/invoice_entity.dart';
import '../repositories/invoice_repository.dart';

class InsertInvoiceUseCase {
  final InvoiceRepository repository;

  InsertInvoiceUseCase(this.repository);

  Future<void> call(InvoiceEntity invoice) async {
    return await repository.insertInvoice(invoice);
  }
}
