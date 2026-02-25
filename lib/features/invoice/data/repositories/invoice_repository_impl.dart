import '../../domain/entities/invoice_entity.dart';
import '../../domain/repositories/invoice_repository.dart';
import '../datasources/invoice_remote_data_source.dart';
import '../models/invoice_model.dart';

class InvoiceRepositoryImpl implements InvoiceRepository {
  final InvoiceRemoteDataSource remoteDataSource;

  InvoiceRepositoryImpl({required this.remoteDataSource});

  @override
  Future<void> insertInvoice(InvoiceEntity invoice) async {
    final invoiceModel = InvoiceModel.fromEntity(invoice);
    await remoteDataSource.insertInvoice(invoiceModel);
  }

  @override
  Future<List<InvoiceEntity>> getAllInvoices({int? month, int? year}) async {
    return await remoteDataSource.getAllInvoices(month: month, year: year);
  }

  @override
  Future<void> updateInvoice(InvoiceEntity invoice) async {
    final invoiceModel = InvoiceModel.fromEntity(invoice);
    await remoteDataSource.updateInvoice(invoiceModel);
  }

  @override
  Future<void> deleteInvoice(String id) async {
    await remoteDataSource.deleteInvoice(id);
  }

  @override
  Future<String> generateNewInvoiceNumber() async {
    return await remoteDataSource.generateNewInvoiceNumber();
  }
}
