import '../entities/invoice_entity.dart';
import '../repositories/invoice_repository.dart';

class GetAllInvoicesUseCase {
  final InvoiceRepository repository;

  GetAllInvoicesUseCase(this.repository);

  Future<List<InvoiceEntity>> call({int? month, int? year}) async {
    return await repository.getAllInvoices(month: month, year: year);
  }
}
