import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/features/finance/domain/entities/expense_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/finance_report.dart';
import 'package:xloop_invoice/features/finance/domain/entities/fund_account_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/fund_transaction_entity.dart';
import 'package:xloop_invoice/features/finance/domain/services/finance_report_builder.dart';
import 'package:xloop_invoice/features/finance/domain/services/finance_report_file_service.dart';

FundAccountEntity _account(String id, String name) => FundAccountEntity(
      id: id,
      name: name,
      code: id.toUpperCase(),
      type: FundAccountType.pettyCash,
      currency: 'SAR',
      createdAt: DateTime(2026),
    );

int _seq = 0;

FundTransactionEntity _tx(
  String accountId,
  DateTime date,
  double before,
  double after, {
  FundTransactionType type = FundTransactionType.deposit,
  String? counterparty,
  String description = 'Movement',
}) {
  _seq++;
  return FundTransactionEntity(
    id: 'tx$_seq',
    referenceNumber: 'TXN-${10000 + _seq}',
    fundAccountId: accountId,
    type: type,
    amount: (after - before).abs(),
    currency: 'SAR',
    description: description,
    transferToAccountId: counterparty,
    performedBy: 'Admin',
    date: date,
    createdAt: date,
    balanceBefore: before,
    balanceAfter: after,
  );
}

ExpenseEntity _expense(
  String id,
  String accountId,
  DateTime date,
  double amount, {
  ExpenseStatus status = ExpenseStatus.paid,
  String category = 'Fuel',
  String? employee,
}) =>
    ExpenseEntity(
      id: id,
      referenceNumber: 'EXP-$id',
      date: date,
      createdAt: date,
      submittedBy: 'Admin',
      submittedByRole: 'admin',
      expenseCategory: category,
      expenseType: '$category type',
      amount: amount,
      currency: 'SAR',
      fundAccountId: accountId,
      status: status,
      employeeName: employee,
    );

