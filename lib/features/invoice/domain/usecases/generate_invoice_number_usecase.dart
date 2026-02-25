import '../repositories/invoice_repository.dart';

class GenerateInvoiceNumberUseCase {
  final InvoiceRepository repository;

  GenerateInvoiceNumberUseCase(this.repository);

  Future<String> call() async {
    return await repository.generateNewInvoiceNumber();
  }
}
