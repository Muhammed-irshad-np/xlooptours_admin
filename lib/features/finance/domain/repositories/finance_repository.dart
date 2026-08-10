import 'package:image_picker/image_picker.dart';
import '../entities/expense_entity.dart';
import '../entities/fund_account_entity.dart';
import '../entities/fund_transaction_entity.dart';
import '../entities/petty_cash_session_entity.dart';
import '../entities/expense_category_entity.dart';

/// Repository interface for all finance-related data operations.
///
/// Covers expenses, fund accounts, fund transactions,
/// petty cash sessions, and expense categories.
abstract class FinanceRepository {
  // ─── Expenses ───────────────────────────────────────────────
  Future<List<ExpenseEntity>> getAllExpenses();
  Future<List<ExpenseEntity>> getExpensesByDateRange(
    DateTime start,
    DateTime end,
  );
  Future<List<ExpenseEntity>> getExpensesByAccount(String fundAccountId);
  Future<void> insertExpense(ExpenseEntity expense);
  Future<void> updateExpense(ExpenseEntity expense);
  Future<void> deleteExpense(String id);
  Future<String> generateReferenceNumber();
  Future<String> uploadReceipt(XFile file, String expenseId);

  // ─── Fund Accounts ──────────────────────────────────────────
  Future<List<FundAccountEntity>> getAllFundAccounts();
  Future<void> insertFundAccount(FundAccountEntity account);
  Future<void> updateFundAccount(FundAccountEntity account);
  Future<void> deleteFundAccount(String id);

  // ─── Fund Transactions ──────────────────────────────────────
  Future<List<FundTransactionEntity>> getTransactionsForAccount(
    String accountId,
  );
  Future<void> insertTransaction(FundTransactionEntity transaction);

  // ─── Petty Cash Sessions ────────────────────────────────────
  Future<List<PettyCashSessionEntity>> getPettyCashSessions(
    String accountId,
  );
  Future<PettyCashSessionEntity?> getOpenSession(String accountId);
  Future<void> openPettyCashSession(PettyCashSessionEntity session);
  Future<void> closePettyCashSession(PettyCashSessionEntity session);
  Future<void> verifyPettyCashSession(String sessionId, String verifiedBy);
  Future<String> uploadClosingSheet(XFile file, String sessionId);

  // ─── Expense Categories ─────────────────────────────────────
  Future<List<ExpenseCategoryEntity>> getExpenseCategories();
  Future<void> insertExpenseCategory(ExpenseCategoryEntity category);
  Future<void> updateExpenseCategory(ExpenseCategoryEntity category);
  Future<void> deleteExpenseCategory(String id);
}
