import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../models/company_info.dart';
import '../entities/salary_entity.dart';

/// One amount on a payment receipt. [isDeduction] amounts are shown with a
/// minus sign because they came off what was paid.
class ReceiptLine {
  final String label;
  final double amount;
  final bool isDeduction;

  const ReceiptLine(this.label, this.amount, {this.isDeduction = false});
}

/// Builds the receipt an external driver gets once their month is paid: as a
/// PDF to share, and as plain text for a WhatsApp message.
class PaymentReceiptService {
  PaymentReceiptService._();

  static const companyName = 'Xloop Tours W.L.L';

  static final _money = NumberFormat('#,##0.00', 'en_US');
  static final _date = DateFormat('d MMM y');

  /// Short, stable reference for the payment, e.g. `RCP-202611-A1B2C3`.
  static String receiptNumber(SalaryPaymentEntity p) {
    final id = p.employeeId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final tail = id.length > 6 ? id.substring(id.length - 6) : id;
    return 'RCP-${p.period.replaceAll('-', '')}-${tail.toUpperCase()}';
  }

  /// "November 2026" for the payment's `yyyy-MM` period.
  static String monthLabel(SalaryPaymentEntity p) {
    final parts = p.period.split('-');
    final year = parts.isNotEmpty ? int.tryParse(parts[0]) : null;
    final month = parts.length > 1 ? int.tryParse(parts[1]) : null;
    if (year == null || month == null) return p.period;
    return DateFormat('MMMM y').format(DateTime(year, month));
  }

  /// What the money was for, e.g. "Trip payment - November 2026 (12 trips)".
  static String purpose(SalaryPaymentEntity p) {
    final kind = p.isTripSettlement ? 'Trip payment' : 'Salary';
    final trips = p.tripCount != null ? ' (${p.tripCount} trips)' : '';
    return '$kind - ${monthLabel(p)}$trips';
  }

  static String paidOn(SalaryPaymentEntity p) =>
      _date.format(p.paidAt ?? p.createdAt);

  static String methodLabel(String method) => switch (method) {
        'cash' => 'Cash',
        'stcPay' => 'STC Pay',
        _ => 'Bank transfer',
      };

  static String money(double v, String currency) =>
      '${_money.format(v)} $currency';

  /// The amounts that make up the net, skipping the ones that are zero.
  static List<ReceiptLine> lines(SalaryPaymentEntity p) {
    String withNote(String label, String? note) =>
        (note ?? '').trim().isEmpty ? label : '$label (${note!.trim()})';

    return [
      ReceiptLine(
        p.isTripSettlement ? 'Trip earnings' : 'Basic salary',
        p.basicSalary,
      ),
      if (p.allowances > 0) ReceiptLine('Allowances', p.allowances),
      if (p.extraAllowance > 0)
        ReceiptLine(withNote('Extra', p.extraAllowanceNote), p.extraAllowance),
      if (p.leaveDeduction > 0)
        ReceiptLine(
          'Unpaid leave (${p.leaveDays} days)',
          p.leaveDeduction,
          isDeduction: true,
        ),
      if (p.deductions > 0)
        ReceiptLine(
          withNote('Deduction', p.deductionNote),
          p.deductions,
          isDeduction: true,
        ),
      if (p.advanceRecovery > 0)
        ReceiptLine('Advance recovered', p.advanceRecovery, isDeduction: true),
    ];
  }

