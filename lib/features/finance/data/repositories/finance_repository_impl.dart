import 'package:image_picker/image_picker.dart';
import '../../domain/entities/expense_entity.dart';
import '../../domain/entities/fund_account_entity.dart';
import '../../domain/entities/fund_transaction_entity.dart';
import '../../domain/entities/petty_cash_session_entity.dart';
import '../../domain/entities/expense_category_entity.dart';
import '../../domain/repositories/finance_repository.dart';
import '../datasources/finance_remote_data_source.dart';
import '../models/expense_model.dart';
import '../models/fund_account_model.dart';
import '../models/fund_transaction_model.dart';
import '../models/petty_cash_session_model.dart';
import '../models/expense_category_model.dart';

/// Firestore-backed implementation of [FinanceRepository].
class FinanceRepositoryImpl implements FinanceRepository {
  final FinanceRemoteDataSource remoteDataSource;

  FinanceRepositoryImpl({required this.remoteDataSource});

  // ─── Expenses ───────────────────────────────────────────────

  @override
  Future<List<ExpenseEntity>> getAllExpenses() async {
    final models = await remoteDataSource.getAllExpenses();
    return List<ExpenseEntity>.from(models);
  }

  @override
  Future<List<ExpenseEntity>> getExpensesByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final models = await remoteDataSource.getExpensesByDateRange(start, end);
    return List<ExpenseEntity>.from(models);
  }

  @override
  Future<List<ExpenseEntity>> getExpensesByAccount(
    String fundAccountId,
  ) async {
    final models = await remoteDataSource.getExpensesByAccount(fundAccountId);
    return List<ExpenseEntity>.from(models);
  }

  @override
  Future<void> insertExpense(ExpenseEntity expense) async {
    final model = ExpenseModel.fromEntity(expense);
    await remoteDataSource.insertExpense(model);
  }

  @override
  Future<void> updateExpense(ExpenseEntity expense) async {
    final model = ExpenseModel.fromEntity(expense);
    await remoteDataSource.updateExpense(model);
  }

  @override
  Future<void> deleteExpense(String id) async {
    await remoteDataSource.deleteExpense(id);
  }

  @override
  Future<String> generateReferenceNumber() async {
    return await remoteDataSource.generateReferenceNumber();
  }

  @override
  Future<String> uploadReceipt(XFile file, String expenseId) async {
    return await remoteDataSource.uploadReceipt(file, expenseId);
  }

  // ─── Fund Accounts ──────────────────────────────────────────

  @override
  Future<List<FundAccountEntity>> getAllFundAccounts() async {
    final models = await remoteDataSource.getAllFundAccounts();
    return List<FundAccountEntity>.from(models);
  }

  @override
  Future<void> insertFundAccount(FundAccountEntity account) async {
    final model = FundAccountModel.fromEntity(account);
    await remoteDataSource.insertFundAccount(model);
  }

  @override
  Future<void> updateFundAccount(FundAccountEntity account) async {
    final model = FundAccountModel.fromEntity(account);
    await remoteDataSource.updateFundAccount(model);
  }

  @override
  Future<void> deleteFundAccount(String id) async {
    await remoteDataSource.deleteFundAccount(id);
  }

  // ─── Fund Transactions ──────────────────────────────────────

  @override
  Future<List<FundTransactionEntity>> getTransactionsForAccount(
    String accountId,
  ) async {
    final models = await remoteDataSource.getTransactionsForAccount(accountId);
    return List<FundTransactionEntity>.from(models);
  }

  @override
  Future<void> insertTransaction(FundTransactionEntity transaction) async {
    final model = FundTransactionModel.fromEntity(transaction);
    await remoteDataSource.insertTransaction(model);
  }

  // ─── Petty Cash Sessions ────────────────────────────────────

  @override
  Future<List<PettyCashSessionEntity>> getPettyCashSessions(
    String accountId,
  ) async {
    final models = await remoteDataSource.getPettyCashSessions(accountId);
    return List<PettyCashSessionEntity>.from(models);
  }

  @override
  Future<PettyCashSessionEntity?> getOpenSession(String accountId) async {
    return await remoteDataSource.getOpenSession(accountId);
  }

  @override
  Future<void> openPettyCashSession(PettyCashSessionEntity session) async {
    final model = PettyCashSessionModel.fromEntity(session);
    await remoteDataSource.openPettyCashSession(model);
  }

  @override
  Future<void> closePettyCashSession(PettyCashSessionEntity session) async {
    final model = PettyCashSessionModel.fromEntity(session);
    await remoteDataSource.closePettyCashSession(model);
  }

  @override
  Future<void> verifyPettyCashSession(
    String sessionId,
    String verifiedBy,
  ) async {
    await remoteDataSource.verifyPettyCashSession(sessionId, verifiedBy);
  }

  @override
  Future<String> uploadClosingSheet(XFile file, String sessionId) async {
    return await remoteDataSource.uploadClosingSheet(file, sessionId);
  }

  // ─── Expense Categories ─────────────────────────────────────

  @override
  Future<List<ExpenseCategoryEntity>> getExpenseCategories() async {
    final models = await remoteDataSource.getExpenseCategories();
    return List<ExpenseCategoryEntity>.from(models);
  }

  @override
  Future<void> insertExpenseCategory(ExpenseCategoryEntity category) async {
    final model = ExpenseCategoryModel.fromEntity(category);
    await remoteDataSource.insertExpenseCategory(model);
  }

  @override
  Future<void> updateExpenseCategory(ExpenseCategoryEntity category) async {
    final model = ExpenseCategoryModel.fromEntity(category);
    await remoteDataSource.updateExpenseCategory(model);
  }

  @override
  Future<void> deleteExpenseCategory(String id) async {
    await remoteDataSource.deleteExpenseCategory(id);
  }
}
