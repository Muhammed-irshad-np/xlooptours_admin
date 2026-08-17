import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/cash_advance_entity.dart';
import '../../domain/entities/day_lock_entity.dart';
import '../../domain/entities/expense_entity.dart';
import '../../domain/entities/finance_policy_entity.dart';
import '../../domain/entities/fund_account_entity.dart';
import '../../domain/entities/fund_transaction_entity.dart';
import '../../domain/entities/ledger_day_totals.dart';
import '../../domain/entities/petty_cash_session_entity.dart';
import '../../domain/entities/post_fund_request.dart';
import '../models/cash_advance_model.dart';
import '../models/expense_model.dart';
import '../models/fund_account_model.dart';
import '../models/fund_transaction_model.dart';
import '../models/petty_cash_session_model.dart';
import '../models/expense_category_model.dart';
import '../../domain/entities/fund_account_type_entity.dart';
import '../models/fund_account_type_model.dart';

abstract class FinanceRemoteDataSource {
  // Expenses
  Future<List<ExpenseModel>> getAllExpenses();
  /// Paginated fetch. Pass [cursor] from the previous page's last doc.
  /// Returns at most [pageSize] results (default 150).
  Future<(List<ExpenseModel>, DocumentSnapshot?)> getExpensesPage({
    DocumentSnapshot? cursor,
    int pageSize = 150,
  });
  Future<List<ExpenseModel>> getExpensesByDateRange(DateTime start, DateTime end);
  Future<List<ExpenseModel>> getExpensesByAccount(String fundAccountId);
  Future<ExpenseModel?> getExpenseById(String id);
  Future<void> insertExpense(ExpenseModel expense);
  Future<void> updateExpense(ExpenseModel expense);
  Future<void> deleteExpense(String id);
  Future<String> generateReferenceNumber();
  Future<String> uploadReceipt(XFile file, String expenseId);

  Future<ExpenseModel> approveAndPostExpense({
    required String expenseId,
    required String actorName,
    required String actorUserId,
    required String actorRole,
    bool allowSelfApprove = false,
  });

  Future<ExpenseModel> rejectExpense({
    required String expenseId,
    required String actorName,
    required String actorUserId,
    required String reason,
  });

  Future<ExpenseModel> voidPaidExpense({
    required String expenseId,
    required String actorName,
    required String actorUserId,
    required String reason,
  });

  // Fund accounts
  Future<List<FundAccountModel>> getAllFundAccounts();
  Future<void> insertFundAccount(FundAccountModel account);
  Future<void> updateFundAccount(FundAccountModel account);
  Future<void> deactivateFundAccount(String id);
  Future<void> deleteFundAccount(String id);

  // Fund transactions
  Future<List<FundTransactionModel>> getTransactionsForAccount(String accountId);
  Future<FundTransactionModel> postFundMovement(PostFundRequest request);
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

  // Petty cash + day lock
  Future<List<PettyCashSessionModel>> getPettyCashSessions(String accountId);
  Future<PettyCashSessionModel?> getOpenSession(String accountId);
  Future<void> openPettyCashSession(PettyCashSessionModel session);
  /// Recomputes day ledger totals then closes.
  Future<PettyCashSessionModel> closePettyCashSession({
    required PettyCashSessionModel session,
    required String closedBy,
    required String? closedByUserId,
  });
  Future<void> verifyPettyCashSession({
    required String sessionId,
    required String verifiedBy,
    required String? verifiedByUserId,
  });
  Future<String> uploadClosingSheet(XFile file, String sessionId);
  Future<LedgerDayTotals> getLedgerDayTotals(String accountId, DateTime day, {DateTime? sessionOpenedAt});
  Future<bool> isDayLocked(String fundAccountId, DateTime day);

  // Advances
  Future<List<CashAdvanceModel>> getCashAdvances({String? fundAccountId});
  Future<CashAdvanceModel> issueCashAdvance({
    required CashAdvanceModel advance,
  });
  Future<CashAdvanceModel> settleCashAdvance({
    required String advanceId,
    required double settleAmountMajor,
    required String actorName,
    required String actorUserId,
    required bool returnToFund,
  });

  /// Closes outstanding advance as a loss. No cash returns to the fund
  /// (money already left when the advance was issued).
  Future<CashAdvanceModel> writeOffCashAdvance({
    required String advanceId,
    required String reason,
    required String actorName,
    required String actorUserId,
  });

  // Policy
  Future<FinancePolicyEntity> getFinancePolicy();
  Future<void> saveFinancePolicy(FinancePolicyEntity policy);

  // Categories
  Future<List<ExpenseCategoryModel>> getExpenseCategories();
  Future<void> insertExpenseCategory(ExpenseCategoryModel category);
  Future<void> updateExpenseCategory(ExpenseCategoryModel category);
  Future<void> deleteExpenseCategory(String id);

  // Account Types
  Future<List<FundAccountTypeModel>> getFundAccountTypes();
  Future<void> insertFundAccountType(FundAccountTypeModel type);
  Future<void> updateFundAccountType(FundAccountTypeModel type);
  Future<void> deleteFundAccountType(String id);

  /// Development-only tool: wipes test data across all finance collections.
  Future<void> resetFinanceModuleData();
}

