import 'package:cross_file/cross_file.dart';
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

  // ── Cache timestamps ───────────────────────────────────────────────────────
  DateTime? _vaultDataLastFetch;
  DateTime? _vatFilingsLastFetch;
  static const _cacheDuration = Duration(minutes: 5);

  /// Invalidates all cached data, forcing fresh fetches on next access.
  void invalidateCache() {
    _vaultDataLastFetch = null;
    _vatFilingsLastFetch = null;
  }

  Future<void> loadVaultData({bool forceRefresh = false}) async {
    if (!forceRefresh && _vaultDataLastFetch != null && _vaultData != null &&
        DateTime.now().difference(_vaultDataLastFetch!) < _cacheDuration) {
      return;
    }
    _setLoading(true);
    try {
      _vaultData = await getVaultDataUseCase();
      _vaultDataLastFetch = DateTime.now();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    }
    _setLoading(false);
  }

  Future<void> loadVatFilings({bool forceRefresh = false}) async {
    if (!forceRefresh && _vatFilingsLastFetch != null && _vatFilings.isNotEmpty &&
        DateTime.now().difference(_vatFilingsLastFetch!) < _cacheDuration) {
      return;
    }
    _setLoading(true);
    try {
      _vatFilings = await getVatFilingsUseCase();
      _vatFilingsLastFetch = DateTime.now();
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
      // Optimistic local update instead of re-fetching
      _vatFilings.add(filing);
      _errorMessage = null;
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
      // Optimistic local update instead of re-fetching
      final index = _vatFilings.indexWhere((f) => f.id == filing.id);
      if (index != -1) {
        _vatFilings[index] = filing;
      }
      _errorMessage = null;
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
      // Optimistic local update instead of re-fetching
      _vatFilings.removeWhere((f) => f.id == id);
      _errorMessage = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<VaultDocument?> uploadDocument(XFile file, String folderPath) async {
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
