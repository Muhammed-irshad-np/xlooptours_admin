import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/expense_model.dart';
import '../models/fund_account_model.dart';
import '../models/fund_transaction_model.dart';
import '../models/petty_cash_session_model.dart';
import '../models/expense_category_model.dart';

/// Abstract data source interface for finance remote operations.
abstract class FinanceRemoteDataSource {
  // ─── Expenses ───────────────────────────────────────────────
  Future<List<ExpenseModel>> getAllExpenses();
  Future<List<ExpenseModel>> getExpensesByDateRange(
    DateTime start,
    DateTime end,
  );
  Future<List<ExpenseModel>> getExpensesByAccount(String fundAccountId);
  Future<void> insertExpense(ExpenseModel expense);
  Future<void> updateExpense(ExpenseModel expense);
  Future<void> deleteExpense(String id);
  Future<String> generateReferenceNumber();
  Future<String> uploadReceipt(XFile file, String expenseId);

  // ─── Fund Accounts ──────────────────────────────────────────
  Future<List<FundAccountModel>> getAllFundAccounts();
  Future<void> insertFundAccount(FundAccountModel account);
  Future<void> updateFundAccount(FundAccountModel account);
  Future<void> deleteFundAccount(String id);

  // ─── Fund Transactions ──────────────────────────────────────
  Future<List<FundTransactionModel>> getTransactionsForAccount(
    String accountId,
  );
  Future<void> insertTransaction(FundTransactionModel transaction);

  // ─── Petty Cash Sessions ────────────────────────────────────
  Future<List<PettyCashSessionModel>> getPettyCashSessions(
    String accountId,
  );
  Future<PettyCashSessionModel?> getOpenSession(String accountId);
  Future<void> openPettyCashSession(PettyCashSessionModel session);
  Future<void> closePettyCashSession(PettyCashSessionModel session);
  Future<void> verifyPettyCashSession(String sessionId, String verifiedBy);
  Future<String> uploadClosingSheet(XFile file, String sessionId);

  // ─── Expense Categories ─────────────────────────────────────
  Future<List<ExpenseCategoryModel>> getExpenseCategories();
  Future<void> insertExpenseCategory(ExpenseCategoryModel category);
  Future<void> updateExpenseCategory(ExpenseCategoryModel category);
  Future<void> deleteExpenseCategory(String id);
}

