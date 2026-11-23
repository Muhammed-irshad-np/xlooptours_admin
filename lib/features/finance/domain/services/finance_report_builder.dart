import 'package:intl/intl.dart';

import '../entities/expense_entity.dart';
import '../entities/finance_report.dart';
import '../entities/fund_account_entity.dart';
import '../entities/fund_transaction_entity.dart';

/// Pure filtering and totals behind the Finance → Reports tab.
///
/// Everything here works on lists already in memory, so the screen can
/// re-run it on every filter change.
class FinanceReportBuilder {
  FinanceReportBuilder._();

  /// Signed balance change of a ledger row (positive = money in).
  static double deltaOf(FundTransactionEntity tx) =>
      ((tx.balanceAfter - tx.balanceBefore) * 100).roundToDouble() / 100;

  static String paymentMethodLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Cash';
      case 'stcPay':
        return 'STC Pay';
      case '':
        return '—';
      default:
        return method[0].toUpperCase() + method.substring(1);
    }
  }

  // ─── Ledger ──────────────────────────────────────────────────────────

  /// Builds an Account Activity or Income report.
  ///
  /// [accounts] are the accounts the user may report on; [filter.accountIds]
  /// narrows them further. [allTransactions] must hold the full history so
  /// opening balances are right.
  static LedgerReport buildLedger({
    required FinanceReportFilter filter,
    required List<FundAccountEntity> accounts,
    required List<FundTransactionEntity> allTransactions,
  }) {
    final selected = filter.accountIds.isEmpty
        ? accounts
        : accounts.where((a) => filter.accountIds.contains(a.id)).toList();
    final selectedIds = {for (final a in selected) a.id};
    final names = {for (final a in accounts) a.id: a.name};

    final start = filter.fromStart;
    final opening = <String, double>{for (final id in selectedIds) id: 0};
    final inByAcc = <String, double>{for (final id in selectedIds) id: 0};
    final outByAcc = <String, double>{for (final id in selectedIds) id: 0};
    final countByAcc = <String, int>{for (final id in selectedIds) id: 0};

    final rows = <LedgerReportRow>[];
    final query = filter.search.trim().toLowerCase();
    final isIncome = filter.type == FinanceReportType.income;

    for (final tx in allTransactions) {
      if (!selectedIds.contains(tx.fundAccountId)) continue;
      final delta = deltaOf(tx);

      // Accounts start at zero, so the balance at any moment is the sum of
      // every earlier change.
      if (start != null && tx.date.isBefore(start)) {
        opening[tx.fundAccountId] = opening[tx.fundAccountId]! + delta;
        continue;
      }
      if (!filter.includesDate(tx.date)) continue;

      if (delta > 0) {
        inByAcc[tx.fundAccountId] = inByAcc[tx.fundAccountId]! + delta;
      } else if (delta < 0) {
        outByAcc[tx.fundAccountId] = outByAcc[tx.fundAccountId]! - delta;
      }
      countByAcc[tx.fundAccountId] = countByAcc[tx.fundAccountId]! + 1;

      // ── Row filters (do not affect the balances above) ──
      if (isIncome && delta <= 0) continue;
      if (!isIncome) {
        if (filter.direction == LedgerDirection.moneyIn && delta <= 0) {
          continue;
        }
        if (filter.direction == LedgerDirection.moneyOut && delta >= 0) {
          continue;
        }
      }
      if (filter.transactionTypes.isNotEmpty &&
          !filter.transactionTypes.contains(tx.type)) {
        continue;
      }
      final counterpartyId = tx.type == FundTransactionType.transfer
          ? tx.transferToAccountId
          : null;
      if (filter.excludeInternalTransfers &&
          counterpartyId != null &&
          selectedIds.contains(counterpartyId)) {
        continue;
      }
      final accountName = names[tx.fundAccountId] ?? 'Unknown account';
      final counterpartyName =
          counterpartyId == null ? null : (names[counterpartyId] ?? '—');
      if (query.isNotEmpty &&
          ![
            tx.displayReference,
            tx.description,
            tx.performedBy,
            accountName,
            counterpartyName ?? '',
            tx.type.displayName,
          ].any((s) => s.toLowerCase().contains(query))) {
        continue;
      }

      rows.add(LedgerReportRow(
        tx: tx,
        accountName: accountName,
        counterpartyName: counterpartyName,
        moneyIn: delta > 0 ? delta : 0,
        moneyOut: delta < 0 ? -delta : 0,
      ));
    }

    rows.sort((a, b) {
      final byDate = b.tx.date.compareTo(a.tx.date);
      return byDate != 0 ? byDate : b.tx.createdAt.compareTo(a.tx.createdAt);
    });

    final summaries = [
      for (final a in selected)
        AccountPeriodSummary(
          accountId: a.id,
          accountName: a.name,
          accountCode: a.code,
          opening: _round(opening[a.id]!),
          moneyIn: _round(inByAcc[a.id]!),
          moneyOut: _round(outByAcc[a.id]!),
          entries: countByAcc[a.id]!,
        ),
    ];

    return LedgerReport(rows: rows, accounts: summaries);
  }

  // ─── Expenses ────────────────────────────────────────────────────────

  /// [accounts] are the accounts the user may report on. When
  /// [includeUnassigned] is true (admins), expenses not tied to one of them
  /// (non-wallet, deleted accounts) are kept while no account filter is set.
  static ExpenseReport buildExpenses({
    required FinanceReportFilter filter,
    required List<FundAccountEntity> accounts,
    required List<ExpenseEntity> allExpenses,
    bool includeUnassigned = false,
  }) {
    final visibleIds = {for (final a in accounts) a.id};
    final names = {for (final a in accounts) a.id: a.name};
    final query = filter.search.trim().toLowerCase();

    final rows = allExpenses.where((e) {
      if (filter.accountIds.isNotEmpty) {
        if (!filter.accountIds.contains(e.fundAccountId)) return false;
      } else if (!visibleIds.contains(e.fundAccountId) && !includeUnassigned) {
        return false;
      }
      if (!filter.includesDate(e.date)) return false;
      if (filter.statuses.isNotEmpty && !filter.statuses.contains(e.status)) {
        return false;
      }
      if (filter.categories.isNotEmpty &&
          !filter.categories.contains(e.expenseCategory)) {
        return false;
      }
      if (filter.expenseTypes.isNotEmpty &&
          !filter.expenseTypes.contains(e.expenseType)) {
        return false;
      }
      if (filter.paymentMethods.isNotEmpty &&
          !filter.paymentMethods.contains(e.paymentMethod)) {
        return false;
      }
      if (filter.employees.isNotEmpty &&
          !filter.employees.contains(e.employeeName ?? '')) {
        return false;
      }
      if (filter.vehicles.isNotEmpty &&
          !filter.vehicles.contains(e.vehicleName ?? '')) {
        return false;
      }
      if (query.isNotEmpty &&
          ![
            e.referenceNumber,
            e.expenseCategory,
            e.expenseType,
            e.description ?? '',
            e.notes ?? '',
            e.submittedBy,
            e.employeeName ?? '',
            e.vehicleName ?? '',
            e.fundAccountName ?? names[e.fundAccountId] ?? '',
          ].any((s) => s.toLowerCase().contains(query))) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return ExpenseReport(
      rows: rows,
      byCategory: _group(rows, (e) => e.expenseCategory),
      byStatus: _group(rows, (e) => e.status.displayName),
      byAccount: _group(
        rows,
        (e) => accountNameOf(e, names),
      ),
    );
  }

  static String accountNameOf(ExpenseEntity e, Map<String, String> names) {
    final name = e.fundAccountName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return names[e.fundAccountId] ??
        (e.isNonWallet ? 'Non-wallet' : 'No account');
  }

  static List<ReportGroupTotal> _group(
    List<ExpenseEntity> rows,
    String Function(ExpenseEntity) keyOf,
  ) {
    final counts = <String, int>{};
    final sums = <String, double>{};
    for (final e in rows) {
      final raw = keyOf(e).trim();
      final key = raw.isEmpty ? 'Uncategorised' : raw;
      counts[key] = (counts[key] ?? 0) + 1;
      sums[key] = (sums[key] ?? 0) + e.amount;
    }
    final list = [
      for (final k in sums.keys)
        ReportGroupTotal(label: k, count: counts[k]!, amount: _round(sums[k]!)),
    ]..sort((a, b) => b.amount.compareTo(a.amount));
    return list;
  }

  static double _round(double v) => (v * 100).roundToDouble() / 100;

  // ─── Export documents ────────────────────────────────────────────────

  static final _money = NumberFormat('#,##0.00', 'en_US');
  static final _day = DateFormat('dd MMM yyyy');

  static String _fmt(double v) => '${_money.format(v)} SAR';

  /// Lines describing [filter] for the report header.
  static List<String> describeFilter({
    required FinanceReportFilter filter,
    required List<FundAccountEntity> accounts,
  }) {
    final lines = <String>[];
    if (filter.from == null && filter.to == null) {
      lines.add('Period: All time');
    } else {
      final from = filter.from == null ? 'Beginning' : _day.format(filter.from!);
      final to = filter.to == null ? 'Today' : _day.format(filter.to!);
      lines.add('Period: $from – $to');
    }
    if (filter.accountIds.isEmpty) {
      lines.add('Accounts: All');
    } else {
      final names = accounts
          .where((a) => filter.accountIds.contains(a.id))
          .map((a) => a.name)
          .toList()
        ..sort();
      lines.add('Accounts: ${names.join(', ')}');
    }
    if (filter.type.isLedger) {
      if (filter.transactionTypes.isNotEmpty) {
        lines.add('Types: ${filter.transactionTypes.map((t) => t.displayName).join(', ')}');
      }
      if (filter.type == FinanceReportType.accountActivity &&
          filter.direction != LedgerDirection.all) {
        lines.add('Direction: ${filter.direction.displayName}');
      }
      if (filter.excludeInternalTransfers) {
        lines.add('Transfers between the selected accounts are hidden');
      }
    } else {
      void addSet(String label, Iterable<String> values) {
        if (values.isNotEmpty) lines.add('$label: ${values.join(', ')}');
      }

      addSet('Status', filter.statuses.map((s) => s.displayName));
      addSet('Category', filter.categories);
      addSet('Type', filter.expenseTypes);
      addSet('Payment method', filter.paymentMethods.map(paymentMethodLabel));
      addSet('Employee', filter.employees);
      addSet('Vehicle', filter.vehicles);
    }
    if (filter.search.trim().isNotEmpty) {
      lines.add('Search: "${filter.search.trim()}"');
    }
    return lines;
  }

  static ReportDocument ledgerDocument({
    required FinanceReportFilter filter,
    required LedgerReport report,
    required List<FundAccountEntity> accounts,
    required String generatedBy,
    DateTime? now,
  }) {
    final isIncome = filter.type == FinanceReportType.income;
    final metrics = <ReportMetric>[
      if (!isIncome) ReportMetric('Opening balance', _fmt(report.openingTotal)),
      ReportMetric('Money in', _fmt(report.totalIn)),
      if (!isIncome) ReportMetric('Money out', _fmt(report.totalOut)),
      if (!isIncome) ReportMetric('Closing balance', _fmt(report.closingTotal)),
      ReportMetric('Entries', '${report.rows.length}'),
    ];

    final detail = ReportSection(
      title: isIncome ? 'Income' : 'Transactions',
      columns: const [
        ReportColumn('Ref', pdfFlex: 1.1),
        ReportColumn('Date', kind: ReportCellKind.date, pdfFlex: 1.3),
        ReportColumn('Account', pdfFlex: 1.5),
        ReportColumn('Type', pdfFlex: 1.2),
        ReportColumn('Description', pdfFlex: 3),
        ReportColumn('Other account', pdfFlex: 0),
        ReportColumn('Bucket', pdfFlex: 0),
        ReportColumn('Money in', kind: ReportCellKind.money, pdfFlex: 1.2),
        ReportColumn('Money out', kind: ReportCellKind.money, pdfFlex: 1.2),
        ReportColumn('Balance after', kind: ReportCellKind.money, pdfFlex: 1.3),
        ReportColumn('By', pdfFlex: 1.2),
        ReportColumn('Reversed', pdfFlex: 0),
      ],
      rows: [
        for (final r in report.rows)
          [
            r.tx.displayReference,
            r.tx.date,
            r.accountName,
            r.tx.type.displayName,
            r.tx.description,
            r.counterpartyName ?? '',
            r.tx.bucket.displayName,
            r.moneyIn == 0 ? null : r.moneyIn,
            r.moneyOut == 0 ? null : r.moneyOut,
            r.tx.balanceAfter,
            r.tx.performedBy,
            r.tx.isReversed ? 'Yes' : '',
          ],
      ],
      totals: [
        'Total', null, null, null, null, null, null,
        report.totalIn, report.totalOut, null, null, null,
      ],
    );

    final balances = ReportSection(
      title: 'Account Balances',
      columns: const [
        ReportColumn('Code', pdfFlex: 1),
        ReportColumn('Account', pdfFlex: 2.5),
        ReportColumn('Opening', kind: ReportCellKind.money, pdfFlex: 1.4),
        ReportColumn('Money in', kind: ReportCellKind.money, pdfFlex: 1.4),
        ReportColumn('Money out', kind: ReportCellKind.money, pdfFlex: 1.4),
        ReportColumn('Closing', kind: ReportCellKind.money, pdfFlex: 1.4),
        ReportColumn('Entries', kind: ReportCellKind.integer, pdfFlex: 0.8),
      ],
      rows: [
        for (final a in report.accounts)
          [
            a.accountCode,
            a.accountName,
            a.opening,
            a.moneyIn,
            a.moneyOut,
            a.closing,
            a.entries,
          ],
      ],
      totals: [
        'Total',
        null,
        report.openingTotal,
        report.accounts.fold<double>(0, (s, a) => s + a.moneyIn),
        report.accounts.fold<double>(0, (s, a) => s + a.moneyOut),
        report.closingTotal,
        report.accounts.fold<int>(0, (s, a) => s + a.entries),
      ],
    );

    return ReportDocument(
      title: '${filter.type.displayName} Report',
      generatedAt: now ?? DateTime.now(),
      generatedBy: generatedBy,
      filterLines: describeFilter(filter: filter, accounts: accounts),
      metrics: metrics,
      sections: [balances, detail],
    );
  }

  static ReportDocument expenseDocument({
    required FinanceReportFilter filter,
    required ExpenseReport report,
    required List<FundAccountEntity> accounts,
    required String generatedBy,
    DateTime? now,
  }) {
    final names = {for (final a in accounts) a.id: a.name};

    ReportSection groupSection(String title, List<ReportGroupTotal> groups) =>
        ReportSection(
          title: title,
          columns: const [
            ReportColumn('Name', pdfFlex: 3),
            ReportColumn('Count', kind: ReportCellKind.integer, pdfFlex: 1),
            ReportColumn('Amount', kind: ReportCellKind.money, pdfFlex: 1.5),
          ],
          rows: [
            for (final g in groups) [g.label, g.count, g.amount],
          ],
          totals: ['Total', report.rows.length, report.total],
        );

    final detail = ReportSection(
      title: 'Expenses',
      columns: const [
        ReportColumn('Ref', pdfFlex: 1.1),
        ReportColumn('Date', kind: ReportCellKind.date, pdfFlex: 1.3),
        ReportColumn('Status', pdfFlex: 0.9),
        ReportColumn('Category', pdfFlex: 1.3),
        ReportColumn('Type', pdfFlex: 1.4),
        ReportColumn('Account', pdfFlex: 1.3),
        ReportColumn('Payment', pdfFlex: 0.8),
        ReportColumn('Employee', pdfFlex: 1.3),
        ReportColumn('Vehicle', pdfFlex: 1.1),
        ReportColumn('Description', pdfFlex: 0),
        ReportColumn('Submitted by', pdfFlex: 0),
        ReportColumn('Approved by', pdfFlex: 0),
        ReportColumn('Paid by', pdfFlex: 0),
        ReportColumn('Paid at', kind: ReportCellKind.date, pdfFlex: 0),
        ReportColumn('Notes', pdfFlex: 0),
        ReportColumn('Amount', kind: ReportCellKind.money, pdfFlex: 1.2),
      ],
      rows: [
        for (final e in report.rows)
          [
            e.referenceNumber,
            e.date,
            e.status.displayName,
            e.expenseCategory,
            e.expenseType,
            accountNameOf(e, names),
            paymentMethodLabel(e.paymentMethod),
            e.employeeName ?? '',
            e.vehicleName ?? '',
            e.description ?? '',
            e.submittedBy,
            e.approvedBy ?? '',
            e.paidBy ?? '',
            e.paidAt,
            e.notes ?? '',
            e.amount,
          ],
      ],
      totals: [
        'Total', null, null, null, null, null, null, null, null, null, null,
        null, null, null, null, report.total,
      ],
    );

    return ReportDocument(
      title: 'Expenses Report',
      generatedAt: now ?? DateTime.now(),
      generatedBy: generatedBy,
      filterLines: describeFilter(filter: filter, accounts: accounts),
      metrics: [
        ReportMetric('Total', _fmt(report.total)),
        ReportMetric('Paid', _fmt(report.paidTotal)),
        ReportMetric('Not paid yet', _fmt(report.outstandingTotal)),
        ReportMetric('Rejected / voided', _fmt(report.rejectedOrVoidedTotal)),
        ReportMetric('Expenses', '${report.rows.length}'),
      ],
      sections: [
        groupSection('By Category', report.byCategory),
        groupSection('By Account', report.byAccount),
        detail,
      ],
    );
  }
}
