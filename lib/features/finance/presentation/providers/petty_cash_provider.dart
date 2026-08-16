import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/ledger_day_totals.dart';
import '../../domain/entities/petty_cash_session_entity.dart';
import '../../domain/repositories/finance_repository.dart';
import '../../domain/usecases/get_petty_cash_sessions_usecase.dart';
import '../../domain/usecases/get_open_session_usecase.dart';
import '../../domain/usecases/open_petty_cash_session_usecase.dart';
import '../../domain/usecases/close_petty_cash_session_usecase.dart';
import '../../domain/usecases/verify_petty_cash_session_usecase.dart';
import '../../domain/usecases/upload_closing_sheet_usecase.dart';

class PettyCashProvider with ChangeNotifier {
  final GetPettyCashSessionsUseCase getPettyCashSessionsUseCase;
  final GetOpenSessionUseCase getOpenSessionUseCase;
  final OpenPettyCashSessionUseCase openPettyCashSessionUseCase;
  final ClosePettyCashSessionUseCase closePettyCashSessionUseCase;
  final VerifyPettyCashSessionUseCase verifyPettyCashSessionUseCase;
  final UploadClosingSheetUseCase uploadClosingSheetUseCase;
  final FinanceRepository financeRepository;

  PettyCashProvider({
    required this.getPettyCashSessionsUseCase,
    required this.getOpenSessionUseCase,
    required this.openPettyCashSessionUseCase,
    required this.closePettyCashSessionUseCase,
    required this.verifyPettyCashSessionUseCase,
    required this.uploadClosingSheetUseCase,
    required this.financeRepository,
  });

  List<PettyCashSessionEntity> _sessions = [];
  PettyCashSessionEntity? _currentSession;
  String? _selectedAccountId;
  bool _isLoading = false;
  String? _error;
  LedgerDayTotals? _previewTotals;

  List<PettyCashSessionEntity> get sessions => _sessions;
  PettyCashSessionEntity? get currentSession => _currentSession;
  String? get selectedAccountId => _selectedAccountId;
  bool get isLoading => _isLoading;
  String? get error => _error;
  LedgerDayTotals? get previewTotals => _previewTotals;
  bool get hasOpenSession => _currentSession != null;

  List<PettyCashSessionEntity> get unverifiedSessions => _sessions
      .where((s) => s.status == PettyCashSessionStatus.closed)
      .toList();

  Future<void> loadSessions(String accountId) async {
    _selectedAccountId = accountId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _sessions = await getPettyCashSessionsUseCase(accountId);
      _currentSession = await getOpenSessionUseCase(accountId);
      if (_currentSession != null) {
        _previewTotals = await financeRepository.getLedgerDayTotals(
          accountId,
          _currentSession!.date,
        );
      } else {
        _previewTotals = null;
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading petty cash sessions: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> openSession(PettyCashSessionEntity session) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await openPettyCashSessionUseCase(session);
      _currentSession = session;
      _sessions.insert(0, session);
      _previewTotals = await financeRepository.getLedgerDayTotals(
        session.fundAccountId,
        session.date,
      );
    } catch (e) {
      _error = e.toString();
      debugPrint('Error opening petty cash session: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> closeSession({
    required PettyCashSessionEntity session,
    required String closedBy,
    required String? closedByUserId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final closed = await closePettyCashSessionUseCase(
        session: session,
        closedBy: closedBy,
        closedByUserId: closedByUserId,
      );
      _currentSession = null;
      _previewTotals = null;
      final index = _sessions.indexWhere((s) => s.id == session.id);
      if (index != -1) {
        _sessions[index] = closed;
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error closing petty cash session: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> verifySession({
    required String sessionId,
    required String verifiedBy,
    required String? verifiedByUserId,
  }) async {
    _error = null;
    try {
      await verifyPettyCashSessionUseCase(
        sessionId: sessionId,
        verifiedBy: verifiedBy,
        verifiedByUserId: verifiedByUserId,
      );
      final index = _sessions.indexWhere((s) => s.id == sessionId);
      if (index != -1) {
        _sessions[index] = _sessions[index].copyWith(
          status: PettyCashSessionStatus.verified,
          verifiedBy: verifiedBy,
          verifiedAt: DateTime.now(),
        );
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error verifying petty cash session: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<String> uploadClosingSheet(XFile file, String sessionId) async {
    return await uploadClosingSheetUseCase(file, sessionId);
  }

  Future<void> refreshDayTotals() async {
    if (_currentSession == null) return;
    _previewTotals = await financeRepository.getLedgerDayTotals(
      _currentSession!.fundAccountId,
      _currentSession!.date,
    );
    notifyListeners();
  }
}