void main() {
  final main = _account('main', 'Main Wallet');
  final petty = _account('petty', 'Petty Cash');
  final accounts = [main, petty];

  // Main: +1000 (Oct), transfer 300 to petty (Nov 5), expense 50 (Nov 10).
  // Petty: +300 transfer in (Nov 5), expense 20 (Nov 12), +40 deposit (Dec 1).
  final txs = [
    _tx('main', DateTime(2026, 10, 1), 0, 1000),
    _tx('main', DateTime(2026, 11, 5), 1000, 700,
        type: FundTransactionType.transfer, counterparty: 'petty'),
    _tx('petty', DateTime(2026, 11, 5), 0, 300,
        type: FundTransactionType.transfer, counterparty: 'main'),
    _tx('main', DateTime(2026, 11, 10), 700, 650,
        type: FundTransactionType.expensePayment, description: 'Fuel pump'),
    _tx('petty', DateTime(2026, 11, 12, 23, 30), 300, 280,
        type: FundTransactionType.expensePayment),
    _tx('petty', DateTime(2026, 12, 1), 280, 320),
  ];

  final november = FinanceReportFilter(
    from: DateTime(2026, 11, 1),
    to: DateTime(2026, 11, 30),
  );

  group('buildLedger', () {
    test('opening, in, out and closing per account for the period', () {
      final r = FinanceReportBuilder.buildLedger(
        filter: november,
        accounts: accounts,
        allTransactions: txs,
      );
      final m = r.accounts.firstWhere((a) => a.accountId == 'main');
      final p = r.accounts.firstWhere((a) => a.accountId == 'petty');
      expect(m.opening, 1000);
      expect(m.moneyIn, 0);
      expect(m.moneyOut, 350);
      expect(m.closing, 650);
      expect(p.opening, 0);
      expect(p.moneyIn, 300);
      expect(p.moneyOut, 20);
      expect(p.closing, 280);
      // The Dec 1 deposit and Oct 1 deposit are outside the period.
      expect(r.rows, hasLength(4));
      expect(r.totalIn, 300);
      expect(r.totalOut, 370);
    });

    test('the "to" day is included up to midnight', () {
      final r = FinanceReportBuilder.buildLedger(
        filter: FinanceReportFilter(
          from: DateTime(2026, 11, 12),
          to: DateTime(2026, 11, 12),
        ),
        accounts: accounts,
        allTransactions: txs,
      );
      expect(r.rows.single.tx.fundAccountId, 'petty');
    });

    test('row filters do not change account balances', () {
      final r = FinanceReportBuilder.buildLedger(
        filter: november.copyWith(
          direction: LedgerDirection.moneyOut,
          transactionTypes: {FundTransactionType.expensePayment},
          search: 'fuel',
        ),
        accounts: accounts,
        allTransactions: txs,
      );
      expect(r.rows.single.tx.description, 'Fuel pump');
      expect(r.accounts.firstWhere((a) => a.accountId == 'main').closing, 650);
    });

    test('account filter limits rows and balances to that account', () {
      final r = FinanceReportBuilder.buildLedger(
        filter: november.copyWith(accountIds: {'petty'}),
        accounts: accounts,
        allTransactions: txs,
      );
      expect(r.accounts.map((a) => a.accountId), ['petty']);
      expect(r.rows.every((row) => row.accountName == 'Petty Cash'), isTrue);
      // Transfer from Main counts as income for Petty on its own.
      expect(r.rows.first.counterpartyName, isNull);
      final transferIn = r.rows.firstWhere(
          (row) => row.tx.type == FundTransactionType.transfer);
      expect(transferIn.counterpartyName, 'Main Wallet');
      expect(transferIn.moneyIn, 300);
    });

    test('income hides internal transfers between selected accounts', () {
      final income = FinanceReportBuilder.buildLedger(
        filter: FinanceReportFilter(
          type: FinanceReportType.income,
          excludeInternalTransfers: true,
        ),
        accounts: accounts,
        allTransactions: txs,
      );
      expect(income.rows.map((r) => r.tx.type),
          everyElement(FundTransactionType.deposit));
      expect(income.totalIn, 1040);

      final pettyOnly = FinanceReportBuilder.buildLedger(
        filter: FinanceReportFilter(
          type: FinanceReportType.income,
          excludeInternalTransfers: true,
          accountIds: {'petty'},
        ),
        accounts: accounts,
        allTransactions: txs,
      );
      // Main is not selected, so its transfer into Petty is income here.
      expect(pettyOnly.totalIn, 340);
    });

    test('ignores accounts the user may not report on', () {
      final r = FinanceReportBuilder.buildLedger(
        filter: const FinanceReportFilter(),
        accounts: [petty],
        allTransactions: txs,
      );
      expect(r.rows.every((row) => row.tx.fundAccountId == 'petty'), isTrue);
    });
  });

  group('buildExpenses', () {
    final expenses = [
      _expense('1', 'main', DateTime(2026, 11, 3), 100, employee: 'Ali'),
      _expense('2', 'petty', DateTime(2026, 11, 4), 40,
          status: ExpenseStatus.pending, category: 'Food'),
      _expense('3', 'petty', DateTime(2026, 11, 20), 50,
          status: ExpenseStatus.rejected, category: 'Food'),
      _expense('4', '', DateTime(2026, 11, 21), 25,
          status: ExpenseStatus.approved),
      _expense('5', 'main', DateTime(2026, 12, 2), 999),
    ];

    test('totals by status and group', () {
      final r = FinanceReportBuilder.buildExpenses(
        filter: november.copyWith(type: FinanceReportType.expenses),
        accounts: accounts,
        allExpenses: expenses,
        includeUnassigned: true,
      );
      expect(r.rows.map((e) => e.id), ['4', '3', '2', '1']);
      expect(r.total, 215);
      expect(r.paidTotal, 100);
      expect(r.outstandingTotal, 65);
      expect(r.rejectedOrVoidedTotal, 50);
      expect(r.byCategory.first.label, 'Fuel');
      expect(r.byCategory.first.amount, 125);
      expect(r.byAccount.map((g) => g.label), contains('No account'));
    });

    test('non-admins only see expenses of their accounts', () {
      final r = FinanceReportBuilder.buildExpenses(
        filter: const FinanceReportFilter(type: FinanceReportType.expenses),
        accounts: [petty],
        allExpenses: expenses,
      );
      expect(r.rows.map((e) => e.id).toSet(), {'2', '3'});
    });

    test('status, category and employee filters combine', () {
      final r = FinanceReportBuilder.buildExpenses(
        filter: const FinanceReportFilter(
          type: FinanceReportType.expenses,
          statuses: {ExpenseStatus.paid},
          categories: {'Fuel'},
          employees: {'Ali'},
        ),
        accounts: accounts,
        allExpenses: expenses,
        includeUnassigned: true,
      );
      expect(r.rows.map((e) => e.id), ['1']);
    });
  });

  group('export files', () {
    test('ledger report renders as Excel and PDF', () async {
      final report = FinanceReportBuilder.buildLedger(
        filter: november,
        accounts: accounts,
        allTransactions: txs,
      );
      final doc = FinanceReportBuilder.ledgerDocument(
        filter: november,
        report: report,
        accounts: accounts,
        generatedBy: 'Tester',
        now: DateTime(2026, 11, 24, 15, 30),
      );
      expect(doc.filterLines.first, 'Period: 01 Nov 2026 – 30 Nov 2026');
      expect(FinanceReportFileService.fileBaseName(doc),
          'Account_Activity_Report_2026-11-24_1530');

      final xlsx = FinanceReportFileService.buildExcel(doc);
      expect(xlsx.sublist(0, 2), [0x50, 0x4B]); // ZIP container
      final pdf = await FinanceReportFileService.buildPdf(doc);
      expect(String.fromCharCodes(pdf.sublist(0, 4)), '%PDF');
    });

    test('expense report renders as Excel and PDF', () async {
      final filter = november.copyWith(type: FinanceReportType.expenses);
      final report = FinanceReportBuilder.buildExpenses(
        filter: filter,
        accounts: accounts,
        allExpenses: [
          _expense('1', 'main', DateTime(2026, 11, 3), 100, employee: 'Ali'),
        ],
      );
      final doc = FinanceReportBuilder.expenseDocument(
        filter: filter,
        report: report,
        accounts: accounts,
        generatedBy: 'Tester',
      );
      expect(FinanceReportFileService.buildExcel(doc), isNotEmpty);
      expect(await FinanceReportFileService.buildPdf(doc), isNotEmpty);
    });
  });
}
