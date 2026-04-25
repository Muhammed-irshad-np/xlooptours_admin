import '../entities/vault_data.dart';
import 'package:cross_file/cross_file.dart';

abstract class VaultRepository {
  Future<VaultData> getVaultData();
  Future<void> updateVaultData(VaultData data);
  Future<List<VatFiling>> getVatFilings();
  Future<void> addVatFiling(VatFiling filing);
  Future<void> updateVatFiling(VatFiling filing);
  Future<void> deleteVatFiling(String id);
  Future<String> uploadVaultDocument(XFile file, String path);
  Future<bool> verifyVaultPassword(String password);
}