/// Firestore implementation of [FinanceRemoteDataSource].
class FinanceRemoteDataSourceImpl implements FinanceRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;

  FinanceRemoteDataSourceImpl({
    required this.firestore,
    required this.storage,
  });

  // ═══════════════════════════════════════════════════════════
  // EXPENSES
  // ═══════════════════════════════════════════════════════════

  @override
  Future<List<ExpenseModel>> getAllExpenses() async {
    final snapshot = await firestore
        .collection('expenses')
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => ExpenseModel.fromJson(doc.data()))
        .toList();
  }

  @override
  Future<List<ExpenseModel>> getExpensesByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final snapshot = await firestore
        .collection('expenses')
        .where('date', isGreaterThanOrEqualTo: start.toIso8601String())
        .where('date', isLessThanOrEqualTo: end.toIso8601String())
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => ExpenseModel.fromJson(doc.data()))
        .toList();
  }

  @override
  Future<List<ExpenseModel>> getExpensesByAccount(
    String fundAccountId,
  ) async {
    final snapshot = await firestore
        .collection('expenses')
        .where('fundAccountId', isEqualTo: fundAccountId)
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => ExpenseModel.fromJson(doc.data()))
        .toList();
  }

  @override
  Future<void> insertExpense(ExpenseModel expense) async {
    await firestore
        .collection('expenses')
        .doc(expense.id)
        .set(expense.toJson());
  }

  @override
  Future<void> updateExpense(ExpenseModel expense) async {
    await firestore
        .collection('expenses')
        .doc(expense.id)
        .update(expense.toJson());
  }

  @override
  Future<void> deleteExpense(String id) async {
    await firestore.collection('expenses').doc(id).delete();
  }

  @override
  Future<String> generateReferenceNumber() async {
    // Get the latest expense to determine the next reference number.
    final snapshot = await firestore
        .collection('expenses')
        .orderBy('referenceNumber', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return '#10001';
    }

    final lastRef = snapshot.docs.first.data()['referenceNumber'] as String;
    // Parse the numeric portion (e.g., "#10001" → 10001).
    final numericPart = int.tryParse(lastRef.replaceAll('#', '')) ?? 10000;
    return '#${numericPart + 1}';
  }

  @override
  Future<String> uploadReceipt(XFile file, String expenseId) async {
    final ext = file.name.split('.').last;
    final ref = storage.ref('expenses/$expenseId/receipt_${DateTime.now().millisecondsSinceEpoch}.$ext');

    final Uint8List bytes = await file.readAsBytes();
    final metadata = SettableMetadata(contentType: _getMimeType(ext));
    await ref.putData(bytes, metadata);
    return await ref.getDownloadURL();
  }

  // ═══════════════════════════════════════════════════════════
  // FUND ACCOUNTS
  // ═══════════════════════════════════════════════════════════

  @override
  Future<List<FundAccountModel>> getAllFundAccounts() async {
    final snapshot = await firestore
        .collection('fund_accounts')
        .orderBy('name')
        .get();
    return snapshot.docs
        .map((doc) => FundAccountModel.fromJson(doc.data()))
        .toList();
  }

  @override
  Future<void> insertFundAccount(FundAccountModel account) async {
    await firestore
        .collection('fund_accounts')
        .doc(account.id)
        .set(account.toJson());
  }

  @override
  Future<void> updateFundAccount(FundAccountModel account) async {
    await firestore
        .collection('fund_accounts')
        .doc(account.id)
        .update(account.toJson());
  }

  @override
  Future<void> deleteFundAccount(String id) async {
    await firestore.collection('fund_accounts').doc(id).delete();
  }

  // ═══════════════════════════════════════════════════════════
  // FUND TRANSACTIONS
  // ═══════════════════════════════════════════════════════════

  @override
  Future<List<FundTransactionModel>> getTransactionsForAccount(
    String accountId,
  ) async {
    final snapshot = await firestore
        .collection('fund_transactions')
        .where('fundAccountId', isEqualTo: accountId)
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => FundTransactionModel.fromJson(doc.data()))
        .toList();
  }

  @override
  Future<void> insertTransaction(FundTransactionModel transaction) async {
    // Use a batch to update both the transaction and the account balance
    // atomically.
    final batch = firestore.batch();

    // 1. Insert the transaction document.
    final txRef =
        firestore.collection('fund_transactions').doc(transaction.id);
    batch.set(txRef, transaction.toJson());

    // 2. Update the fund account balance.
    final accountRef =
        firestore.collection('fund_accounts').doc(transaction.fundAccountId);
    batch.update(accountRef, {
      'currentBalance': transaction.balanceAfter,
    });

    await batch.commit();
  }

  // ═══════════════════════════════════════════════════════════
  // PETTY CASH SESSIONS
  // ═══════════════════════════════════════════════════════════

  @override
  Future<List<PettyCashSessionModel>> getPettyCashSessions(
    String accountId,
  ) async {
    final snapshot = await firestore
        .collection('petty_cash_sessions')
        .where('fundAccountId', isEqualTo: accountId)
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => PettyCashSessionModel.fromJson(doc.data()))
        .toList();
  }

  @override
  Future<PettyCashSessionModel?> getOpenSession(String accountId) async {
    final snapshot = await firestore
        .collection('petty_cash_sessions')
        .where('fundAccountId', isEqualTo: accountId)
        .where('status', isEqualTo: 'open')
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return PettyCashSessionModel.fromJson(snapshot.docs.first.data());
  }

  @override
  Future<void> openPettyCashSession(PettyCashSessionModel session) async {
    await firestore
        .collection('petty_cash_sessions')
        .doc(session.id)
        .set(session.toJson());
  }

  @override
  Future<void> closePettyCashSession(PettyCashSessionModel session) async {
    await firestore
        .collection('petty_cash_sessions')
        .doc(session.id)
        .update(session.toJson());
  }

  @override
  Future<void> verifyPettyCashSession(
    String sessionId,
    String verifiedBy,
  ) async {
    await firestore.collection('petty_cash_sessions').doc(sessionId).update({
      'status': 'verified',
      'verifiedBy': verifiedBy,
      'verifiedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<String> uploadClosingSheet(XFile file, String sessionId) async {
    final ext = file.name.split('.').last;
    final ref = storage.ref('petty_cash/$sessionId/closing_sheet.$ext');

    final Uint8List bytes = await file.readAsBytes();
    final metadata = SettableMetadata(contentType: _getMimeType(ext));
    await ref.putData(bytes, metadata);
    return await ref.getDownloadURL();
  }

  // ═══════════════════════════════════════════════════════════
  // EXPENSE CATEGORIES
  // ═══════════════════════════════════════════════════════════

  @override
  Future<List<ExpenseCategoryModel>> getExpenseCategories() async {
    final snapshot = await firestore
        .collection('expense_categories')
        .orderBy('name')
        .get();
    return snapshot.docs
        .map((doc) => ExpenseCategoryModel.fromJson(doc.data()))
        .toList();
  }

  @override
  Future<void> insertExpenseCategory(ExpenseCategoryModel category) async {
    await firestore
        .collection('expense_categories')
        .doc(category.id)
        .set(category.toJson());
  }

  @override
  Future<void> updateExpenseCategory(ExpenseCategoryModel category) async {
    await firestore
        .collection('expense_categories')
        .doc(category.id)
        .update(category.toJson());
  }

  @override
  Future<void> deleteExpenseCategory(String id) async {
    await firestore.collection('expense_categories').doc(id).delete();
  }

  // ═══════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════

  String _getMimeType(String ext) {
    switch (ext.toLowerCase().replaceAll('.', '')) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }
}
