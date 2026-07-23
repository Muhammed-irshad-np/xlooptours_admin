import 'package:image_picker/image_picker.dart';
import '../entities/cash_advance_entity.dart';
import '../entities/expense_entity.dart';
import '../entities/expense_category_entity.dart';
import '../entities/finance_policy_entity.dart';
import '../entities/fund_account_entity.dart';
import '../entities/fund_transaction_entity.dart';
import '../entities/ledger_day_totals.dart';
import '../entities/petty_cash_session_entity.dart';
import '../entities/post_fund_request.dart';

abstract class FinanceRepository {
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

  Future<ExpenseEntity> approveAndPostExpense({
    required String expenseId,
    required String actorName,
    required String actorUserId,
    required String actorRole,
    bool allowSelfApprove = false,
  });

  Future<ExpenseEntity> rejectExpense({
    required String expenseId,
    required String actorName,
    required String actorUserId,
    required String reason,
  });

  Future<ExpenseEntity> voidPaidExpense({
    required String expenseId,
    required String actorName,
    required String actorUserId,
    required String reason,
  });

  Future<List<FundAccountEntity>> getAllFundAccounts();
  Future<void> insertFundAccount(FundAccountEntity account);
  Future<void> updateFundAccount(FundAccountEntity account);
  Future<void> deleteFundAccount(String id);

  Future<List<FundTransactionEntity>> getTransactionsForAccount(
    String accountId,
  );
  Future<FundTransactionEntity> postFundMovement(PostFundRequest request);
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
  });

  Future<List<PettyCashSessionEntity>> getPettyCashSessions(String accountId);
  Future<PettyCashSessionEntity?> getOpenSession(String accountId);
  Future<void> openPettyCashSession(PettyCashSessionEntity session);
  Future<PettyCashSessionEntity> closePettyCashSession({
    required PettyCashSessionEntity session,
    required String closedBy,
    required String? closedByUserId,
  });
  Future<void> verifyPettyCashSession({
    required String sessionId,
    required String verifiedBy,
    required String? verifiedByUserId,
  });
  Future<String> uploadClosingSheet(XFile file, String sessionId);
  Future<LedgerDayTotals> getLedgerDayTotals(String accountId, DateTime day);
  Future<bool> isDayLocked(String fundAccountId, DateTime day);

  Future<List<CashAdvanceEntity>> getCashAdvances({String? fundAccountId});
  Future<CashAdvanceEntity> issueCashAdvance(CashAdvanceEntity advance);
  Future<CashAdvanceEntity> settleCashAdvance({
    required String advanceId,
    required double settleAmountMajor,
    required String actorName,
    required String actorUserId,
    required bool returnToFund,
  });

  Future<CashAdvanceEntity> writeOffCashAdvance({
    required String advanceId,
    required String reason,
    required String actorName,
    required String actorUserId,
  });

  Future<FinancePolicyEntity> getFinancePolicy();
  Future<void> saveFinancePolicy(FinancePolicyEntity policy);

  Future<List<ExpenseCategoryEntity>> getExpenseCategories();
  Future<void> insertExpenseCategory(ExpenseCategoryEntity category);
  Future<void> updateExpenseCategory(ExpenseCategoryEntity category);
  Future<void> deleteExpenseCategory(String id);
}
