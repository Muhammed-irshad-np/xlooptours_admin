import '../entities/vault_data.dart';
import 'dart:io';

abstract class VaultRepository {
  Future<VaultData> getVaultData();
  Future<void> updateVaultData(VaultData data);
  Future<List<VatFiling>> getVatFilings();
  Future<void> addVatFiling(VatFiling filing);
  Future<void> updateVatFiling(VatFiling filing);
  Future<void> deleteVatFiling(String id);
  Future<String> uploadVaultDocument(File file, String path);
  Future<bool> verifyVaultPassword(String password);
}
