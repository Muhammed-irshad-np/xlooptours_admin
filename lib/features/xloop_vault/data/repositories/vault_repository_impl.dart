import 'dart:io';
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
          documentUrl: data.license.documentUrl,
        ),
        vatCertificate: VatCertificateModel(
          issueDate: data.vatCertificate.issueDate,
          expiryDate: data.vatCertificate.expiryDate,
          vatAccountNo: data.vatCertificate.vatAccountNo,
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
        fromDate: filing.fromDate,
        toDate: filing.toDate,
        documentUrls: filing.documentUrls,
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
        fromDate: filing.fromDate,
        toDate: filing.toDate,
        documentUrls: filing.documentUrls,
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
  Future<String> uploadVaultDocument(File file, String path) async {
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
