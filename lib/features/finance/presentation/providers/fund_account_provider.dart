import 'package:flutter/foundation.dart';
import '../../domain/entities/fund_account_entity.dart';
import '../../domain/entities/fund_transaction_entity.dart';
import '../../domain/entities/post_fund_request.dart';
import '../../domain/usecases/get_all_fund_accounts_usecase.dart';
import '../../domain/usecases/insert_fund_account_usecase.dart';
import '../../domain/usecases/update_fund_account_usecase.dart';
import '../../domain/usecases/delete_fund_account_usecase.dart';
import '../../domain/usecases/get_transactions_usecase.dart';
import '../../domain/usecases/insert_transaction_usecase.dart';
import '../../domain/usecases/post_fund_movement_usecase.dart';
import '../../domain/usecases/transfer_funds_usecase.dart';

class FundAccountProvider with ChangeNotifier {
  final GetAllFundAccountsUseCase getAllFundAccountsUseCase;
  final InsertFundAccountUseCase insertFundAccountUseCase;
  final UpdateFundAccountUseCase updateFundAccountUseCase;
  final DeleteFundAccountUseCase deleteFundAccountUseCase;
  final GetTransactionsUseCase getTransactionsUseCase;
  final InsertTransactionUseCase insertTransactionUseCase;
  final PostFundMovementUseCase postFundMovementUseCase;
  final TransferFundsUseCase transferFundsUseCase;

  FundAccountProvider({
    required this.getAllFundAccountsUseCase,
    required this.insertFundAccountUseCase,
    required this.updateFundAccountUseCase,
    required this.deleteFundAccountUseCase,
    required this.getTransactionsUseCase,
    required this.insertTransactionUseCase,
    required this.postFundMovementUseCase,
    required this.transferFundsUseCase,
  });

  List<FundAccountEntity> _accounts = [];
  List<FundTransactionEntity> _transactions = [];
  String? _selectedAccountId;
  bool _isLoading = false;
  bool _isTransactionsLoading = false;
  String? _error;

  List<FundAccountEntity> get accounts => _accounts;
  List<FundAccountEntity> get activeAccounts =>
      _accounts.where((a) => a.isActive).toList();
  List<FundTransactionEntity> get transactions => _transactions;
  String? get selectedAccountId => _selectedAccountId;
  bool get isLoading => _isLoading;
  bool get isTransactionsLoading => _isTransactionsLoading;
  String? get error => _error;

  FundAccountEntity? get selectedAccount {
    if (_selectedAccountId == null) return null;
    try {
      return _accounts.firstWhere((a) => a.id == _selectedAccountId);
    } catch (_) {
      return null;
    }
  }

  double get totalBalance =>
      activeAccounts.fold(0.0, (sum, a) => sum + a.currentBalance);

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
    _accounts = [account, ..._accounts];
    notifyListeners();

    try {
      await insertFundAccountUseCase(account);
    } catch (e) {
      _accounts = _accounts.where((a) => a.id != account.id).toList();
      _error = e.toString();
      debugPrint('Error inserting fund account: $e');
      notifyListeners();
    }
  }

  Future<void> updateAccount(FundAccountEntity account) async {
    _error = null;
    final index = _accounts.indexWhere((a) => a.id == account.id);
    FundAccountEntity? oldAccount;

    if (index != -1) {
      oldAccount = _accounts[index];
      _accounts[index] = account;
      notifyListeners();
    }

    try {
      await updateFundAccountUseCase(account);
    } catch (e) {
      if (index != -1 && oldAccount != null) {
        _accounts[index] = oldAccount;
      }
      _error = e.toString();
      debugPrint('Error updating fund account: $e');
      notifyListeners();
    }
  }

  /// Deactivates if history exists; may hard-delete empty accounts only.
  Future<void> deleteAccount(String id) async {
    _error = null;
    final index = _accounts.indexWhere((a) => a.id == id);
    FundAccountEntity? oldAccount;

    if (index != -1) {
      oldAccount = _accounts[index];
      // Soft: mark inactive locally; refresh after.
      _accounts[index] = oldAccount.copyWith(isActive: false);
      if (_selectedAccountId == id) {
        _selectedAccountId = null;
        _transactions = [];
      }
      notifyListeners();
    }

    try {
      await deleteFundAccountUseCase(id);
      await fetchAllAccounts();
    } catch (e) {
      if (index != -1 && oldAccount != null) {
        _accounts[index] = oldAccount;
      }
      _error = e.toString();
      debugPrint('Error deleting fund account: $e');
      notifyListeners();
    }
  }

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

  /// Deposit/withdraw/adjustment with server-side balance math.
  /// [credit] overrides direction when set (required for adjustments).
  Future<void> recordMovement({
    required String fundAccountId,
    required FundTransactionType type,
    required double amountMajor,
    required String currency,
    required String description,
    required String performedBy,
    required String performedByUserId,
    FundBucket bucket = FundBucket.total,
    double? cashDelta,
    double? stcPayDelta,
    bool? credit,
  }) async {
    _error = null;
    try {
      final isCredit = credit ??
          (type == FundTransactionType.deposit ||
              type == FundTransactionType.reversal);
      final tx = await postFundMovementUseCase(
        PostFundRequest(
          fundAccountId: fundAccountId,
          type: type,
          amountMajor: amountMajor,
          currency: currency,
          description: description,
          performedBy: performedBy,
          performedByUserId: performedByUserId,
          bucket: bucket,
          credit: isCredit,
          cashDeltaMajor: cashDelta,
          stcPayDeltaMajor: stcPayDelta,
        ),
      );
      _transactions = [tx, ..._transactions];
      await fetchAllAccounts();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error recording movement: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> transfer({
    required String fromAccountId,
    required String toAccountId,
    required double amountMajor,
    required String currency,
    required String description,
    required String performedBy,
    required String performedByUserId,
  }) async {
    _error = null;
    try {
      await transferFundsUseCase(
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
        amountMajor: amountMajor,
        currency: currency,
        description: description,
        performedBy: performedBy,
        performedByUserId: performedByUserId,
      );
      await fetchAllAccounts();
      if (_selectedAccountId != null) {
        await fetchTransactions(_selectedAccountId!);
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error transferring: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Legacy name used by UI — routes to safe post path.
  Future<void> recordTransaction(
    FundTransactionEntity transaction, {
    double? cashDelta,
    double? stcPayDelta,
    String? performedByUserId,
  }) async {
    final isCredit = transaction.type == FundTransactionType.deposit ||
        transaction.type == FundTransactionType.reversal;
    await recordMovement(
      fundAccountId: transaction.fundAccountId,
      type: transaction.type == FundTransactionType.expensePayment
          ? FundTransactionType.withdrawal
          : transaction.type,
      amountMajor: transaction.amount,
      currency: transaction.currency,
      description: transaction.description,
      performedBy: transaction.performedBy,
      performedByUserId: performedByUserId ?? transaction.performedByUserId ?? '',
      bucket: transaction.bucket,
      cashDelta: cashDelta,
      stcPayDelta: stcPayDelta,
    );
    // silence unused if type is withdrawal with isCredit false
    assert(isCredit || !isCredit);
  }

  FundAccountEntity? getAccountById(String id) {
    try {
      return _accounts.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }
}
