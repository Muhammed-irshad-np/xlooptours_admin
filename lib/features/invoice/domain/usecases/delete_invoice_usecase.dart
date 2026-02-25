import '../repositories/invoice_repository.dart';

class DeleteInvoiceUseCase {
  final InvoiceRepository repository;

  DeleteInvoiceUseCase(this.repository);

  Future<void> call(String id) async {
    return await repository.deleteInvoice(id);
  }
}
