import 'package:flutter/foundation.dart';
import '../../domain/entities/cash_advance_entity.dart';
import '../../domain/usecases/cash_advance_usecases.dart';

class CashAdvanceProvider with ChangeNotifier {
  final GetCashAdvancesUseCase getCashAdvancesUseCase;
  final IssueCashAdvanceUseCase issueCashAdvanceUseCase;
  final SettleCashAdvanceUseCase settleCashAdvanceUseCase;
  final WriteOffCashAdvanceUseCase writeOffCashAdvanceUseCase;

  CashAdvanceProvider({
    required this.getCashAdvancesUseCase,
    required this.issueCashAdvanceUseCase,
    required this.settleCashAdvanceUseCase,
    required this.writeOffCashAdvanceUseCase,
  });

  List<CashAdvanceEntity> _advances = [];
  bool _isLoading = false;
  String? _error;

  List<CashAdvanceEntity> get advances => _advances;
  List<CashAdvanceEntity> get openAdvances =>
      _advances.where((a) => a.isOpen).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load({String? fundAccountId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _advances =
          await getCashAdvancesUseCase(fundAccountId: fundAccountId);
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading advances: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> issue(CashAdvanceEntity advance) async {
    _error = null;
    try {
      final saved = await issueCashAdvanceUseCase(advance);
      _advances = [saved, ..._advances];
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> settle({
    required String advanceId,
    required double amount,
    required String actorName,
    required String actorUserId,
    bool returnToFund = true,
  }) async {
    _error = null;
    try {
      final updated = await settleCashAdvanceUseCase(
        advanceId: advanceId,
        settleAmountMajor: amount,
        actorName: actorName,
        actorUserId: actorUserId,
        returnToFund: returnToFund,
      );
      final i = _advances.indexWhere((a) => a.id == advanceId);
      if (i != -1) _advances[i] = updated;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> writeOff({
    required String advanceId,
    required String reason,
    required String actorName,
    required String actorUserId,
  }) async {
    _error = null;
    try {
      final updated = await writeOffCashAdvanceUseCase(
        advanceId: advanceId,
        reason: reason,
        actorName: actorName,
        actorUserId: actorUserId,
      );
      final i = _advances.indexWhere((a) => a.id == advanceId);
      if (i != -1) _advances[i] = updated;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}