class FinanceRemoteDataSourceImpl implements FinanceRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;
  final _uuid = const Uuid();

  FinanceRemoteDataSourceImpl({
    required this.firestore,
    required this.storage,
  });

  CollectionReference<Map<String, dynamic>> get _expenses =>
      firestore.collection('expenses');
  CollectionReference<Map<String, dynamic>> get _accounts =>
      firestore.collection('fund_accounts');
  CollectionReference<Map<String, dynamic>> get _txs =>
      firestore.collection('fund_transactions');
  CollectionReference<Map<String, dynamic>> get _counters =>
      firestore.collection('counters');
  CollectionReference<Map<String, dynamic>> get _audit =>
      firestore.collection('finance_audit_log');
  CollectionReference<Map<String, dynamic>> get _dayLocks =>
      firestore.collection('finance_day_locks');
  CollectionReference<Map<String, dynamic>> get _advances =>
      firestore.collection('cash_advances');
  DocumentReference<Map<String, dynamic>> get _policyDoc =>
      firestore.collection('finance_settings').doc('policy');

  // ─── Expenses ───────────────────────────────────────────────

  @override
  Future<List<ExpenseModel>> getAllExpenses() async {
    // Unbounded fetch — use getExpensesPage() for large datasets.
    final snapshot = await _expenses.orderBy('date', descending: true).get();
    return snapshot.docs.map((d) => ExpenseModel.fromJson(d.data())).toList();
  }

  @override
  Future<(List<ExpenseModel>, DocumentSnapshot?)> getExpensesPage({
    DocumentSnapshot? cursor,
    int pageSize = 150,
  }) async {
    Query<Map<String, dynamic>> q = _expenses
        .orderBy('date', descending: true)
        .limit(pageSize);
    if (cursor != null) {
      q = q.startAfterDocument(cursor);
    }
    final snapshot = await q.get();
    final docs = snapshot.docs
        .map((d) => ExpenseModel.fromJson(d.data()))
        .toList();
    final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
    return (docs, lastDoc);
  }

  @override
  Future<List<ExpenseModel>> getExpensesByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final snapshot = await _expenses
        .where('date', isGreaterThanOrEqualTo: start.toIso8601String())
        .where('date', isLessThanOrEqualTo: end.toIso8601String())
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs.map((d) => ExpenseModel.fromJson(d.data())).toList();
  }

  @override
  Future<List<ExpenseModel>> getExpensesByAccount(String fundAccountId) async {
    // Equality-only query (no composite index required); sort client-side.
    final snapshot = await _expenses
        .where('fundAccountId', isEqualTo: fundAccountId)
        .get();
    final list =
        snapshot.docs.map((d) => ExpenseModel.fromJson(d.data())).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  @override
  Future<ExpenseModel?> getExpenseById(String id) async {
    final doc = await _expenses.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return ExpenseModel.fromJson(doc.data()!);
  }

  @override
  Future<void> insertExpense(ExpenseModel expense) async {
    final data = expense.toJson();
    data['amountMinor'] = expense.resolvedAmountMinor;
    await _expenses.doc(expense.id).set(data);
    await _writeAudit(
      action: 'expense.insert',
      entityType: 'expense',
      entityId: expense.id,
      actorUserId: expense.submittedByUserId,
      actorName: expense.submittedBy,
      detail: expense.referenceNumber,
    );
  }

  @override
  Future<void> updateExpense(ExpenseModel expense) async {
    // Only allow field updates for non-posted expenses at data layer when status is editable.
    final existing = await getExpenseById(expense.id);
    if (existing != null && !existing.status.canEdit) {
      throw StateError(
        'Cannot edit expense in status ${existing.status.name}. Void or reverse instead.',
      );
    }
    await _expenses
        .doc(expense.id)
        .set(_stripNulls(expense.toJson()), SetOptions(merge: true));
  }

  @override
  Future<void> deleteExpense(String id) async {
    final existing = await getExpenseById(id);
    if (existing == null) return;
    if (!existing.status.canHardDelete) {
      throw StateError(
        'Cannot delete posted/closed expense. Void it instead.',
      );
    }
    await _expenses.doc(id).delete();
    await _writeAudit(
      action: 'expense.delete_draft',
      entityType: 'expense',
      entityId: id,
      actorName: 'system',
      detail: existing.referenceNumber,
    );
  }

  @override
  Future<String> generateReferenceNumber() async {
    final counterRef = _counters.doc('expense_reference');
    return firestore.runTransaction((txn) async {
      final snap = await txn.get(counterRef);
      int next = 10001;
      if (snap.exists) {
        next = ((snap.data()?['value'] as num?)?.toInt() ?? 10000) + 1;
      }
      txn.set(counterRef, {'value': next}, SetOptions(merge: true));
      return '#$next';
    });
  }

  @override
  Future<String> uploadReceipt(XFile file, String expenseId) async {
    final ext = file.name.split('.').last;
    final ref = storage.ref(
      'expenses/$expenseId/receipt_${DateTime.now().millisecondsSinceEpoch}.$ext',
    );
    final bytes = await file.readAsBytes();
    final metadata = SettableMetadata(contentType: _getMimeType(ext));
    await ref.putData(bytes, metadata);
    return ref.getDownloadURL();
  }

  @override
  Future<ExpenseModel> approveAndPostExpense({
    required String expenseId,
    required String actorName,
    required String actorUserId,
    required String actorRole,
    bool allowSelfApprove = false,
  }) async {
    // Validate OUTSIDE the transaction so Flutter web surfaces real messages
    // (exceptions inside runTransaction become "Dart exception thrown…").
    final policy = await getFinancePolicy();
    final existing = await getExpenseById(expenseId);
    if (existing == null) {
      throw StateError('Expense not found');
    }
    if (existing.status == ExpenseStatus.paid) {
      return existing;
    }
    if (existing.status != ExpenseStatus.pending &&
        existing.status != ExpenseStatus.approved) {
      throw StateError(
        'Expense cannot be paid from status ${existing.status.name}',
      );
    }
    if (policy.blockSelfApprove &&
        !allowSelfApprove &&
        existing.submittedByUserId != null &&
        existing.submittedByUserId == actorUserId &&
        actorUserId.isNotEmpty) {
      throw StateError('Cannot approve your own expense');
    }
    if (!policy.canApproveAmount(actorRole, existing.amount)) {
      final limit = policy.limitForRole(actorRole);
      throw StateError(
        'Amount ${existing.amount} exceeds your approval limit'
        '${limit != null ? ' ($limit)' : ''}. Your role: $actorRole',
      );
    }
    _assertExpensePolicy(existing, policy);

    if (!existing.isNonWallet && existing.fundAccountId.isNotEmpty) {
      // Parallelize day lock check and single target account document fetch
      final results = await Future.wait([
        isDayLocked(existing.fundAccountId, existing.date),
        _accounts.doc(existing.fundAccountId).get(),
      ]);
      final dayLocked = results[0] as bool;
      final accSnap = results[1] as DocumentSnapshot<Map<String, dynamic>>;

      if (dayLocked) {
        throw StateError(
          'Day ${DayLockEntity.dayKeyFrom(existing.date)} is locked '
          'for this fund account after petty cash verification.',
        );
      }
      if (!accSnap.exists || accSnap.data() == null) {
        throw StateError(
          'Fund account not found (${existing.fundAccountId}). '
          'Pick a valid wallet on the expense.',
        );
      }
      final account = FundAccountModel.fromJson(accSnap.data()!);
      if (!account.isActive) {
        throw StateError('Fund account is inactive');
      }
      if (account.type == FundAccountType.pettyCash) {
        final openSession = await getOpenSession(account.id);
        if (openSession == null) {
          throw StateError(
            'Cannot pay from Petty Cash account "${account.name}" because no petty cash session is currently open. '
            'Please open a session first in the Petty Cash tab.',
          );
        }
      }
      final amountMinor = existing.resolvedAmountMinor;
      final amountMajor = amountMinor / 100.0;
      final balAfterMinor = account.currentBalanceMinor - amountMinor;
      if (balAfterMinor < 0) {
        throw StateError(
          'Insufficient fund balance '
          '(have ${account.currentBalance.toStringAsFixed(2)}, '
          'need ${amountMajor.toStringAsFixed(2)} ${existing.currency})',
        );
      }
      final bucket = _resolvePaymentBucket(
        paymentMethod: existing.paymentMethod,
        cashBalance: account.cashBalance,
        stcPayBalance: account.stcPayBalance,
      );
      if (bucket == FundBucket.cash &&
          account.cashBalance + 1e-9 < amountMajor) {
        throw StateError(
          'Insufficient cash balance '
          '(have ${account.cashBalance.toStringAsFixed(2)}, '
          'need ${amountMajor.toStringAsFixed(2)}). '
          'Deposit cash into this wallet first, or use STC Pay.',
        );
      }
      if (bucket == FundBucket.stcPay &&
          account.stcPayBalance + 1e-9 < amountMajor) {
        throw StateError(
          'Insufficient STC Pay balance '
          '(have ${account.stcPayBalance.toStringAsFixed(2)}, '
          'need ${amountMajor.toStringAsFixed(2)})',
        );
      }
    }

    try {
      final result = await firestore.runTransaction((txn) async {
        final expRef = _expenses.doc(expenseId);
        final expSnap = await txn.get(expRef);
        if (!expSnap.exists || expSnap.data() == null) {
          throw Exception('Expense not found');
        }
        final expense = ExpenseModel.fromJson(expSnap.data()!);

        if (expense.status == ExpenseStatus.paid) {
          return expense;
        }
        if (expense.status != ExpenseStatus.pending &&
            expense.status != ExpenseStatus.approved) {
          throw Exception(
            'Expense status changed to ${expense.status.name}',
          );
        }

        final now = DateTime.now();
        String? ledgerId;

        if (!expense.isNonWallet && expense.fundAccountId.isNotEmpty) {
          final lockId =
              DayLockEntity.lockId(expense.fundAccountId, expense.date);
          final lockSnap = await txn.get(_dayLocks.doc(lockId));
          if (lockSnap.exists) {
            throw Exception('Day was locked during approve');
          }

          final accountRef = _accounts.doc(expense.fundAccountId);
          final accSnap = await txn.get(accountRef);
          if (!accSnap.exists || accSnap.data() == null) {
            throw Exception('Fund account not found');
          }
          final account = FundAccountModel.fromJson(accSnap.data()!);
          if (!account.isActive) {
            throw Exception('Fund account is inactive');
          }

          final amountMinor = expense.resolvedAmountMinor;
          final amountMajor = amountMinor / 100.0;
          final balBeforeMinor = account.currentBalanceMinor;
          final balAfterMinor = balBeforeMinor - amountMinor;
          if (balAfterMinor < 0) {
            throw Exception('Insufficient fund balance');
          }

          final bucket = _resolvePaymentBucket(
            paymentMethod: expense.paymentMethod,
            cashBalance: account.cashBalance,
            stcPayBalance: account.stcPayBalance,
          );
          double cash = account.cashBalance;
          double stc = account.stcPayBalance;
          if (bucket == FundBucket.cash) {
            if (cash + 1e-9 < amountMajor) {
              throw Exception('Insufficient cash balance');
            }
            cash -= amountMajor;
          } else if (bucket == FundBucket.stcPay) {
            if (stc + 1e-9 < amountMajor) {
              throw Exception('Insufficient STC Pay balance');
            }
            stc -= amountMajor;
          } else {
            // FundBucket.total: deduct from cash first, then remainder from STC Pay
            if (cash >= amountMajor) {
              cash -= amountMajor;
            } else {
              final rem = amountMajor - cash;
              cash = 0;
              stc = (stc - rem).clamp(0.0, double.infinity);
            }
          }

          ledgerId = _uuid.v4();
          final balBefore = balBeforeMinor / 100.0;
          final balAfter = balAfterMinor / 100.0;

          final tx = FundTransactionModel(
            id: ledgerId,
            fundAccountId: expense.fundAccountId,
            type: FundTransactionType.expensePayment,
            amount: amountMajor,
            amountMinor: amountMinor,
            currency: expense.currency,
            description:
                'Payment ${expense.referenceNumber} — ${expense.expenseType}',
            referenceExpenseId: expense.id,
            performedBy: actorName,
            performedByUserId: actorUserId,
            date: now,
            createdAt: now,
            balanceBefore: balBefore,
            balanceAfter: balAfter,
            bucket: bucket,
          );

          // set() allows full document; update() rejects null fields on web.
          txn.set(_txs.doc(ledgerId), _stripNulls(tx.toJson()));
          final cashMinor = ((cash < 0 ? 0.0 : cash) * 100).round();
          final stcMinor = ((stc < 0 ? 0.0 : stc) * 100).round();
          txn.update(accountRef, {
            'currentBalanceMinor': balAfterMinor,
            'cashBalanceMinor': cashMinor,
            'stcPayBalanceMinor': stcMinor,
            'currentBalance': balAfter,
            'cashBalance': cash < 0 ? 0.0 : cash,
            'stcPayBalance': stc < 0 ? 0.0 : stc,
          });
        }

        final updated = expense.copyWith(
          status: expense.isNonWallet
              ? ExpenseStatus.approved
              : ExpenseStatus.paid,
          approvedBy: actorName,
          approvedByUserId: actorUserId,
          approvedAt: expense.approvedAt ?? now,
          paidBy: expense.isNonWallet ? null : actorName,
          paidByUserId: expense.isNonWallet ? null : actorUserId,
          paidAt: expense.isNonWallet ? null : now,
          ledgerEntryId: ledgerId,
          updatedAt: now,
          amountMinor: expense.resolvedAmountMinor,
        );

        // Merge set so null fields are not sent as invalid update values.
        txn.set(
          expRef,
          _stripNulls(ExpenseModel.fromEntity(updated).toJson()),
          SetOptions(merge: true),
        );
        return ExpenseModel.fromEntity(updated);
      });

      // Non-blocking audit log so response returns immediately to UI
      unawaited(
        _writeAudit(
          action: result.isNonWallet
              ? 'expense.approve'
              : 'expense.approve_and_post',
          entityType: 'expense',
          entityId: expenseId,
          actorUserId: actorUserId,
          actorName: actorName,
          detail: result.referenceNumber,
        ),
      );
      return result;
    } catch (e) {
      throw StateError(_unwrapFirebaseError(e));
    }
  }

  @override
  Future<ExpenseModel> rejectExpense({
    required String expenseId,
    required String actorName,
    required String actorUserId,
    required String reason,
  }) async {
    final existing = await getExpenseById(expenseId);
    if (existing == null) throw StateError('Expense not found');
    if (!existing.status.canReject) {
      throw StateError('Cannot reject expense in status ${existing.status.name}');
    }
    final now = DateTime.now();
    final updated = existing.copyWith(
      status: ExpenseStatus.rejected,
      approvedBy: actorName,
      approvedByUserId: actorUserId,
      approvedAt: now,
      rejectionReason: reason,
      updatedAt: now,
    );
    await _expenses.doc(expenseId).update(ExpenseModel.fromEntity(updated).toJson());
    await _writeAudit(
      action: 'expense.reject',
      entityType: 'expense',
      entityId: expenseId,
      actorUserId: actorUserId,
      actorName: actorName,
      detail: reason,
    );
    return ExpenseModel.fromEntity(updated);
  }

  @override
  Future<ExpenseModel> voidPaidExpense({
    required String expenseId,
    required String actorName,
    required String actorUserId,
    required String reason,
  }) async {
    return firestore.runTransaction((txn) async {
      final expRef = _expenses.doc(expenseId);
      final expSnap = await txn.get(expRef);
      if (!expSnap.exists || expSnap.data() == null) {
        throw StateError('Expense not found');
      }
      final expense = ExpenseModel.fromJson(expSnap.data()!);
      if (expense.status == ExpenseStatus.voided) return expense;
      if (!expense.status.canVoid) {
        throw StateError('Only paid expenses can be voided');
      }

      final now = DateTime.now();
      String? reverseId;

      if (!expense.isNonWallet &&
          expense.fundAccountId.isNotEmpty &&
          expense.ledgerEntryId != null) {
        final accountRef = _accounts.doc(expense.fundAccountId);
        final accSnap = await txn.get(accountRef);
        if (!accSnap.exists || accSnap.data() == null) {
          throw StateError('Fund account not found');
        }
        final account = FundAccountModel.fromJson(accSnap.data()!);
        final amountMinor = expense.resolvedAmountMinor;
        final amountMajor = amountMinor / 100.0;
        final balBeforeMinor = account.currentBalanceMinor;
        final balAfterMinor = balBeforeMinor + amountMinor;
        final balBefore = balBeforeMinor / 100.0;
        final balAfter = balAfterMinor / 100.0;

        final bucket = _bucketFromPaymentMethod(expense.paymentMethod);
        double cash = account.cashBalance;
        double stc = account.stcPayBalance;
        if (bucket == FundBucket.cash) {
          cash += amountMajor;
        } else if (bucket == FundBucket.stcPay) {
          stc += amountMajor;
        }

        reverseId = _uuid.v4();
        final tx = FundTransactionModel(
          id: reverseId,
          fundAccountId: expense.fundAccountId,
          type: FundTransactionType.reversal,
          amount: amountMajor,
          amountMinor: amountMinor,
          currency: expense.currency,
          description: 'Void ${expense.referenceNumber}: $reason',
          referenceExpenseId: expense.id,
          reversesTransactionId: expense.ledgerEntryId,
          performedBy: actorName,
          performedByUserId: actorUserId,
          date: now,
          createdAt: now,
          balanceBefore: balBefore,
          balanceAfter: balAfter,
          bucket: bucket,
          auditNote: reason,
        );
        txn.set(_txs.doc(reverseId), tx.toJson());
        final cashMinor = ((cash < 0 ? 0.0 : cash) * 100).round();
        final stcMinor = ((stc < 0 ? 0.0 : stc) * 100).round();
        txn.update(accountRef, {
          'currentBalanceMinor': balAfterMinor,
          'cashBalanceMinor': cashMinor,
          'stcPayBalanceMinor': stcMinor,
          'currentBalance': balAfter,
          'cashBalance': cash,
          'stcPayBalance': stc,
        });
        if (expense.ledgerEntryId != null) {
          txn.update(_txs.doc(expense.ledgerEntryId!), {'isReversed': true});
        }
      }

      final updated = expense.copyWith(
        status: ExpenseStatus.voided,
        voidedBy: actorName,
        voidedByUserId: actorUserId,
        voidedAt: now,
        voidReason: reason,
        reverseLedgerEntryId: reverseId,
        updatedAt: now,
      );
      txn.update(expRef, ExpenseModel.fromEntity(updated).toJson());
      return ExpenseModel.fromEntity(updated);
    }).then((result) async {
      await _writeAudit(
        action: 'expense.void',
        entityType: 'expense',
        entityId: expenseId,
        actorUserId: actorUserId,
        actorName: actorName,
        detail: reason,
      );
      return result;
    });
  }

  // ─── Fund accounts ──────────────────────────────────────────

  @override
  Future<List<FundAccountModel>> getAllFundAccounts() async {
    final snapshot = await _accounts.orderBy('name').get();
    return snapshot.docs
        .map((d) => FundAccountModel.fromJson(d.data()))
        .toList();
  }

  @override
  Future<void> insertFundAccount(FundAccountModel account) async {
    await _accounts.doc(account.id).set(account.toJson());
  }

  @override
  Future<void> updateFundAccount(FundAccountModel account) async {
    // Do not allow clients to overwrite balances via this path.
    // Both legacy double fields and new int minor fields are stripped.
    final data = account.toJson();
    data.remove('currentBalance');
    data.remove('cashBalance');
    data.remove('stcPayBalance');
    data.remove('currentBalanceMinor');
    data.remove('cashBalanceMinor');
    data.remove('stcPayBalanceMinor');
    await _accounts.doc(account.id).update(data);
  }

  @override
  Future<void> deactivateFundAccount(String id) async {
    await _accounts.doc(id).update({'isActive': false});
  }

  @override
  Future<void> deleteFundAccount(String id) async {
    final accSnap = await _accounts.doc(id).get();
    if (!accSnap.exists || accSnap.data() == null) return;
    final account = FundAccountModel.fromJson(accSnap.data()!);

    if (account.currentBalanceMinor > 0) {
      throw StateError(
        'Cannot close account "${account.name}" with an active balance of ${account.currentBalance.toStringAsFixed(2)} ${account.currency}. Please transfer or withdraw all funds first.',
      );
    }

    // Soft-delete only: deactivate. Hard delete blocked for posted history.
    final txs = await _txs.where('fundAccountId', isEqualTo: id).limit(1).get();
    if (txs.docs.isNotEmpty) {
      await deactivateFundAccount(id);
      return;
    }
    await _accounts.doc(id).delete();
  }

  // ─── Fund transactions ──────────────────────────────────────

  @override
  Future<List<FundTransactionModel>> getTransactionsForAccount(
    String accountId,
  ) async {
    // Equality-only query so approve/UI works without waiting for composite
    // index deploy. Optional index still speeds large accounts later.
    final snapshot =
        await _txs.where('fundAccountId', isEqualTo: accountId).get();
    final list = snapshot.docs
        .map((d) => FundTransactionModel.fromJson(d.data()))
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  @override
  Future<FundTransactionModel> postFundMovement(PostFundRequest request) async {
    if (request.amountMajor <= 0) {
      throw ArgumentError('Amount must be positive');
    }
    final movementDate = request.date ?? DateTime.now();
    await _throwIfDayLocked(request.fundAccountId, movementDate);

    return firestore.runTransaction((txn) async {
      final accountRef = _accounts.doc(request.fundAccountId);
      final accSnap = await txn.get(accountRef);
      if (!accSnap.exists || accSnap.data() == null) {
        throw StateError('Fund account not found');
      }
      final account = FundAccountModel.fromJson(accSnap.data()!);
      if (!account.isActive) {
        throw StateError('Fund account is inactive');
      }

      final amountMinor = (request.amountMajor * 100).round();
      final amountMajor = amountMinor / 100.0;
      final balBeforeMinor = account.currentBalanceMinor;
      final deltaMinor = request.credit ? amountMinor : -amountMinor;
      final balAfterMinor = balBeforeMinor + deltaMinor;
      if (balAfterMinor < 0) {
        throw StateError('Insufficient fund balance');
      }

      double cash = account.cashBalance;
      double stc = account.stcPayBalance;

      if (request.cashDeltaMajor != null) {
        cash += request.cashDeltaMajor!;
        if (cash < -1e-9) throw StateError('Insufficient cash balance');
      } else if (request.bucket == FundBucket.cash) {
        cash += request.credit ? amountMajor : -amountMajor;
        if (cash < -1e-9) throw StateError('Insufficient cash balance');
      }

      if (request.stcPayDeltaMajor != null) {
        stc += request.stcPayDeltaMajor!;
        if (stc < -1e-9) throw StateError('Insufficient STC Pay balance');
      } else if (request.bucket == FundBucket.stcPay) {
        stc += request.credit ? amountMajor : -amountMajor;
        if (stc < -1e-9) throw StateError('Insufficient STC Pay balance');
      }

      // If bucket is FundBucket.total and neither cashDelta nor stcPayDelta was explicitly set:
      if (request.cashDeltaMajor == null &&
          request.stcPayDeltaMajor == null &&
          (request.bucket == FundBucket.total ||
              (request.bucket != FundBucket.cash &&
                  request.bucket != FundBucket.stcPay))) {
        if (request.credit) {
          // Default incoming money to cash bucket
          cash += amountMajor;
        } else {
          // Outgoing money: deduct from cash first, then remainder from STC
          if (cash >= amountMajor) {
            cash -= amountMajor;
          } else {
            final remainder = amountMajor - cash;
            cash = 0;
            stc = (stc - remainder).clamp(0.0, double.infinity);
          }
        }
      }

      if (cash < 0) cash = 0;
      if (stc < 0) stc = 0;

      final balBefore = balBeforeMinor / 100.0;
      final balAfter = balAfterMinor / 100.0;
      final id = _uuid.v4();

      final tx = FundTransactionModel(
        id: id,
        fundAccountId: request.fundAccountId,
        type: request.type,
        amount: amountMajor,
        amountMinor: amountMinor,
        currency: request.currency,
        description: request.description,
        referenceExpenseId: request.referenceExpenseId,
        transferToAccountId: request.transferToAccountId,
        transferPairId: request.transferPairId,
        reversesTransactionId: request.reversesTransactionId,
        performedBy: request.performedBy,
        performedByUserId: request.performedByUserId,
        date: movementDate,
        createdAt: DateTime.now(),
        balanceBefore: balBefore,
        balanceAfter: balAfter,
        bucket: request.bucket,
        auditNote: request.auditNote,
      );

      txn.set(_txs.doc(id), tx.toJson());
      final cashMinor = ((cash < 0 ? 0.0 : cash) * 100).round();
      final stcMinor = ((stc < 0 ? 0.0 : stc) * 100).round();
      txn.update(accountRef, {
        'currentBalanceMinor': balAfterMinor,
        'cashBalanceMinor': cashMinor,
        'stcPayBalanceMinor': stcMinor,
        'currentBalance': balAfter,
        'cashBalance': cash,
        'stcPayBalance': stc,
      });
      return tx;
    });
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
    if (fromAccountId == toAccountId) {
      throw ArgumentError('Cannot transfer to the same account');
    }
    final now = DateTime.now();
    await _throwIfDayLocked(fromAccountId, now);
    await _throwIfDayLocked(toAccountId, now);
    final pairId = _uuid.v4();
    await firestore.runTransaction((txn) async {
      final fromRef = _accounts.doc(fromAccountId);
      final toRef = _accounts.doc(toAccountId);
      final fromSnap = await txn.get(fromRef);
      final toSnap = await txn.get(toRef);
      if (!fromSnap.exists || fromSnap.data() == null) {
        throw StateError('Source account not found');
      }
      if (!toSnap.exists || toSnap.data() == null) {
        throw StateError('Destination account not found');
      }
      final from = FundAccountModel.fromJson(fromSnap.data()!);
      final to = FundAccountModel.fromJson(toSnap.data()!);
      if (!from.isActive || !to.isActive) {
        throw StateError('Both accounts must be active');
      }

      final amountMinor = (amountMajor * 100).round();
      final amount = amountMinor / 100.0;
      final fromBeforeM = from.currentBalanceMinor;
      final toBeforeM = to.currentBalanceMinor;
      if (fromBeforeM < amountMinor) {
        throw StateError('Insufficient balance on source account');
      }
      final fromAfterM = fromBeforeM - amountMinor;
      final toAfterM = toBeforeM + amountMinor;

      double fromCash = from.cashBalance;
      double fromStc = from.stcPayBalance;
      double toCash = to.cashBalance;
      double toStc = to.stcPayBalance;

      if (fromBucket == FundBucket.cash) {
        if (fromCash + 1e-9 < amount) throw StateError('Insufficient cash');
        fromCash -= amount;
      } else if (fromBucket == FundBucket.stcPay) {
        if (fromStc + 1e-9 < amount) throw StateError('Insufficient STC');
        fromStc -= amount;
      }
      if (toBucket == FundBucket.cash) {
        toCash += amount;
      } else if (toBucket == FundBucket.stcPay) {
        toStc += amount;
      }

      final now = DateTime.now();
      final outId = _uuid.v4();
      final inId = _uuid.v4();

      final outTx = FundTransactionModel(
        id: outId,
        fundAccountId: fromAccountId,
        type: FundTransactionType.transfer,
        amount: amount,
        amountMinor: amountMinor,
        currency: currency,
        description: 'Transfer out → ${to.name}: $description',
        transferToAccountId: toAccountId,
        transferPairId: pairId,
        performedBy: performedBy,
        performedByUserId: performedByUserId,
        date: now,
        createdAt: now,
        balanceBefore: fromBeforeM / 100.0,
        balanceAfter: fromAfterM / 100.0,
        bucket: fromBucket,
      );
      final inTx = FundTransactionModel(
        id: inId,
        fundAccountId: toAccountId,
        type: FundTransactionType.transfer,
        amount: amount,
        amountMinor: amountMinor,
        currency: currency,
        description: 'Transfer in ← ${from.name}: $description',
        transferToAccountId: fromAccountId,
        transferPairId: pairId,
        performedBy: performedBy,
        performedByUserId: performedByUserId,
        date: now,
        createdAt: now,
        balanceBefore: toBeforeM / 100.0,
        balanceAfter: toAfterM / 100.0,
        bucket: toBucket,
      );

      txn.set(_txs.doc(outId), outTx.toJson());
      txn.set(_txs.doc(inId), inTx.toJson());
      final fromCashMinor = ((fromCash < 0 ? 0.0 : fromCash) * 100).round();
      final fromStcMinor = ((fromStc < 0 ? 0.0 : fromStc) * 100).round();
      final toCashMinor = ((toCash < 0 ? 0.0 : toCash) * 100).round();
      final toStcMinor = ((toStc < 0 ? 0.0 : toStc) * 100).round();
      txn.update(fromRef, {
        'currentBalanceMinor': fromAfterM,
        'cashBalanceMinor': fromCashMinor,
        'stcPayBalanceMinor': fromStcMinor,
        'currentBalance': fromAfterM / 100.0,
        'cashBalance': fromCash < 0 ? 0.0 : fromCash,
        'stcPayBalance': fromStc < 0 ? 0.0 : fromStc,
      });
      txn.update(toRef, {
        'currentBalanceMinor': toAfterM,
        'cashBalanceMinor': toCashMinor,
        'stcPayBalanceMinor': toStcMinor,
        'currentBalance': toAfterM / 100.0,
        'cashBalance': toCash < 0 ? 0.0 : toCash,
        'stcPayBalance': toStc < 0 ? 0.0 : toStc,
      });
    });
  }

  // ─── Petty cash ─────────────────────────────────────────────

  @override
  Future<List<PettyCashSessionModel>> getPettyCashSessions(
    String accountId,
  ) async {
    final snapshot = await firestore
        .collection('petty_cash_sessions')
        .where('fundAccountId', isEqualTo: accountId)
        .get();
    final list = snapshot.docs
        .map((d) => PettyCashSessionModel.fromJson(d.data()))
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  @override
  Future<PettyCashSessionModel?> getOpenSession(String accountId) async {
    // Prefer equality-only + filter to avoid composite index on status.
    final snapshot = await firestore
        .collection('petty_cash_sessions')
        .where('fundAccountId', isEqualTo: accountId)
        .get();
    for (final doc in snapshot.docs) {
      final s = PettyCashSessionModel.fromJson(doc.data());
      if (s.status == PettyCashSessionStatus.open) return s;
    }
    return null;
  }

  @override
  Future<void> openPettyCashSession(PettyCashSessionModel session) async {
    // Guard 1: check if day is already locked
    final locked = await isDayLocked(session.fundAccountId, session.date);
    if (locked) {
      throw StateError(
          'This account has already been verified and locked for this date. Cannot open a new session.');
    }

    // Guard 2: check if any session already exists for this calendar day
    final allSessions = await getPettyCashSessions(session.fundAccountId);
    final targetDay =
        DateTime(session.date.year, session.date.month, session.date.day);
    for (final s in allSessions) {
      final sDay = DateTime(s.date.year, s.date.month, s.date.day);
      if (sDay == targetDay) {
        if (s.status == PettyCashSessionStatus.verified) {
          throw StateError(
              'Today\'s session has already been verified and locked.');
        }
        if (s.status == PettyCashSessionStatus.closed) {
          throw StateError(
              'Today\'s session has already been closed. A daily register can only be opened once per day.');
        }
        if (s.status == PettyCashSessionStatus.open) {
          throw StateError('An open session already exists for this account');
        }
      }
    }

    // Snapshot live balances from the ledger inside a transaction so the
    // opening balance cannot be tampered with by the client.
    await firestore.runTransaction((txn) async {
      final lockId = DayLockEntity.lockId(session.fundAccountId, session.date);
      final lockSnap = await txn.get(_dayLocks.doc(lockId));
      if (lockSnap.exists) {
        throw StateError('Day is already locked for this account');
      }

      final sessionRef = firestore
          .collection('petty_cash_sessions')
          .doc(session.id);

      // Re-check for sessions for this day inside the transaction (race guard).
      final existing = await firestore
          .collection('petty_cash_sessions')
          .where('fundAccountId', isEqualTo: session.fundAccountId)
          .get();
      for (final doc in existing.docs) {
        final s = PettyCashSessionModel.fromJson(doc.data());
        final sDay = DateTime(s.date.year, s.date.month, s.date.day);
        if (sDay == targetDay) {
          throw StateError('A session already exists for this date');
        }
      }

      final accSnap = await txn.get(_accounts.doc(session.fundAccountId));
      if (!accSnap.exists || accSnap.data() == null) {
        throw StateError('Fund account not found');
      }
      final account = FundAccountModel.fromJson(accSnap.data()!);
      if (!account.isActive) {
        throw StateError('Fund account is inactive');
      }

      // Override client-supplied opening balances with the authoritative
      // ledger snapshot. This ensures expectedClosingBalance is grounded
      // in actual money, not whatever the user typed.
      final snapshotted = PettyCashSessionModel.fromEntity(
        session.copyWith(
          openingCashBalance: account.cashBalance,
          openingStcPayBalance: account.stcPayBalance,
        ),
      );

      txn.set(sessionRef, snapshotted.toJson());
    });

    await _writeAudit(
      action: 'petty_cash.open',
      entityType: 'petty_cash_session',
      entityId: session.id,
      actorName: session.openedBy,
      detail: 'fundAccount=${session.fundAccountId}',
    );
  }

  @override
  Future<PettyCashSessionModel> closePettyCashSession({
    required PettyCashSessionModel session,
    required String closedBy,
    required String? closedByUserId,
  }) async {
    if (session.status != PettyCashSessionStatus.open) {
      throw StateError('Only open sessions can be closed');
    }
    final totals = await getLedgerDayTotals(
      session.fundAccountId,
      session.date,
      sessionOpenedAt: session.createdAt,
    );
    final closed = session.copyWith(
      cashDeposits: totals.cashDeposits,
      stcPayDeposits: totals.stcPayDeposits,
      cashExpenses: totals.cashExpenses,
      stcPayExpenses: totals.stcPayExpenses,
      closedBy: closedBy,
      status: PettyCashSessionStatus.closed,
      discrepancy: session.closingBalance -
          (session.openingCashBalance +
              session.openingStcPayBalance +
              totals.cashDeposits +
              totals.stcPayDeposits -
              totals.cashExpenses -
              totals.stcPayExpenses),
    );
    // Fix expected using recomputed deposits/expenses
    final expected = closed.expectedClosingBalance;
    final withDisc = closed.copyWith(
      discrepancy: session.closingBalance - expected,
    );
    await firestore
        .collection('petty_cash_sessions')
        .doc(session.id)
        .update(PettyCashSessionModel.fromEntity(withDisc).toJson());
    await _writeAudit(
      action: 'petty_cash.close',
      entityType: 'petty_cash_session',
      entityId: session.id,
      actorUserId: closedByUserId,
      actorName: closedBy,
      detail:
          'disc=${withDisc.discrepancy?.toStringAsFixed(2)} expected=$expected',
    );
    return PettyCashSessionModel.fromEntity(withDisc);
  }

  @override
  Future<void> verifyPettyCashSession({
    required String sessionId,
    required String verifiedBy,
    required String? verifiedByUserId,
  }) async {
    final ref = firestore.collection('petty_cash_sessions').doc(sessionId);
    final snap = await ref.get();
    if (!snap.exists || snap.data() == null) {
      throw StateError('Session not found');
    }
    final session = PettyCashSessionModel.fromJson(snap.data()!);
    if (session.status != PettyCashSessionStatus.closed) {
      throw StateError('Only closed sessions can be verified');
    }
    final now = DateTime.now();
    final lockId = DayLockEntity.lockId(session.fundAccountId, session.date);
    final dayKey = DayLockEntity.dayKeyFrom(session.date);

    await firestore.runTransaction((txn) async {
      txn.update(ref, {
        'status': 'verified',
        'verifiedBy': verifiedBy,
        'verifiedAt': now.toIso8601String(),
      });
      txn.set(_dayLocks.doc(lockId), {
        'id': lockId,
        'fundAccountId': session.fundAccountId,
        'dayKey': dayKey,
        'day': DateTime(session.date.year, session.date.month, session.date.day)
            .toIso8601String(),
        'lockedBy': verifiedBy,
        'lockedByUserId': verifiedByUserId,
        'lockedAt': now.toIso8601String(),
        'sessionId': sessionId,
        'reason': 'Petty cash day verified',
      });
    });
    await _writeAudit(
      action: 'petty_cash.verify_and_lock',
      entityType: 'petty_cash_session',
      entityId: sessionId,
      actorUserId: verifiedByUserId,
      actorName: verifiedBy,
      detail: 'dayLock=$lockId',
    );
  }

  @override
  Future<LedgerDayTotals> getLedgerDayTotals(
    String accountId,
    DateTime day, {
    DateTime? sessionOpenedAt,
  }) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    // Fetch account txs and filter in memory (avoids composite index issues).
    final all = await getTransactionsForAccount(accountId);
    double cashIn = 0, stcIn = 0, cashOut = 0, stcOut = 0, otherIn = 0, otherOut = 0;
    for (final tx in all) {
      if (tx.isReversed) continue;
      if (tx.date.isBefore(start) || !tx.date.isBefore(end)) continue;
      // If sessionOpenedAt is provided, only count transactions created
      // AFTER the session was opened. Pre-session transactions are already
      // captured in the session's opening balance snapshot.
      if (sessionOpenedAt != null && tx.createdAt.isBefore(sessionOpenedAt)) {
        continue;
      }

      // Reversals (e.g. voided expense payments) are skipped entirely.
      // The original transaction is already excluded via isReversed=true,
      // so skipping the reversal too means the voided pair cancels out
      // cleanly — as if the transaction never happened.
      if (tx.type == FundTransactionType.reversal) {
        continue;
      }

      final isIn = tx.type == FundTransactionType.deposit ||
          (tx.type == FundTransactionType.transfer &&
              tx.balanceAfter > tx.balanceBefore);
      final isOut = tx.type == FundTransactionType.withdrawal ||
          tx.type == FundTransactionType.expensePayment ||
          (tx.type == FundTransactionType.transfer &&
              tx.balanceAfter < tx.balanceBefore);
      if (isIn) {
        if (tx.bucket == FundBucket.cash) {
          cashIn += tx.amount;
        } else if (tx.bucket == FundBucket.stcPay) {
          stcIn += tx.amount;
        } else {
          // Split unknown total evenly attribution: treat as cash for petty
          cashIn += tx.amount;
        }
      } else if (isOut) {
        if (tx.bucket == FundBucket.cash) {
          cashOut += tx.amount;
        } else if (tx.bucket == FundBucket.stcPay) {
          stcOut += tx.amount;
        } else {
          cashOut += tx.amount;
        }
      } else if (tx.type == FundTransactionType.adjustment) {
        if (tx.balanceAfter >= tx.balanceBefore) {
          otherIn += tx.amount;
        } else {
          otherOut += tx.amount;
        }
      }
    }
    return LedgerDayTotals(
      cashDeposits: cashIn,
      stcPayDeposits: stcIn,
      cashExpenses: cashOut,
      stcPayExpenses: stcOut,
      otherIn: otherIn,
      otherOut: otherOut,
    );
  }

  @override
  Future<bool> isDayLocked(String fundAccountId, DateTime day) async {
    final id = DayLockEntity.lockId(fundAccountId, day);
    final snap = await _dayLocks.doc(id).get();
    return snap.exists;
  }

  // ─── Advances ───────────────────────────────────────────────

  @override
  Future<List<CashAdvanceModel>> getCashAdvances({String? fundAccountId}) async {
    QuerySnapshot<Map<String, dynamic>> snap;
    if (fundAccountId != null) {
      snap = await _advances
          .where('fundAccountId', isEqualTo: fundAccountId)
          .get();
    } else {
      snap = await _advances.get();
    }
    final list =
        snap.docs.map((d) => CashAdvanceModel.fromJson(d.data())).toList();
    list.sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
    return list;
  }

  @override
  Future<CashAdvanceModel> issueCashAdvance({
    required CashAdvanceModel advance,
  }) async {
    // Prefer total-balance deduction so non-split wallets work.
    final tx = await postFundMovement(
      PostFundRequest(
        fundAccountId: advance.fundAccountId,
        type: FundTransactionType.withdrawal,
        amountMajor: advance.amount,
        currency: advance.currency,
        description:
            'Advance to ${advance.employeeName}: ${advance.purpose}',
        performedBy: advance.issuedBy,
        performedByUserId: advance.issuedByUserId,
        bucket: FundBucket.total,
        credit: false,
        auditNote: 'cash_advance:${advance.id}',
      ),
    );
    final withLedger = CashAdvanceModel(
      id: advance.id,
      fundAccountId: advance.fundAccountId,
      fundAccountName: advance.fundAccountName,
      employeeId: advance.employeeId,
      employeeName: advance.employeeName,
      amount: advance.amount,
      amountMinor: advance.resolvedAmountMinor,
      settledAmount: 0,
      currency: advance.currency,
      purpose: advance.purpose,
      status: CashAdvanceStatus.open,
      issuedBy: advance.issuedBy,
      issuedByUserId: advance.issuedByUserId,
      issuedAt: advance.issuedAt,
      issueLedgerEntryId: tx.id,
      notes: advance.notes,
      createdAt: advance.createdAt,
    );
    await _advances.doc(advance.id).set(withLedger.toJson());
    await _writeAudit(
      action: 'advance.issue',
      entityType: 'cash_advance',
      entityId: advance.id,
      actorUserId: advance.issuedByUserId,
      actorName: advance.issuedBy,
      detail: '${advance.amount} to ${advance.employeeName}',
    );
    return withLedger;
  }

  @override
  Future<CashAdvanceModel> settleCashAdvance({
    required String advanceId,
    required double settleAmountMajor,
    required String actorName,
    required String actorUserId,
    required bool returnToFund,
  }) async {
    if (settleAmountMajor <= 0) {
      throw ArgumentError('Settle amount must be positive');
    }
    final snap = await _advances.doc(advanceId).get();
    if (!snap.exists || snap.data() == null) {
      throw StateError('Advance not found');
    }
    final advance = CashAdvanceModel.fromJson(snap.data()!);
    if (!advance.isOpen) {
      throw StateError('Advance is not open');
    }
    final outstanding = advance.outstanding;
    if (settleAmountMajor > outstanding + 1e-9) {
      throw StateError('Settle amount exceeds outstanding $outstanding');
    }

    if (returnToFund) {
      await postFundMovement(
        PostFundRequest(
          fundAccountId: advance.fundAccountId,
          type: FundTransactionType.deposit,
          amountMajor: settleAmountMajor,
          currency: advance.currency,
          description:
              'Advance settlement from ${advance.employeeName}',
          performedBy: actorName,
          performedByUserId: actorUserId,
          bucket: FundBucket.total,
          credit: true,
          auditNote: 'cash_advance_settle:${advance.id}',
        ),
      );
    }

    final newSettled = advance.settledAmount + settleAmountMajor;
    final fully = newSettled + 1e-9 >= advance.amount;
    final updated = CashAdvanceModel(
      id: advance.id,
      fundAccountId: advance.fundAccountId,
      fundAccountName: advance.fundAccountName,
      employeeId: advance.employeeId,
      employeeName: advance.employeeName,
      amount: advance.amount,
      amountMinor: advance.amountMinor,
      settledAmount: newSettled,
      currency: advance.currency,
      purpose: advance.purpose,
      status: fully
          ? CashAdvanceStatus.settled
          : CashAdvanceStatus.partiallySettled,
      issuedBy: advance.issuedBy,
      issuedByUserId: advance.issuedByUserId,
      issuedAt: advance.issuedAt,
      issueLedgerEntryId: advance.issueLedgerEntryId,
      settledAt: fully ? DateTime.now() : advance.settledAt,
      notes: advance.notes,
      createdAt: advance.createdAt,
    );
    await _advances.doc(advanceId).update(_stripNulls(updated.toJson()));
    return updated;
  }

  @override
  Future<CashAdvanceModel> writeOffCashAdvance({
    required String advanceId,
    required String reason,
    required String actorName,
    required String actorUserId,
  }) async {
    final trimmed = reason.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Write-off reason is required');
    }
    final snap = await _advances.doc(advanceId).get();
    if (!snap.exists || snap.data() == null) {
      throw StateError('Advance not found');
    }
    final advance = CashAdvanceModel.fromJson(snap.data()!);
    if (!advance.isOpen) {
      throw StateError('Only open advances can be written off');
    }
    final outstanding = advance.outstanding;
    if (outstanding <= 1e-9) {
      throw StateError('Nothing left to write off');
    }

    final note = [
      if (advance.notes != null && advance.notes!.isNotEmpty) advance.notes,
      'WRITE-OFF ${outstanding.toStringAsFixed(2)} ${advance.currency} '
          'by $actorName: $trimmed',
    ].join('\n');

    final updated = CashAdvanceModel(
      id: advance.id,
      fundAccountId: advance.fundAccountId,
      fundAccountName: advance.fundAccountName,
      employeeId: advance.employeeId,
      employeeName: advance.employeeName,
      amount: advance.amount,
      amountMinor: advance.amountMinor,
      settledAmount: advance.settledAmount,
      currency: advance.currency,
      purpose: advance.purpose,
      status: CashAdvanceStatus.writtenOff,
      issuedBy: advance.issuedBy,
      issuedByUserId: advance.issuedByUserId,
      issuedAt: advance.issuedAt,
      issueLedgerEntryId: advance.issueLedgerEntryId,
      settledAt: DateTime.now(),
      notes: note,
      createdAt: advance.createdAt,
    );
    await _advances.doc(advanceId).update(_stripNulls(updated.toJson()));
    await _writeAudit(
      action: 'advance.write_off',
      entityType: 'cash_advance',
      entityId: advanceId,
      actorUserId: actorUserId,
      actorName: actorName,
      detail: 'outstanding=$outstanding reason=$trimmed',
    );
    return updated;
  }

  // ─── Policy (with 5-minute memory cache) ───────────────────

  FinancePolicyEntity? _cachedPolicy;
  DateTime? _policyCachedAt;
  static const _policyCacheDuration = Duration(minutes: 5);

  @override
  Future<FinancePolicyEntity> getFinancePolicy() async {
    if (_cachedPolicy != null &&
        _policyCachedAt != null &&
        DateTime.now().difference(_policyCachedAt!) < _policyCacheDuration) {
      return _cachedPolicy!;
    }
    final snap = await _policyDoc.get();
    if (!snap.exists) {
      _cachedPolicy = const FinancePolicyEntity();
    } else {
      _cachedPolicy = FinancePolicyEntity.fromJson(snap.data());
    }
    _policyCachedAt = DateTime.now();
    return _cachedPolicy!;
  }

  @override
  Future<void> saveFinancePolicy(FinancePolicyEntity policy) async {
    _cachedPolicy = policy;
    _policyCachedAt = DateTime.now();
    await _policyDoc.set(policy.toJson(), SetOptions(merge: true));
  }

  @override
  Future<String> uploadClosingSheet(XFile file, String sessionId) async {
    final ext = file.name.split('.').last;
    final ref = storage.ref('petty_cash/$sessionId/closing_sheet.$ext');
    final bytes = await file.readAsBytes();
    final metadata = SettableMetadata(contentType: _getMimeType(ext));
    await ref.putData(bytes, metadata);
    return ref.getDownloadURL();
  }

  // ─── Categories ─────────────────────────────────────────────

  @override
  Future<List<ExpenseCategoryModel>> getExpenseCategories() async {
    final snapshot =
        await firestore.collection('expense_categories').orderBy('name').get();
    return snapshot.docs
        .map((d) => ExpenseCategoryModel.fromJson(d.data()))
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

  // ─── Account Types ──────────────────────────────────────────

  @override
  Future<List<FundAccountTypeModel>> getFundAccountTypes() async {
    final snapshot = await firestore
        .collection('fund_account_types')
        .orderBy('createdAt')
        .get();

    if (snapshot.docs.isEmpty) {
      // Auto-seed default types (Bank, Petty Cash, STC Pay)
      final defaults = FundAccountTypeEntity.defaultTypes
          .map((e) => FundAccountTypeModel.fromEntity(e))
          .toList();
      for (final d in defaults) {
        await firestore
            .collection('fund_account_types')
            .doc(d.id)
            .set(d.toJson());
      }
      return defaults;
    }

    final loaded = snapshot.docs
        .map((d) => FundAccountTypeModel.fromJson(d.data()))
        .toList();

    // Ensure all system default types exist if not present in collection
    final loadedIds = loaded.map((e) => e.id).toSet();
    final missingDefaults = FundAccountTypeEntity.defaultTypes
        .where((d) => !loadedIds.contains(d.id))
        .map((e) => FundAccountTypeModel.fromEntity(e))
        .toList();

    for (final d in missingDefaults) {
      await firestore
          .collection('fund_account_types')
          .doc(d.id)
          .set(d.toJson());
      loaded.add(d);
    }

    return loaded;
  }

  @override
  Future<void> insertFundAccountType(FundAccountTypeModel type) async {
    await firestore
        .collection('fund_account_types')
        .doc(type.id)
        .set(type.toJson());
  }

  @override
  Future<void> updateFundAccountType(FundAccountTypeModel type) async {
    await firestore
        .collection('fund_account_types')
        .doc(type.id)
        .update(type.toJson());
  }

  @override
  Future<void> deleteFundAccountType(String id) async {
    await firestore.collection('fund_account_types').doc(id).delete();
  }

  // ─── Helpers ────────────────────────────────────────────────

  FundBucket _bucketFromPaymentMethod(String method) {
    final m = method.toLowerCase();
    if (m == 'cash') return FundBucket.cash;
    if (m.contains('stc')) return FundBucket.stcPay;
    return FundBucket.total;
  }

  /// Prefer cash/STC split when those buckets are funded; otherwise total-only.
  /// Avoids approve failing when deposits only raised [currentBalance].
  FundBucket _resolvePaymentBucket({
    required String paymentMethod,
    required double cashBalance,
    required double stcPayBalance,
  }) {
    final preferred = _bucketFromPaymentMethod(paymentMethod);
    final usesSplit = cashBalance > 1e-9 || stcPayBalance > 1e-9;
    if (!usesSplit) return FundBucket.total;
    return preferred;
  }

  /// Firestore [update] rejects null field values (especially on web).
  Map<String, dynamic> _stripNulls(Map<String, dynamic> data) {
    final out = <String, dynamic>{};
    data.forEach((key, value) {
      if (value != null) out[key] = value;
    });
    return out;
  }

  String _unwrapFirebaseError(Object e) {
    final s = e.toString();
    // Flutter web wraps real errors in this opaque message.
    if (s.contains('Dart exception thrown from converted Future') ||
        s.contains('Stacktrace: null')) {
      try {
        // ignore: avoid_dynamic_calls
        final dynamic d = e;
        final inner = d.error;
        if (inner != null) return inner.toString();
      } catch (_) {}
    }
    if (s.contains('permission-denied')) {
      return 'Permission denied. Check you are logged in and your '
          'allowed_users role can update expenses/fund_accounts.';
    }
    if (s.contains('failed-precondition')) {
      return 'Firestore precondition failed (often a missing index or '
          'stale transaction). Retry once. Details: $s';
    }
    return s
        .replaceFirst('StateError: ', '')
        .replaceFirst('Exception: ', '')
        .replaceFirst('Bad state: ', '');
  }

  Future<void> _throwIfDayLocked(String fundAccountId, DateTime day) async {
    if (await isDayLocked(fundAccountId, day)) {
      final key = DayLockEntity.dayKeyFrom(day);
      throw StateError(
        'Day $key is locked for this fund account after petty cash verification. '
        'No new money posts allowed.',
      );
    }
  }

  void _assertExpensePolicy(ExpenseEntity expense, FinancePolicyEntity policy) {
    if (expense.amount >= policy.receiptRequiredAbove &&
        expense.receiptUrls.isEmpty) {
      throw StateError(
        'Receipt required for amounts >= ${policy.receiptRequiredAbove}',
      );
    }
    final type = expense.expenseType.toUpperCase();
    if (policy.requireVehicleForFuel &&
        type.contains('FUEL') &&
        (expense.vehicleId == null || expense.vehicleId!.isEmpty)) {
      throw StateError('Vehicle is required for fuel expenses');
    }
    if (policy.requireEmployeeForSalary &&
        (type.contains('SALARY') || type.contains('PAYROLL')) &&
        (expense.employeeId == null || expense.employeeId!.isEmpty)) {
      throw StateError('Employee is required for salary expenses');
    }
  }

  @override
  Future<void> resetFinanceModuleData() async {
    final collections = [
      _expenses,
      _txs,
      _accounts,
      _advances,
      _dayLocks,
      firestore.collection('petty_cash_sessions'),
      firestore.collection('finance_audits'),
    ];

    for (final col in collections) {
      final snap = await col.get();
      for (var i = 0; i < snap.docs.length; i += 400) {
        final chunk = snap.docs.sublist(
          i,
          i + 400 > snap.docs.length ? snap.docs.length : i + 400,
        );
        final batch = firestore.batch();
        for (final doc in chunk) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }
    _cachedPolicy = null;
    _policyCachedAt = null;
  }

  Future<void> _writeAudit({
    required String action,
    required String entityType,
    required String entityId,
    String? actorUserId,
    String? actorName,
    String? detail,
  }) async {
    try {
      await _audit.add({
        'action': action,
        'entityType': entityType,
        'entityId': entityId,
        'actorUserId': actorUserId,
        'actorName': actorName,
        'detail': detail,
        'createdAt': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Audit must not block money ops.
    }
  }

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
