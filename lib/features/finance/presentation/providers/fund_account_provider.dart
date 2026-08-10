import 'package:flutter/foundation.dart';
import '../../domain/entities/fund_account_entity.dart';
import '../../domain/entities/fund_transaction_entity.dart';
import '../../domain/usecases/get_all_fund_accounts_usecase.dart';
import '../../domain/usecases/insert_fund_account_usecase.dart';
import '../../domain/usecases/update_fund_account_usecase.dart';
import '../../domain/usecases/delete_fund_account_usecase.dart';
import '../../domain/usecases/get_transactions_usecase.dart';
import '../../domain/usecases/insert_transaction_usecase.dart';

/// Provider managing fund accounts and their transactions.
///
/// Handles account CRUD, balance display, deposit/withdrawal
/// recording, and transaction history.
class FundAccountProvider with ChangeNotifier {
  final GetAllFundAccountsUseCase getAllFundAccountsUseCase;
  final InsertFundAccountUseCase insertFundAccountUseCase;
  final UpdateFundAccountUseCase updateFundAccountUseCase;
  final DeleteFundAccountUseCase deleteFundAccountUseCase;
  final GetTransactionsUseCase getTransactionsUseCase;
  final InsertTransactionUseCase insertTransactionUseCase;

  FundAccountProvider({
    required this.getAllFundAccountsUseCase,
    required this.insertFundAccountUseCase,
    required this.updateFundAccountUseCase,
    required this.deleteFundAccountUseCase,
    required this.getTransactionsUseCase,
    required this.insertTransactionUseCase,
  });

  // ─── State ──────────────────────────────────────────────────

  List<FundAccountEntity> _accounts = [];
  List<FundTransactionEntity> _transactions = [];
  String? _selectedAccountId;
  bool _isLoading = false;
  bool _isTransactionsLoading = false;
  String? _error;

  // ─── Getters ────────────────────────────────────────────────

  List<FundAccountEntity> get accounts => _accounts;
  List<FundAccountEntity> get activeAccounts =>
      _accounts.where((a) => a.isActive).toList();
  List<FundTransactionEntity> get transactions => _transactions;
  String? get selectedAccountId => _selectedAccountId;
  bool get isLoading => _isLoading;
  bool get isTransactionsLoading => _isTransactionsLoading;
  String? get error => _error;

  /// Returns the currently selected account entity.
  FundAccountEntity? get selectedAccount {
    if (_selectedAccountId == null) return null;
    try {
      return _accounts.firstWhere((a) => a.id == _selectedAccountId);
    } catch (_) {
      return null;
    }
  }

  /// Total balance across all active accounts (SAR only for simplicity).
  double get totalBalance =>
      activeAccounts.fold(0.0, (sum, a) => sum + a.currentBalance);

  // ─── Account Operations ─────────────────────────────────────

  Future<void> fetchAllAccounts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _accounts = await getAllFundAccountsUseCase();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error fetching fund accounts: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> insertAccount(FundAccountEntity account) async {
    _error = null;
    try {
      await insertFundAccountUseCase(account);
      _accounts.add(account);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error inserting fund account: $e');
      notifyListeners();
    }
  }

  Future<void> updateAccount(FundAccountEntity account) async {
    _error = null;
    try {
      await updateFundAccountUseCase(account);
      final index = _accounts.indexWhere((a) => a.id == account.id);
      if (index != -1) {
        _accounts[index] = account;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error updating fund account: $e');
      notifyListeners();
    }
  }

  Future<void> deleteAccount(String id) async {
    _error = null;
    try {
      await deleteFundAccountUseCase(id);
      _accounts.removeWhere((a) => a.id == id);
      if (_selectedAccountId == id) {
        _selectedAccountId = null;
        _transactions = [];
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error deleting fund account: $e');
      notifyListeners();
    }
  }

  // ─── Transaction Operations ─────────────────────────────────

  void selectAccount(String? accountId) {
    _selectedAccountId = accountId;
    if (accountId != null) {
      fetchTransactions(accountId);
    } else {
      _transactions = [];
      notifyListeners();
    }
  }

  Future<void> fetchTransactions(String accountId) async {
    _isTransactionsLoading = true;
    _error = null;
    notifyListeners();

    try {
      _transactions = await getTransactionsUseCase(accountId);
    } catch (e) {
      _error = e.toString();
      debugPrint('Error fetching transactions: $e');
    } finally {
      _isTransactionsLoading = false;
      notifyListeners();
    }
  }

  Future<void> recordTransaction(FundTransactionEntity transaction) async {
    _error = null;
    try {
      await insertTransactionUseCase(transaction);
      _transactions.insert(0, transaction);

      // Update the local account balance.
      final index =
          _accounts.indexWhere((a) => a.id == transaction.fundAccountId);
      if (index != -1) {
        _accounts[index] = _accounts[index].copyWith(
          currentBalance: transaction.balanceAfter,
        );
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error recording transaction: $e');
      notifyListeners();
    }
  }

  /// Helper to find an account by ID.
  FundAccountEntity? getAccountById(String id) {
    try {
      return _accounts.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }
}
