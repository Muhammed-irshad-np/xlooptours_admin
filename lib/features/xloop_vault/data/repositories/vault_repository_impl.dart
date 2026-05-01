import 'package:cross_file/cross_file.dart';
import '../../domain/entities/vault_data.dart';
import '../../domain/repositories/vault_repository.dart';
import '../datasources/vault_remote_data_source.dart';
import '../models/vault_data_model.dart';
import '../../../../core/error/failures.dart';

class VaultRepositoryImpl implements VaultRepository {
  final VaultRemoteDataSource remoteDataSource;

  VaultRepositoryImpl({required this.remoteDataSource});

  @override
  Future<VaultData> getVaultData() async {
    try {
      return await remoteDataSource.getVaultData();
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> updateVaultData(VaultData data) async {
    try {
      final model = VaultDataModel(
        license: CommercialLicenseModel(
          issueDate: data.license.issueDate,
          expiryDate: data.license.expiryDate,
          registrationNo: data.license.registrationNo,
          document: data.license.document != null
              ? VaultDocumentModel(
                  url: data.license.document!.url,
                  name: data.license.document!.name,
                )
              : null,
        ),
        vatCertificate: VatCertificateModel(
          issueDate: data.vatCertificate.issueDate,
          vatAccountNo: data.vatCertificate.vatAccountNo,
          document: data.vatCertificate.document != null
              ? VaultDocumentModel(
                  url: data.vatCertificate.document!.url,
                  name: data.vatCertificate.document!.name,
                )
              : null,
        ),
      );
      await remoteDataSource.updateVaultData(model);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<List<VatFiling>> getVatFilings() async {
    try {
      return await remoteDataSource.getVatFilings();
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> addVatFiling(VatFiling filing) async {
    try {
      final model = VatFilingModel(
        id: filing.id,
        date: filing.date,
        amount: filing.amount,
        currency: filing.currency,
        billNumber: filing.billNumber,
        fromDate: filing.fromDate,
        toDate: filing.toDate,
        documents: filing.documents
            .map((d) => VaultDocumentModel(url: d.url, name: d.name))
            .toList(),
      );
      await remoteDataSource.addVatFiling(model);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> updateVatFiling(VatFiling filing) async {
    try {
      final model = VatFilingModel(
        id: filing.id,
        date: filing.date,
        amount: filing.amount,
        currency: filing.currency,
        billNumber: filing.billNumber,
        fromDate: filing.fromDate,
        toDate: filing.toDate,
        documents: filing.documents
            .map((d) => VaultDocumentModel(url: d.url, name: d.name))
            .toList(),
      );
      await remoteDataSource.updateVatFiling(model);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> deleteVatFiling(String id) async {
    try {
      await remoteDataSource.deleteVatFiling(id);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<VaultDocument> uploadVaultDocument(XFile file, String path) async {
    try {
      return await remoteDataSource.uploadVaultDocument(file, path);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }


  @override
  Future<bool> verifyVaultPassword(String password) async {
    try {
      return await remoteDataSource.verifyVaultPassword(password);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}
