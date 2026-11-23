import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/ledger_day_totals.dart';
import '../../domain/entities/petty_cash_session_entity.dart';
import '../../domain/entities/session_expense_item.dart';
import '../../domain/repositories/finance_repository.dart';
import '../../domain/usecases/get_petty_cash_sessions_usecase.dart';
import '../../domain/usecases/get_open_session_usecase.dart';
import '../../domain/usecases/open_petty_cash_session_usecase.dart';
import '../../domain/usecases/close_petty_cash_session_usecase.dart';
import '../../domain/usecases/verify_petty_cash_session_usecase.dart';
import '../../domain/usecases/upload_closing_sheet_usecase.dart';
import '../../domain/usecases/get_session_expenses_usecase.dart';
import '../../domain/usecases/transfer_bucket_usecase.dart';
import '../../domain/entities/fund_transaction_entity.dart';
import '../../domain/entities/fund_account_entity.dart';
import '../../domain/entities/expense_entity.dart';
import '../../domain/entities/petty_cash_close_request.dart';

class PettyCashProvider with ChangeNotifier {
  final GetPettyCashSessionsUseCase getPettyCashSessionsUseCase;
  final GetOpenSessionUseCase getOpenSessionUseCase;
  final OpenPettyCashSessionUseCase openPettyCashSessionUseCase;
  final ClosePettyCashSessionUseCase closePettyCashSessionUseCase;
  final VerifyPettyCashSessionUseCase verifyPettyCashSessionUseCase;
  final UploadClosingSheetUseCase uploadClosingSheetUseCase;
  final GetSessionExpensesUseCase getSessionExpensesUseCase;
  final TransferBucketUseCase transferBucketUseCase;
  final FinanceRepository financeRepository;

  PettyCashProvider({
    required this.getPettyCashSessionsUseCase,
    required this.getOpenSessionUseCase,
    required this.openPettyCashSessionUseCase,
    required this.closePettyCashSessionUseCase,
    required this.verifyPettyCashSessionUseCase,
    required this.uploadClosingSheetUseCase,
    required this.getSessionExpensesUseCase,
    required this.transferBucketUseCase,
    required this.financeRepository,
  });

  List<PettyCashSessionEntity> _sessions = [];
  PettyCashSessionEntity? _currentSession;
  String? _selectedAccountId;
  bool _isLoading = false;
  String? _error;
  LedgerDayTotals? _previewTotals;
  FundAccountEntity? _liveAccount;

  List<PettyCashSessionEntity> get sessions => _sessions;
  PettyCashSessionEntity? get currentSession => _currentSession;
  String? get selectedAccountId => _selectedAccountId;
  bool get isLoading => _isLoading;
  String? get error => _error;
  LedgerDayTotals? get previewTotals => _previewTotals;
  bool get hasOpenSession => _currentSession != null;

  /// The selected account as last read from the server. Its Cash and STC
  /// Pay balances are what the open register is expected to hold.
  FundAccountEntity? get liveAccount => _liveAccount;

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
      _liveAccount = await financeRepository.getFundAccountById(accountId);
      if (_currentSession != null) {
        _previewTotals = await financeRepository.getLedgerDayTotals(
          accountId,
          _currentSession!.date,
          sessionOpenedAt: _currentSession!.createdAt,
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
      _currentSession =
          await getOpenSessionUseCase(session.fundAccountId) ?? session;
      _sessions = await getPettyCashSessionsUseCase(session.fundAccountId);
      _previewTotals = await financeRepository.getLedgerDayTotals(
        session.fundAccountId,
        session.date,
        sessionOpenedAt: _currentSession?.createdAt ?? session.createdAt,
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

  /// Closes the open register. On success the sessions and the live
  /// account are reloaded, so the page shows the server's figures.
  Future<PettyCashSessionEntity> closeSession(
      PettyCashCloseRequest request) async {
    _error = null;
    try {
      final closed = await closePettyCashSessionUseCase(request);
      await loadSessions(closed.fundAccountId);
      return closed;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error closing petty cash session: $e');
      rethrow;
    }
  }

  Future<void> verifySession({
    required String sessionId,
    required String verifiedBy,
    required String? verifiedByUserId,
    String? resolutionNotes,
    PettyCashResolution? resolution,
  }) async {
    _error = null;
    try {
      await verifyPettyCashSessionUseCase(
        sessionId: sessionId,
        verifiedBy: verifiedBy,
        verifiedByUserId: verifiedByUserId,
        resolutionNotes: resolutionNotes,
        resolution: resolution,
      );
      final accountId = _selectedAccountId;
      if (accountId != null) {
        await loadSessions(accountId);
      } else {
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error verifying petty cash session: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Reads the account fresh from the server (for the closing count).
  Future<FundAccountEntity> fetchLiveAccount(String accountId) async {
    final account = await financeRepository.getFundAccountById(accountId);
    if (accountId == _selectedAccountId) {
      _liveAccount = account;
      notifyListeners();
    }
    return account;
  }

  /// Expenses on [accountId] not yet paid from the account (draft, pending
  /// or approved-but-unpaid). Cash already handed out for these is not in
  /// the ledger yet, so it makes the drawer look short.
  Future<List<ExpenseEntity>> getUnpostedExpenses(String accountId) async {
    final all = await financeRepository.getExpensesByAccount(accountId);
    return all
        .where((e) =>
            !e.isNonWallet &&
            (e.status == ExpenseStatus.draft ||
                e.status == ExpenseStatus.pending ||
                e.status == ExpenseStatus.approved))
        .toList();
  }

  Future<String> uploadClosingSheet(XFile file, String sessionId) async {
    return await uploadClosingSheetUseCase(file, sessionId);
  }

  /// Transfers money between Cash and STC Pay buckets within the same
  /// fund account. After a successful transfer, refreshes the day totals
  /// so the closing form picks up the updated expected balances.
  Future<void> transferBucket({
    required String fundAccountId,
    required double amountMajor,
    required FundBucket fromBucket,
    required FundBucket toBucket,
    required String performedBy,
    required String? performedByUserId,
  }) async {
    await transferBucketUseCase(
      fundAccountId: fundAccountId,
      amountMajor: amountMajor,
      fromBucket: fromBucket,
      toBucket: toBucket,
      performedBy: performedBy,
      performedByUserId: performedByUserId,
    );
    // Refresh day totals so expected closing values update
    await refreshDayTotals();
  }

  Future<void> refreshDayTotals() async {
    if (_currentSession == null) return;
    _previewTotals = await financeRepository.getLedgerDayTotals(
      _currentSession!.fundAccountId,
      _currentSession!.date,
      sessionOpenedAt: _currentSession!.createdAt,
    );
    _liveAccount = await financeRepository
        .getFundAccountById(_currentSession!.fundAccountId);
    notifyListeners();
  }

  /// Fetches all expense records and ledger outflows that occurred during
  /// a specific petty cash session.
  Future<List<SessionExpenseItem>> getSessionExpenses(
    PettyCashSessionEntity session,
  ) async {
    return await getSessionExpensesUseCase(session);
  }
}
