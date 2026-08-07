import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cross_file/cross_file.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/vault_data_model.dart';
import 'package:path/path.dart' as path;
import 'package:xloop_invoice/core/utils/file_upload_helper.dart';

abstract class VaultRemoteDataSource {
  Future<VaultDataModel> getVaultData();
  Future<void> updateVaultData(VaultDataModel data);
  Future<List<VatFilingModel>> getVatFilings();
  Future<void> addVatFiling(VatFilingModel filing);
  Future<void> updateVatFiling(VatFilingModel filing);
  Future<void> deleteVatFiling(String id);
  Future<VaultDocumentModel> uploadVaultDocument(XFile file, String folderPath);
  Future<bool> verifyVaultPassword(String passwordHash);
}

class VaultRemoteDataSourceImpl implements VaultRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;

  VaultRemoteDataSourceImpl({required this.firestore, required this.storage});

  @override
  Future<VaultDataModel> getVaultData() async {
    final doc = await firestore
        .collection('xloop_company')
        .doc('details')
        .get();
    if (doc.exists && doc.data() != null) {
      return VaultDataModel.fromJson(doc.data()!);
    }
    return const VaultDataModel(
      license: CommercialLicenseModel(),
      vatCertificate: VatCertificateModel(),
    );
  }

  @override
  Future<void> updateVaultData(VaultDataModel data) async {
    await firestore
        .collection('xloop_company')
        .doc('details')
        .set(data.toJson(), SetOptions(merge: true));
  }

  @override
  Future<List<VatFilingModel>> getVatFilings() async {
    final snapshot = await firestore
        .collection('vat_filings')
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => VatFilingModel.fromJson(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<void> addVatFiling(VatFilingModel filing) async {
    final docRef = firestore.collection('vat_filings').doc();
    final data = filing.toJson();
    await docRef.set(data);
  }

  @override
  Future<void> updateVatFiling(VatFilingModel filing) async {
    await firestore
        .collection('vat_filings')
        .doc(filing.id)
        .update(filing.toJson());
  }

  @override
  Future<void> deleteVatFiling(String id) async {
    await firestore.collection('vat_filings').doc(id).delete();
  }

  @override
  Future<VaultDocumentModel> uploadVaultDocument(XFile file, String folderPath) async {
    // Read bytes first so we can detect the true file type via magic bytes.
    final bytes = await file.readAsBytes();
    final info = FileUploadHelper.getUploadInfo(bytes, file.name);

    // Build a storage filename that always carries the correct extension.
    final nameWithoutExt = path.basenameWithoutExtension(file.name).isNotEmpty
        ? path.basenameWithoutExtension(file.name)
        : '${DateTime.now().millisecondsSinceEpoch}';
    final fileName = '${nameWithoutExt}_${DateTime.now().millisecondsSinceEpoch}${info.extension}';
    final ref = storage.ref().child('vault/$folderPath/$fileName');

    // Use putData to avoid platform-specific "unsupported file _namespace"
    // errors that occur on iOS/macOS when using putFile with security-scoped paths.
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: info.mimeType,
        customMetadata: {'originalName': file.name},
      ),
    );
    final url = await ref.getDownloadURL();
    return VaultDocumentModel(url: url, name: file.name);
  }

  @override
  Future<bool> verifyVaultPassword(String passwordHash) async {
    final doc = await firestore
        .collection('xloop_company')
        .doc('security')
        .get();
    if (doc.exists && doc.data() != null) {
      final storedHash = doc.data()!['vaultPasswordHash'] as String?;
      if (storedHash != null) {
        return storedHash == passwordHash;
      }
    }

    // Fallback or initialization handling.
    // If we're setting it up initially, we can just return true for the hardcoded hash temporarily,
    // or we could enforce creating it. Let's return true for the specific hash if it's missing
    // in order to avoid locking out the admin before they set it up in Firestore.
    if (passwordHash ==
        '390b17d411fd12a956206fb5cfed80335bb0db9dc4666917cbd168f59b721b75') {
      return true;
    }

    return false;
  }
}
