import 'package:image_picker/image_picker.dart';
import '../../domain/entities/cash_advance_entity.dart';
import '../../domain/entities/expense_entity.dart';
import '../../domain/entities/expense_category_entity.dart';
import '../../domain/entities/finance_policy_entity.dart';
import '../../domain/entities/fund_account_entity.dart';
import '../../domain/entities/fund_transaction_entity.dart';
import '../../domain/entities/ledger_day_totals.dart';
import '../../domain/entities/petty_cash_session_entity.dart';
import '../../domain/entities/post_fund_request.dart';
import '../../domain/repositories/finance_repository.dart';
import '../datasources/finance_remote_data_source.dart';
import '../models/cash_advance_model.dart';
import '../models/expense_model.dart';
import '../models/fund_account_model.dart';
import '../models/petty_cash_session_model.dart';
import '../models/expense_category_model.dart';

class FinanceRepositoryImpl implements FinanceRepository {
  final FinanceRemoteDataSource remoteDataSource;

  FinanceRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<ExpenseEntity>> getAllExpenses() async {
    return List.from(await remoteDataSource.getAllExpenses());
  }

  @override
  Future<List<ExpenseEntity>> getExpensesByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    return List.from(await remoteDataSource.getExpensesByDateRange(start, end));
  }

  @override
  Future<List<ExpenseEntity>> getExpensesByAccount(String fundAccountId) async {
    return List.from(
      await remoteDataSource.getExpensesByAccount(fundAccountId),
    );
  }

  @override
  Future<void> insertExpense(ExpenseEntity expense) async {
    await remoteDataSource.insertExpense(ExpenseModel.fromEntity(expense));
  }

  @override
  Future<void> updateExpense(ExpenseEntity expense) async {
    await remoteDataSource.updateExpense(ExpenseModel.fromEntity(expense));
  }

  @override
  Future<void> deleteExpense(String id) => remoteDataSource.deleteExpense(id);

  @override
  Future<String> generateReferenceNumber() =>
      remoteDataSource.generateReferenceNumber();

  @override
  Future<String> uploadReceipt(XFile file, String expenseId) =>
      remoteDataSource.uploadReceipt(file, expenseId);

  @override
  Future<ExpenseEntity> approveAndPostExpense({
    required String expenseId,
    required String actorName,
    required String actorUserId,
    required String actorRole,
    bool allowSelfApprove = false,
  }) {
    return remoteDataSource.approveAndPostExpense(
      expenseId: expenseId,
      actorName: actorName,
      actorUserId: actorUserId,
      actorRole: actorRole,
      allowSelfApprove: allowSelfApprove,
    );
  }

  @override
  Future<ExpenseEntity> rejectExpense({
    required String expenseId,
    required String actorName,
    required String actorUserId,
    required String reason,
  }) {
    return remoteDataSource.rejectExpense(
      expenseId: expenseId,
      actorName: actorName,
      actorUserId: actorUserId,
      reason: reason,
    );
  }

  @override
  Future<ExpenseEntity> voidPaidExpense({
    required String expenseId,
    required String actorName,
    required String actorUserId,
    required String reason,
  }) {
    return remoteDataSource.voidPaidExpense(
      expenseId: expenseId,
      actorName: actorName,
      actorUserId: actorUserId,
      reason: reason,
    );
  }

  @override
  Future<List<FundAccountEntity>> getAllFundAccounts() async {
    return List.from(await remoteDataSource.getAllFundAccounts());
  }

  @override
  Future<void> insertFundAccount(FundAccountEntity account) async {
    await remoteDataSource.insertFundAccount(
      FundAccountModel.fromEntity(account),
    );
  }

  @override
  Future<void> updateFundAccount(FundAccountEntity account) async {
    await remoteDataSource.updateFundAccount(
      FundAccountModel.fromEntity(account),
    );
  }

  @override
  Future<void> deleteFundAccount(String id) =>
      remoteDataSource.deleteFundAccount(id);

  @override
  Future<List<FundTransactionEntity>> getTransactionsForAccount(
    String accountId,
  ) async {
    return List.from(
      await remoteDataSource.getTransactionsForAccount(accountId),
    );
  }

  @override
  Future<FundTransactionEntity> postFundMovement(PostFundRequest request) {
    return remoteDataSource.postFundMovement(request);
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
  }) {
    return remoteDataSource.transferBetweenAccounts(
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      amountMajor: amountMajor,
      currency: currency,
      description: description,
      performedBy: performedBy,
      performedByUserId: performedByUserId,
      fromBucket: fromBucket,
      toBucket: toBucket,
    );
  }

  @override
  Future<List<PettyCashSessionEntity>> getPettyCashSessions(
    String accountId,
  ) async {
    return List.from(await remoteDataSource.getPettyCashSessions(accountId));
  }

  @override
  Future<PettyCashSessionEntity?> getOpenSession(String accountId) =>
      remoteDataSource.getOpenSession(accountId);

  @override
  Future<void> openPettyCashSession(PettyCashSessionEntity session) async {
    await remoteDataSource.openPettyCashSession(
      PettyCashSessionModel.fromEntity(session),
    );
  }

  @override
  Future<PettyCashSessionEntity> closePettyCashSession({
    required PettyCashSessionEntity session,
    required String closedBy,
    required String? closedByUserId,
  }) {
    return remoteDataSource.closePettyCashSession(
      session: PettyCashSessionModel.fromEntity(session),
      closedBy: closedBy,
      closedByUserId: closedByUserId,
    );
  }

  @override
  Future<void> verifyPettyCashSession({
    required String sessionId,
    required String verifiedBy,
    required String? verifiedByUserId,
  }) {
    return remoteDataSource.verifyPettyCashSession(
      sessionId: sessionId,
      verifiedBy: verifiedBy,
      verifiedByUserId: verifiedByUserId,
    );
  }

  @override
  Future<String> uploadClosingSheet(XFile file, String sessionId) =>
      remoteDataSource.uploadClosingSheet(file, sessionId);

  @override
  Future<LedgerDayTotals> getLedgerDayTotals(String accountId, DateTime day) =>
      remoteDataSource.getLedgerDayTotals(accountId, day);

  @override
  Future<bool> isDayLocked(String fundAccountId, DateTime day) =>
      remoteDataSource.isDayLocked(fundAccountId, day);

  @override
  Future<List<CashAdvanceEntity>> getCashAdvances({
    String? fundAccountId,
  }) async {
    return List.from(
      await remoteDataSource.getCashAdvances(fundAccountId: fundAccountId),
    );
  }

  @override
  Future<CashAdvanceEntity> issueCashAdvance(CashAdvanceEntity advance) {
    return remoteDataSource.issueCashAdvance(
      advance: CashAdvanceModel.fromEntity(advance),
    );
  }

  @override
  Future<CashAdvanceEntity> settleCashAdvance({
    required String advanceId,
    required double settleAmountMajor,
    required String actorName,
    required String actorUserId,
    required bool returnToFund,
  }) {
    return remoteDataSource.settleCashAdvance(
      advanceId: advanceId,
      settleAmountMajor: settleAmountMajor,
      actorName: actorName,
      actorUserId: actorUserId,
      returnToFund: returnToFund,
    );
  }

  @override
  Future<CashAdvanceEntity> writeOffCashAdvance({
    required String advanceId,
    required String reason,
    required String actorName,
    required String actorUserId,
  }) {
    return remoteDataSource.writeOffCashAdvance(
      advanceId: advanceId,
      reason: reason,
      actorName: actorName,
      actorUserId: actorUserId,
    );
  }

  @override
  Future<FinancePolicyEntity> getFinancePolicy() =>
      remoteDataSource.getFinancePolicy();

  @override
  Future<void> saveFinancePolicy(FinancePolicyEntity policy) =>
      remoteDataSource.saveFinancePolicy(policy);

  @override
  Future<List<ExpenseCategoryEntity>> getExpenseCategories() async {
    return List.from(await remoteDataSource.getExpenseCategories());
  }

  @override
  Future<void> insertExpenseCategory(ExpenseCategoryEntity category) async {
    await remoteDataSource.insertExpenseCategory(
      ExpenseCategoryModel.fromEntity(category),
    );
  }

  @override
  Future<void> updateExpenseCategory(ExpenseCategoryEntity category) async {
    await remoteDataSource.updateExpenseCategory(
      ExpenseCategoryModel.fromEntity(category),
    );
  }

  @override
  Future<void> deleteExpenseCategory(String id) =>
      remoteDataSource.deleteExpenseCategory(id);
}
