import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import '../entities/cash_advance_entity.dart';
import '../entities/expense_entity.dart';
import '../entities/fund_transaction_entity.dart';

/// Builds CSV files for the external accountant (they do not use this app).
class FinanceExportService {
  static String _csvEscape(String? value) {
    final v = value ?? '';
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  static String expensesToCsv(List<ExpenseEntity> expenses) {
    final buf = StringBuffer();
    buf.writeln(
      'reference,date,status,category,type,amount,currency,amountMinor,'
      'fundAccountId,fundAccountName,paymentMethod,submittedBy,employeeName,'
      'vehicleName,isNonWallet,approvedBy,paidBy,notes',
    );
    for (final e in expenses) {
      buf.writeln([
        _csvEscape(e.referenceNumber),
        e.date.toIso8601String(),
        e.status.name,
        _csvEscape(e.expenseCategory),
        _csvEscape(e.expenseType),
        e.amount.toStringAsFixed(2),
        e.currency,
        e.resolvedAmountMinor.toString(),
        _csvEscape(e.fundAccountId),
        _csvEscape(e.fundAccountName),
        _csvEscape(e.paymentMethod),
        _csvEscape(e.submittedBy),
        _csvEscape(e.employeeName),
        _csvEscape(e.vehicleName),
        e.isNonWallet.toString(),
        _csvEscape(e.approvedBy),
        _csvEscape(e.paidBy),
        _csvEscape(e.notes),
      ].join(','));
    }
    return buf.toString();
  }

  static String transactionsToCsv(List<FundTransactionEntity> txs) {
    final buf = StringBuffer();
    buf.writeln(
      'id,date,type,amount,currency,fundAccountId,description,'
      'balanceBefore,balanceAfter,bucket,performedBy,referenceExpenseId,isReversed',
    );
    for (final t in txs) {
      buf.writeln([
        _csvEscape(t.id),
        t.date.toIso8601String(),
        t.type.name,
        t.amount.toStringAsFixed(2),
        t.currency,
        _csvEscape(t.fundAccountId),
        _csvEscape(t.description),
        t.balanceBefore.toStringAsFixed(2),
        t.balanceAfter.toStringAsFixed(2),
        t.bucket.name,
        _csvEscape(t.performedBy),
        _csvEscape(t.referenceExpenseId),
        t.isReversed.toString(),
      ].join(','));
    }
    return buf.toString();
  }

  static String advancesToCsv(List<CashAdvanceEntity> advances) {
    final buf = StringBuffer();
    buf.writeln(
      'id,issuedAt,status,employeeName,amount,settledAmount,outstanding,'
      'currency,fundAccountName,purpose,issuedBy,notes',
    );
    for (final a in advances) {
      buf.writeln([
        _csvEscape(a.id),
        a.issuedAt.toIso8601String(),
        a.status.name,
        _csvEscape(a.employeeName),
        a.amount.toStringAsFixed(2),
        a.settledAmount.toStringAsFixed(2),
        a.outstanding.toStringAsFixed(2),
        a.currency,
        _csvEscape(a.fundAccountName),
        _csvEscape(a.purpose),
        _csvEscape(a.issuedBy),
        _csvEscape(a.notes),
      ].join(','));
    }
    return buf.toString();
  }

  /// Share/download CSV via platform share sheet.
  static Future<void> shareCsv({
    required String fileName,
    required String csvContent,
  }) async {
    final bytes = utf8.encode(csvContent);
    final xFile = XFile.fromData(
      bytes,
      mimeType: 'text/csv',
      name: fileName,
    );
    await Share.shareXFiles(
      [xFile],
      subject: fileName,
      text: 'Finance export: $fileName',
    );
  }
}
