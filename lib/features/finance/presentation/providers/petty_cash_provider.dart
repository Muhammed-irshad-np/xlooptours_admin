import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/petty_cash_session_entity.dart';
import '../../domain/usecases/get_petty_cash_sessions_usecase.dart';
import '../../domain/usecases/get_open_session_usecase.dart';
import '../../domain/usecases/open_petty_cash_session_usecase.dart';
import '../../domain/usecases/close_petty_cash_session_usecase.dart';
import '../../domain/usecases/verify_petty_cash_session_usecase.dart';
import '../../domain/usecases/upload_closing_sheet_usecase.dart';

/// Provider managing the daily petty cash open/close workflow.
///
/// Handles opening sessions, recording closing balances,
/// admin verification, and session history.
class PettyCashProvider with ChangeNotifier {
  final GetPettyCashSessionsUseCase getPettyCashSessionsUseCase;
  final GetOpenSessionUseCase getOpenSessionUseCase;
  final OpenPettyCashSessionUseCase openPettyCashSessionUseCase;
  final ClosePettyCashSessionUseCase closePettyCashSessionUseCase;
  final VerifyPettyCashSessionUseCase verifyPettyCashSessionUseCase;
  final UploadClosingSheetUseCase uploadClosingSheetUseCase;

  PettyCashProvider({
    required this.getPettyCashSessionsUseCase,
    required this.getOpenSessionUseCase,
    required this.openPettyCashSessionUseCase,
    required this.closePettyCashSessionUseCase,
    required this.verifyPettyCashSessionUseCase,
    required this.uploadClosingSheetUseCase,
  });

  // ─── State ──────────────────────────────────────────────────

  List<PettyCashSessionEntity> _sessions = [];
  PettyCashSessionEntity? _currentSession;
  String? _selectedAccountId;
  bool _isLoading = false;
  String? _error;

  // ─── Getters ────────────────────────────────────────────────

  List<PettyCashSessionEntity> get sessions => _sessions;
  PettyCashSessionEntity? get currentSession => _currentSession;
  String? get selectedAccountId => _selectedAccountId;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Whether a session is currently open for the selected account.
  bool get hasOpenSession => _currentSession != null;

  /// Sessions that have been closed but not yet verified by admin.
  List<PettyCashSessionEntity> get unverifiedSessions => _sessions
      .where((s) => s.status == PettyCashSessionStatus.closed)
      .toList();

  /// Sessions with discrepancies (non-zero discrepancy).
  List<PettyCashSessionEntity> get sessionsWithDiscrepancies => _sessions
      .where((s) => s.discrepancy != null && s.discrepancy != 0)
      .toList();

  // ─── Operations ─────────────────────────────────────────────

  Future<void> loadSessions(String accountId) async {
    _selectedAccountId = accountId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _sessions = await getPettyCashSessionsUseCase(accountId);
      _currentSession = await getOpenSessionUseCase(accountId);
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
    } catch (e) {
      _error = e.toString();
      debugPrint('Error opening petty cash session: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> closeSession(PettyCashSessionEntity session) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Calculate discrepancy before saving.
      final discrepancy =
          session.closingBalance - session.expectedClosingBalance;
      final closedSession = session.copyWith(
        status: PettyCashSessionStatus.closed,
        discrepancy: discrepancy,
      );

      await closePettyCashSessionUseCase(closedSession);
      _currentSession = null;

      // Update the session in the list.
      final index = _sessions.indexWhere((s) => s.id == session.id);
      if (index != -1) {
        _sessions[index] = closedSession;
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error closing petty cash session: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> verifySession(String sessionId, String verifiedBy) async {
    _error = null;
    try {
      await verifyPettyCashSessionUseCase(sessionId, verifiedBy);
      final index = _sessions.indexWhere((s) => s.id == sessionId);
      if (index != -1) {
        _sessions[index] = _sessions[index].copyWith(
          status: PettyCashSessionStatus.verified,
          verifiedBy: verifiedBy,
          verifiedAt: DateTime.now(),
        );
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error verifying petty cash session: $e');
      notifyListeners();
    }
  }

  Future<String> uploadClosingSheet(XFile file, String sessionId) async {
    return await uploadClosingSheetUseCase(file, sessionId);
  }
}
