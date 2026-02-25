import '../entities/invoice_entity.dart';
import '../repositories/invoice_repository.dart';

class UpdateInvoiceUseCase {
  final InvoiceRepository repository;

  UpdateInvoiceUseCase(this.repository);

  Future<void> call(InvoiceEntity invoice) async {
    return await repository.updateInvoice(invoice);
  }
}
