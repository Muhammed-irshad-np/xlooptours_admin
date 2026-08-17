// ignore_for_file: avoid_returning_null_for_void
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:xloop_invoice/features/finance/domain/entities/cash_advance_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/expense_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/expense_category_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/finance_policy_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/fund_account_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/fund_account_type_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/fund_transaction_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/ledger_day_totals.dart';
import 'package:xloop_invoice/features/finance/domain/entities/petty_cash_session_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/post_fund_request.dart';
import 'package:xloop_invoice/features/finance/domain/repositories/finance_repository.dart';

/// Configurable fake repository for unit tests. Set the result/error
/// fields before calling the use case under test.
class FakeFinanceRepository implements FinanceRepository {
  // --- Expense approval ---
  ExpenseEntity? approveResult;
  Object? approveError;

  // --- Void expense ---
  ExpenseEntity? voidResult;
  Object? voidError;

  // --- Open petty cash session ---
  Object? openSessionError;

  // --- Close petty cash session ---
  PettyCashSessionEntity? closeResult;
  Object? closeSessionError;

  // --- Verify petty cash session ---
  Object? verifySessionError;

  // --- Fund movement ---
  FundTransactionEntity? fundMovementResult;
  Object? fundMovementError;

  // --- Transfer ---
  Object? transferError;

  @override
  Future<ExpenseEntity> approveAndPostExpense({
    required String expenseId,
    required String actorName,
    required String actorUserId,
    required String actorRole,
    bool allowSelfApprove = false,
  }) async {
    if (approveError != null) throw approveError!;
    return approveResult!;
  }

  @override
  Future<ExpenseEntity> voidPaidExpense({
    required String expenseId,
    required String actorName,
    required String actorUserId,
    required String reason,
  }) async {
    if (voidError != null) throw voidError!;
    return voidResult!;
  }

  @override
  Future<void> openPettyCashSession(PettyCashSessionEntity session) async {
    if (openSessionError != null) throw openSessionError!;
  }

  @override
  Future<PettyCashSessionEntity> closePettyCashSession({
    required PettyCashSessionEntity session,
    required String closedBy,
    required String? closedByUserId,
  }) async {
    if (closeSessionError != null) throw closeSessionError!;
    return closeResult!;
  }

  @override
  Future<void> verifyPettyCashSession({
    required String sessionId,
    required String verifiedBy,
    required String? verifiedByUserId,
  }) async {
    if (verifySessionError != null) throw verifySessionError!;
  }

  @override
  Future<FundTransactionEntity> postFundMovement(
    PostFundRequest request,
  ) async {
    if (fundMovementError != null) throw fundMovementError!;
    return fundMovementResult!;
  }

  @override
  Future<void> transferBetweenAccounts({
    required String fromAccountId,
    required String toAccountId,
    required double amountMajor,
    required String currency,
    required String description,
    required String performedBy,
    required String performedByUserId,
    FundBucket fromBucket = FundBucket.total,
    FundBucket toBucket = FundBucket.total,
  }) async {
    if (transferError != null) throw transferError!;
  }

  // ── Stubs for remaining interface methods ──────────────────────────────────

  @override
  Future<List<ExpenseEntity>> getAllExpenses() async => [];

  @override
  Future<(List<ExpenseEntity>, DocumentSnapshot?)> getExpensesPage({
    DocumentSnapshot? cursor,
    int pageSize = 150,
  }) async => (<ExpenseEntity>[], null);

  @override
  Future<List<ExpenseEntity>> getExpensesByDateRange(
    DateTime start,
    DateTime end,
  ) async => [];

  @override
  Future<List<ExpenseEntity>> getExpensesByAccount(
    String fundAccountId,
  ) async => [];

  @override
  Future<void> insertExpense(ExpenseEntity expense) async {}

  @override
  Future<void> updateExpense(ExpenseEntity expense) async {}

  @override
  Future<void> deleteExpense(String id) async {}

  @override
  Future<String> generateReferenceNumber() async => '#10001';

  @override
  Future<String> uploadReceipt(XFile file, String expenseId) async => '';

  @override
  Future<ExpenseEntity> rejectExpense({
    required String expenseId,
    required String actorName,
    required String actorUserId,
    required String reason,
  }) async => throw UnimplementedError();

  @override
  Future<List<FundAccountEntity>> getAllFundAccounts() async => [];

  @override
  Future<void> insertFundAccount(FundAccountEntity account) async {}

  @override
  Future<void> updateFundAccount(FundAccountEntity account) async {}

  @override
  Future<void> deleteFundAccount(String id) async {}

  @override
  Future<List<FundTransactionEntity>> getTransactionsForAccount(
    String accountId,
  ) async => [];

  @override
  Future<List<PettyCashSessionEntity>> getPettyCashSessions(
    String accountId,
  ) async => [];

  @override
  Future<PettyCashSessionEntity?> getOpenSession(String accountId) async =>
      null;

  @override
  Future<String> uploadClosingSheet(XFile file, String sessionId) async => '';

  @override
  Future<LedgerDayTotals> getLedgerDayTotals(
    String accountId,
    DateTime day, {
    DateTime? sessionOpenedAt,
  }) async {
    return const LedgerDayTotals(
      cashDeposits: 0,
      stcPayDeposits: 0,
      cashExpenses: 0,
      stcPayExpenses: 0,
    );
  }

  @override
  Future<bool> isDayLocked(String fundAccountId, DateTime day) async => false;

  @override
  Future<List<CashAdvanceEntity>> getCashAdvances({
    String? fundAccountId,
  }) async => [];

  @override
  Future<CashAdvanceEntity> issueCashAdvance(CashAdvanceEntity advance) async =>
      advance;

  @override
  Future<CashAdvanceEntity> settleCashAdvance({
    required String advanceId,
    required double settleAmountMajor,
    required String actorName,
    required String actorUserId,
    required bool returnToFund,
  }) async => throw UnimplementedError();

  @override
  Future<CashAdvanceEntity> writeOffCashAdvance({
    required String advanceId,
    required String reason,
    required String actorName,
    required String actorUserId,
  }) async => throw UnimplementedError();

  @override
  Future<FinancePolicyEntity> getFinancePolicy() async {
    return const FinancePolicyEntity(
      approvalLimits: {'admin': 999999999, 'manager': 5000, 'finance': 50000},
      blockSelfApprove: true,
    );
  }

  @override
  Future<void> saveFinancePolicy(FinancePolicyEntity policy) async {}

  @override
  Future<List<ExpenseCategoryEntity>> getExpenseCategories() async => [];

  @override
  Future<void> insertExpenseCategory(ExpenseCategoryEntity category) async {}

  @override
  Future<void> updateExpenseCategory(ExpenseCategoryEntity category) async {}

  @override
  Future<void> deleteExpenseCategory(String id) async {}

  @override
  Future<List<FundAccountTypeEntity>> getFundAccountTypes() async =>
      FundAccountTypeEntity.defaultTypes;

  @override
  Future<void> insertFundAccountType(FundAccountTypeEntity type) async {}

  @override
  Future<void> updateFundAccountType(FundAccountTypeEntity type) async {}

  @override
  Future<void> deleteFundAccountType(String id) async {}

  @override
  Future<void> resetFinanceModuleData() async {}
}
