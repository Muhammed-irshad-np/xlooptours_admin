import 'dart:io';
import '../entities/vault_data.dart';
import '../repositories/vault_repository.dart';

class GetVaultDataUseCase {
  final VaultRepository repository;
  GetVaultDataUseCase(this.repository);
  Future<VaultData> call() => repository.getVaultData();
}

class UpdateVaultDataUseCase {
  final VaultRepository repository;
  UpdateVaultDataUseCase(this.repository);
  Future<void> call(VaultData data) => repository.updateVaultData(data);
}

class GetVatFilingsUseCase {
  final VaultRepository repository;
  GetVatFilingsUseCase(this.repository);
  Future<List<VatFiling>> call() => repository.getVatFilings();
}

class AddVatFilingUseCase {
  final VaultRepository repository;
  AddVatFilingUseCase(this.repository);
  Future<void> call(VatFiling filing) => repository.addVatFiling(filing);
}

class UpdateVatFilingUseCase {
  final VaultRepository repository;
  UpdateVatFilingUseCase(this.repository);
  Future<void> call(VatFiling filing) => repository.updateVatFiling(filing);
}

class DeleteVatFilingUseCase {
  final VaultRepository repository;
  DeleteVatFilingUseCase(this.repository);
  Future<void> call(String id) => repository.deleteVatFiling(id);
}

class UploadVaultDocumentUseCase {
  final VaultRepository repository;
  UploadVaultDocumentUseCase(this.repository);
  Future<String> call(File file, String path) => repository.uploadVaultDocument(file, path);
}

class VerifyVaultPasswordUseCase {
  final VaultRepository repository;
  VerifyVaultPasswordUseCase(this.repository);
  Future<bool> call(String password) => repository.verifyVaultPassword(password);
}
