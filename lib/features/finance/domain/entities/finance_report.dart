import 'expense_entity.dart';
import 'fund_transaction_entity.dart';

/// What a finance report lists.
enum FinanceReportType {
  /// Every ledger row: deposits, withdrawals, transfers, expense payments,
  /// adjustments and reversals.
  accountActivity,

  /// Ledger rows that put money into an account.
  income,

  /// Expense records in any status (pending, paid, rejected, ...).
  expenses;

  String get displayName {
    switch (this) {
      case FinanceReportType.accountActivity:
        return 'Account Activity';
      case FinanceReportType.income:
        return 'Deposits';
      case FinanceReportType.expenses:
        return 'Expenses';
    }
  }

  String get description {
    switch (this) {
      case FinanceReportType.accountActivity:
        return 'Every money movement in and out of the selected accounts, '
            'with opening and closing balances.';
      case FinanceReportType.income:
        return 'Money deposited into the selected finance accounts.';
      case FinanceReportType.expenses:
        return 'Expense records with status, category, employee and vehicle.';
    }
  }

  bool get isLedger => this != FinanceReportType.expenses;
}

/// Money direction filter for ledger reports.
enum LedgerDirection {
  all,
  moneyIn,
  moneyOut;

  String get displayName {
    switch (this) {
      case LedgerDirection.all:
        return 'In & Out';
      case LedgerDirection.moneyIn:
        return 'Money In';
      case LedgerDirection.moneyOut:
        return 'Money Out';
    }
  }
}

/// Every selection the user can make on the Reports tab.
///
/// Empty sets mean "no restriction".
class FinanceReportFilter {
  final FinanceReportType type;

  /// First day included (time is ignored).
  final DateTime? from;

  /// Last day included (time is ignored).
  final DateTime? to;

  final Set<String> accountIds;
  final String search;

  // ── Ledger reports ──
  final Set<FundTransactionType> transactionTypes;
  final LedgerDirection direction;

  /// Hide transfers whose other side is also in the report, so money moved
  /// between two listed accounts is not counted as income or spending.
  final bool excludeInternalTransfers;

  // ── Expense report ──
  final Set<ExpenseStatus> statuses;
  final Set<String> categories;
  final Set<String> expenseTypes;
  final Set<String> paymentMethods;
  final Set<String> employees;
  final Set<String> vehicles;

  const FinanceReportFilter({
    this.type = FinanceReportType.accountActivity,
    this.from,
    this.to,
    this.accountIds = const {},
    this.search = '',
    this.transactionTypes = const {},
    this.direction = LedgerDirection.all,
    this.excludeInternalTransfers = false,
    this.statuses = const {},
    this.categories = const {},
    this.expenseTypes = const {},
    this.paymentMethods = const {},
    this.employees = const {},
    this.vehicles = const {},
  });

  FinanceReportFilter copyWith({
    FinanceReportType? type,
    DateTime? from,
    DateTime? to,
    bool clearDates = false,
    Set<String>? accountIds,
    String? search,
    Set<FundTransactionType>? transactionTypes,
    LedgerDirection? direction,
    bool? excludeInternalTransfers,
    Set<ExpenseStatus>? statuses,
    Set<String>? categories,
    Set<String>? expenseTypes,
    Set<String>? paymentMethods,
    Set<String>? employees,
    Set<String>? vehicles,
  }) {
    return FinanceReportFilter(
      type: type ?? this.type,
      from: clearDates ? null : (from ?? this.from),
      to: clearDates ? null : (to ?? this.to),
      accountIds: accountIds ?? this.accountIds,
      search: search ?? this.search,
      transactionTypes: transactionTypes ?? this.transactionTypes,
      direction: direction ?? this.direction,
      excludeInternalTransfers:
          excludeInternalTransfers ?? this.excludeInternalTransfers,
      statuses: statuses ?? this.statuses,
      categories: categories ?? this.categories,
      expenseTypes: expenseTypes ?? this.expenseTypes,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      employees: employees ?? this.employees,
      vehicles: vehicles ?? this.vehicles,
    );
  }

  /// Start of [from], or null.
  DateTime? get fromStart =>
      from == null ? null : DateTime(from!.year, from!.month, from!.day);

  /// Start of the day after [to] (exclusive upper bound), or null.
  DateTime? get toEndExclusive =>
      to == null ? null : DateTime(to!.year, to!.month, to!.day + 1);

  bool includesDate(DateTime d) {
    final start = fromStart;
    final end = toEndExclusive;
    if (start != null && d.isBefore(start)) return false;
    if (end != null && !d.isBefore(end)) return false;
    return true;
  }
}