  /// Digits for a wa.me link, with the country code: [countryCode] (e.g.
  /// `+966`) is added unless [phone] already starts with it. Empty when there
  /// is no number, which makes WhatsApp ask who to send to.
  static String whatsAppNumber(String? countryCode, String? phone) {
    var digits = (phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    if (digits.startsWith('00')) return digits.substring(2);
    final cc = (countryCode ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if ((phone ?? '').trim().startsWith('+')) return digits;
    if (cc.isNotEmpty && digits.startsWith(cc) && digits.length > 9) {
      return digits;
    }
    digits = digits.replaceFirst(RegExp(r'^0+'), '');
    return '$cc$digits';
  }

  /// The receipt as a WhatsApp message (`*bold*` is WhatsApp formatting).
  static String whatsAppText(SalaryPaymentEntity p) {
    final buf = StringBuffer()
      ..writeln('*$companyName - Payment Receipt*')
      ..writeln('Receipt No: ${receiptNumber(p)}')
      ..writeln('Date: ${paidOn(p)}')
      ..writeln()
      ..writeln('Paid to: ${p.employeeName}')
      ..writeln('For: ${purpose(p)}')
      ..writeln();
    for (final l in lines(p)) {
      buf.writeln(
        '${l.label}: ${l.isDeduction ? '- ' : ''}${money(l.amount, p.currency)}',
      );
    }
    buf
      ..writeln('*Net paid: ${money(p.netAmount, p.currency)}*')
      ..writeln('Paid via: ${methodLabel(p.paymentMethod)}')
      ..writeln()
      ..write('Thank you.');
    return buf.toString();
  }

  static String fileName(SalaryPaymentEntity p) {
    final name = p.employeeName
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return 'Receipt_${name.isEmpty ? 'payment' : name}_${p.period}.pdf';
  }

  /// Arabic font used as a fallback so Arabic names print; null when the
  /// asset can't be loaded.
  static Future<pw.Font?> _loadArabicFont() async {
    try {
      final data =
          await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
      return pw.Font.ttf(data);
    } catch (_) {
      return null;
    }
  }

  /// The built-in PDF font only covers Latin-1, so common punctuation is
  /// swapped for plain characters. Without the Arabic fallback, anything
  /// else outside Latin-1 is dropped rather than printed as boxes.
  static String _pdfSafe(String text, {bool keepArabic = true}) {
    var out = text
        .replaceAll(RegExp('[—–]'), '-')
        .replaceAll(RegExp('[‘’]'), "'")
        .replaceAll(RegExp('[“”]'), '"')
        .replaceAll('·', '|');
    out = out.replaceAll(
      keepArabic
          ? RegExp(r'[^\x20-\x7E\xA0-\xFF\n\u0600-\u06FF\u0750-\u077F]')
          : RegExp(r'[^\x20-\x7E\xA0-\xFF\n]'),
      '',
    );
    return out.trim();
  }

  /// One-page A5 receipt.
  static Future<Uint8List> buildPdf(
    SalaryPaymentEntity p, {
    String? phone,
  }) async {
    const brand = PdfColor.fromInt(0xFF4F46E5);
    const muted = PdfColor.fromInt(0xFF6B7280);
    const line = PdfColor.fromInt(0xFFE5E7EB);
    const danger = PdfColor.fromInt(0xFFDC2626);

    final arabic = await _loadArabicFont();
    String safe(String t) => _pdfSafe(t, keepArabic: arabic != null);

    pw.Widget infoRow(String label, String value) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 80,
                child: pw.Text(
                  label,
                  style: const pw.TextStyle(fontSize: 9, color: muted),
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  safe(value),
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );

    pw.Widget amountRow(ReceiptLine l) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: line, width: 0.6)),
          ),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  safe(l.label),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.Text(
                '${l.isDeduction ? '- ' : ''}${money(l.amount, p.currency)}',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: l.isDeduction ? danger : PdfColors.black,
                ),
              ),
            ],
          ),
        );

    final doc = pw.Document(title: 'Payment Receipt ${receiptNumber(p)}');
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        theme: arabic == null
            ? null
            : pw.ThemeData.withFont(fontFallback: [arabic]),
        margin: const pw.EdgeInsets.all(28),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        companyName.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: brand,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '${CompanyInfo.crNumber}  |  ${CompanyInfo.contact}',
                        style: const pw.TextStyle(fontSize: 7.5, color: muted),
                      ),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'PAYMENT RECEIPT',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      receiptNumber(p),
                      style: const pw.TextStyle(fontSize: 8, color: muted),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(color: brand, thickness: 1.5),
            pw.SizedBox(height: 10),
            infoRow('Paid to', p.employeeName),
            if ((phone ?? '').trim().isNotEmpty) infoRow('Phone', phone!),
            infoRow('For', purpose(p)),
            infoRow('Date paid', paidOn(p)),
            infoRow('Paid via', methodLabel(p.paymentMethod)),
            pw.SizedBox(height: 16),
            ...lines(p).map(amountRow),
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 10),
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFEEF2FF),
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      'NET PAID',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: brand,
                      ),
                    ),
                  ),
                  pw.Text(
                    money(p.netAmount, p.currency),
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: brand,
                    ),
                  ),
                ],
              ),
            ),
            if ((p.paidBy ?? '').trim().isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Text(
                safe('Paid by ${p.paidBy}'),
                style: const pw.TextStyle(fontSize: 8.5, color: muted),
              ),
            ],
            pw.Spacer(),
            pw.Divider(color: line),
            pw.Text(
              'This receipt confirms the payment above. Computer-generated, '
              'no signature required.',
              style: const pw.TextStyle(fontSize: 7.5, color: muted),
            ),
          ],
        ),
      ),
    );
    return doc.save();
  }
}
