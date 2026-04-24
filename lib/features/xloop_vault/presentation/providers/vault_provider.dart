import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../domain/entities/vault_data.dart';
import '../../domain/usecases/vault_usecases.dart';

class VaultProvider extends ChangeNotifier {
  final GetVaultDataUseCase getVaultDataUseCase;
  final UpdateVaultDataUseCase updateVaultDataUseCase;
  final GetVatFilingsUseCase getVatFilingsUseCase;
  final AddVatFilingUseCase addVatFilingUseCase;
  final UpdateVatFilingUseCase updateVatFilingUseCase;
  final DeleteVatFilingUseCase deleteVatFilingUseCase;
  final UploadVaultDocumentUseCase uploadVaultDocumentUseCase;
  final VerifyVaultPasswordUseCase verifyVaultPasswordUseCase;

  VaultProvider({
    required this.getVaultDataUseCase,
    required this.updateVaultDataUseCase,
    required this.getVatFilingsUseCase,
    required this.addVatFilingUseCase,
    required this.updateVatFilingUseCase,
    required this.deleteVatFilingUseCase,
    required this.uploadVaultDocumentUseCase,
    required this.verifyVaultPasswordUseCase,
  });

  VaultData? _vaultData;
  VaultData? get vaultData => _vaultData;

  List<VatFiling> _vatFilings = [];
  List<VatFiling> get vatFilings => _vatFilings;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> loadVaultData() async {
    _setLoading(true);
    try {
      _vaultData = await getVaultDataUseCase();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    }
    _setLoading(false);
  }

  Future<void> loadVatFilings() async {
    _setLoading(true);
    try {
      _vatFilings = await getVatFilingsUseCase();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    }
    _setLoading(false);
  }

  Future<bool> updateVaultData(VaultData data) async {
    _setLoading(true);
    try {
      await updateVaultDataUseCase(data);
      _vaultData = data;
      _errorMessage = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> addVatFiling(VatFiling filing) async {
    _setLoading(true);
    try {
      await addVatFilingUseCase(filing);
      // Refresh list
      await loadVatFilings();
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateVatFiling(VatFiling filing) async {
    _setLoading(true);
    try {
      await updateVatFilingUseCase(filing);
      // Refresh list
      await loadVatFilings();
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> deleteVatFiling(String id) async {
    _setLoading(true);
    try {
      await deleteVatFilingUseCase(id);
      // Refresh list
      await loadVatFilings();
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<String?> uploadDocument(File file, String folderPath) async {
    try {
      return await uploadVaultDocumentUseCase(file, folderPath);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> verifyPassword(String passwordHash) async {
    _setLoading(true);
    try {
      final isValid = await verifyVaultPasswordUseCase(passwordHash);
      _errorMessage = null;
      _setLoading(false);
      return isValid;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