/// A ledger row with the names a reader needs.
class LedgerReportRow {
  final FundTransactionEntity tx;
  final String accountName;

  /// Other account of a transfer, when there is one.
  final String? counterpartyName;
  final double moneyIn;
  final double moneyOut;

  const LedgerReportRow({
    required this.tx,
    required this.accountName,
    this.counterpartyName,
    required this.moneyIn,
    required this.moneyOut,
  });
}

/// One account's balance movement over the report period.
class AccountPeriodSummary {
  final String accountId;
  final String accountName;
  final String accountCode;
  final double opening;
  final double moneyIn;
  final double moneyOut;
  final int entries;

  const AccountPeriodSummary({
    required this.accountId,
    required this.accountName,
    required this.accountCode,
    required this.opening,
    required this.moneyIn,
    required this.moneyOut,
    required this.entries,
  });

  double get closing => opening + moneyIn - moneyOut;
}

class LedgerReport {
  final List<LedgerReportRow> rows;

  /// Balances per selected account for the whole period, whatever the type,
  /// direction and search filters are.
  final List<AccountPeriodSummary> accounts;

  const LedgerReport({required this.rows, required this.accounts});

  double get totalIn => rows.fold(0.0, (s, r) => s + r.moneyIn);
  double get totalOut => rows.fold(0.0, (s, r) => s + r.moneyOut);
  double get net => totalIn - totalOut;
  double get openingTotal => accounts.fold(0.0, (s, a) => s + a.opening);
  double get closingTotal => accounts.fold(0.0, (s, a) => s + a.closing);
}

/// Total and count of one group of expenses (category, status, ...).
class ReportGroupTotal {
  final String label;
  final int count;
  final double amount;

  const ReportGroupTotal({
    required this.label,
    required this.count,
    required this.amount,
  });
}

class ExpenseReport {
  final List<ExpenseEntity> rows;
  final List<ReportGroupTotal> byCategory;
  final List<ReportGroupTotal> byStatus;
  final List<ReportGroupTotal> byAccount;

  const ExpenseReport({
    required this.rows,
    required this.byCategory,
    required this.byStatus,
    required this.byAccount,
  });

  double get total => rows.fold(0.0, (s, e) => s + e.amount);

  double _sumWhere(bool Function(ExpenseEntity) test) =>
      rows.where(test).fold(0.0, (s, e) => s + e.amount);

  /// Paid from a wallet.
  double get paidTotal =>
      _sumWhere((e) => e.status == ExpenseStatus.paid);

  /// Submitted or approved but not paid yet (includes non-wallet approvals).
  double get outstandingTotal => _sumWhere((e) =>
      e.status == ExpenseStatus.pending ||
      e.status == ExpenseStatus.approved ||
      e.status == ExpenseStatus.draft);

  double get rejectedOrVoidedTotal => _sumWhere((e) =>
      e.status == ExpenseStatus.rejected || e.status == ExpenseStatus.voided);
}

// ═══════════════════════════════════════════════════════════════════════════
// Export model: format-agnostic tables that the Excel and PDF writers render.
// ═══════════════════════════════════════════════════════════════════════════

enum ReportCellKind { text, money, date, integer }

class ReportColumn {
  final String label;
  final ReportCellKind kind;

  /// Relative width in the PDF; 0 leaves the column out of the PDF.
  final double pdfFlex;

  const ReportColumn(
    this.label, {
    this.kind = ReportCellKind.text,
    this.pdfFlex = 1,
  });

  bool get inPdf => pdfFlex > 0;
  bool get isNumeric =>
      kind == ReportCellKind.money || kind == ReportCellKind.integer;
}

class ReportSection {
  /// Also the Excel sheet name (max 31 chars).
  final String title;
  final List<ReportColumn> columns;

  /// Cell values: String, num, DateTime or null.
  final List<List<Object?>> rows;

  /// Optional bold totals row, same length as [columns].
  final List<Object?>? totals;

  const ReportSection({
    required this.title,
    required this.columns,
    required this.rows,
    this.totals,
  });
}

class ReportMetric {
  final String label;
  final String value;
  const ReportMetric(this.label, this.value);
}

/// A finished report ready to be written as Excel or PDF.
class ReportDocument {
  final String title;
  final DateTime generatedAt;
  final String generatedBy;

  /// Human-readable filter descriptions, e.g. "Accounts: Main, Petty Cash".
  final List<String> filterLines;
  final List<ReportMetric> metrics;
  final List<ReportSection> sections;

  const ReportDocument({
    required this.title,
    required this.generatedAt,
    required this.generatedBy,
    required this.filterLines,
    required this.metrics,
    required this.sections,
  });
}
