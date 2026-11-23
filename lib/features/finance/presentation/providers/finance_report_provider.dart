import 'package:flutter/foundation.dart';

import '../../domain/entities/expense_entity.dart';
import '../../domain/entities/finance_report.dart';
import '../../domain/entities/fund_account_entity.dart';
import '../../domain/entities/fund_transaction_entity.dart';
import '../../domain/services/finance_report_builder.dart';
import '../../domain/usecases/get_all_expenses_usecase.dart';
import '../../domain/usecases/get_all_transactions_usecase.dart';

/// State for Finance → Reports: the raw ledger and expenses, the user's
/// filters and the report built from them.
class FinanceReportProvider with ChangeNotifier {
  final GetAllTransactionsUseCase getAllTransactionsUseCase;
  final GetAllExpensesUseCase getAllExpensesUseCase;

  FinanceReportProvider({
    required this.getAllTransactionsUseCase,
    required this.getAllExpensesUseCase,
  });

  List<FundTransactionEntity> _transactions = const [];
  List<ExpenseEntity> _expenses = const [];
  List<FundAccountEntity> _accounts = const [];
  bool _includeUnassigned = false;
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _error;
  FinanceReportFilter _filter = FinanceReportFilter(
    from: DateTime(DateTime.now().year, DateTime.now().month, 1),
    to: DateTime.now(),
  );

  LedgerReport? _ledger;
  ExpenseReport? _expenseReport;

  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get error => _error;
  FinanceReportFilter get filter => _filter;

  /// Accounts the current user may report on.
  List<FundAccountEntity> get accounts => _accounts;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        getAllTransactionsUseCase(),
        getAllExpensesUseCase(),
      ]);
      _transactions = results[0] as List<FundTransactionEntity>;
      _expenses = results[1] as List<ExpenseEntity>;
      _hasLoaded = true;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading finance report data: $e');
    } finally {
      _isLoading = false;
      _invalidate();
    }
  }

  /// Sets which accounts the user may see. [includeUnassigned] lets admins
  /// see expenses not tied to one of them (non-wallet, removed accounts).
  void setScope(
    List<FundAccountEntity> accounts, {
    required bool includeUnassigned,
  }) {
    final sameAccounts = listEquals(
      accounts.map((a) => a.id).toList(),
      _accounts.map((a) => a.id).toList(),
    );
    if (sameAccounts && includeUnassigned == _includeUnassigned) return;
    _accounts = accounts;
    _includeUnassigned = includeUnassigned;
    final allowed = {for (final a in accounts) a.id};
    _filter = _filter.copyWith(
      accountIds: _filter.accountIds.where(allowed.contains).toSet(),
    );
    _invalidate();
  }

  void updateFilter(FinanceReportFilter filter) {
    _filter = filter;
    _invalidate();
  }

  void setType(FinanceReportType type) {
    if (type == _filter.type) return;
    _filter = _filter.copyWith(
      type: type,
      // Income should not count money moved between the listed accounts.
      excludeInternalTransfers: type == FinanceReportType.income,
      transactionTypes: const {},
      direction: LedgerDirection.all,
    );
    _invalidate();
  }

  /// Clears every filter except the report type and the period.
  void resetFilters() {
    _filter = FinanceReportFilter(
      type: _filter.type,
      from: _filter.from,
      to: _filter.to,
      excludeInternalTransfers: _filter.type == FinanceReportType.income,
    );
    _invalidate();
  }

  void _invalidate() {
    _ledger = null;
    _expenseReport = null;
    notifyListeners();
  }

  LedgerReport get ledgerReport => _ledger ??= FinanceReportBuilder.buildLedger(
        filter: _filter,
        accounts: _accounts,
        allTransactions: _transactions,
      );

  ExpenseReport get expenseReport =>
      _expenseReport ??= FinanceReportBuilder.buildExpenses(
        filter: _filter,
        accounts: _accounts,
        allExpenses: _expenses,
        includeUnassigned: _includeUnassigned,
      );

  /// The current report as an exportable document.
  ReportDocument buildDocument({required String generatedBy}) {
    return _filter.type.isLedger
        ? FinanceReportBuilder.ledgerDocument(
            filter: _filter,
            report: ledgerReport,
            accounts: _accounts,
            generatedBy: generatedBy,
          )
        : FinanceReportBuilder.expenseDocument(
            filter: _filter,
            report: expenseReport,
            accounts: _accounts,
            generatedBy: generatedBy,
          );
  }

  // ─── Expense filter options (from the expenses the user may see) ──

  Iterable<ExpenseEntity> get _scopedExpenses {
    final ids = {for (final a in _accounts) a.id};
    return _includeUnassigned
        ? _expenses
        : _expenses.where((e) => ids.contains(e.fundAccountId));
  }

  List<String> _distinct(String? Function(ExpenseEntity) pick) {
    final set = <String>{};
    for (final e in _scopedExpenses) {
      final v = pick(e)?.trim();
      if (v != null && v.isNotEmpty) set.add(v);
    }
    return set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  List<String> get categoryOptions => _distinct((e) => e.expenseCategory);
  List<String> get expenseTypeOptions => _distinct((e) => e.expenseType);
  List<String> get paymentMethodOptions => _distinct((e) => e.paymentMethod);
  List<String> get employeeOptions => _distinct((e) => e.employeeName);
  List<String> get vehicleOptions => _distinct((e) => e.vehicleName);
}
