import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xls;

import '../entities/finance_report.dart';

/// Writes a [ReportDocument] as an Excel workbook or a PDF.
class FinanceReportFileService {
  FinanceReportFileService._();

  static const _brandHex = '#4F46E5';
  static const _moneyFormat = '#,##0.00';
  static const _dateFormat = 'dd-mmm-yyyy hh:mm';

  static final _stamp = DateFormat('dd MMM yyyy, hh:mm a');
  static final _money = NumberFormat('#,##0.00', 'en_US');
  static final _pdfDate = DateFormat('dd MMM yy\nhh:mm a');

  /// The built-in PDF font has no glyphs for these (transfer descriptions
  /// use arrows), so they are swapped for plain characters.
  static const _pdfAsciiMap = {
    '—': '-',
    '–': '-',
    '→': '->',
    '←': '<-',
    '↔': '<->',
    '·': '|',
    '…': '...',
    '‘': "'",
    '’': "'",
    '“': '"',
    '”': '"',
  };

  static String _pdfSafe(String text) {
    var out = text;
    _pdfAsciiMap.forEach((k, v) => out = out.replaceAll(k, v));
    return out;
  }

  /// File name without extension, e.g. `Expenses_Report_2026-11-24_1530`.
  static String fileBaseName(ReportDocument doc) {
    final title = doc.title
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+$'), '');
    return '${title}_${DateFormat('yyyy-MM-dd_HHmm').format(doc.generatedAt)}';
  }

  // ─── Excel ─────────────────────────────────────────────────────────

  /// One "Summary" sheet (filters, key figures) plus one sheet per section.
  static Uint8List buildExcel(ReportDocument doc) {
    final workbook = xls.Workbook();
    try {
      final summary = workbook.worksheets[0];
      summary.name = 'Summary';
      _writeSummarySheet(summary, doc);

      final usedNames = <String>{'Summary'};
      for (final section in doc.sections) {
        var name = _sheetName(section.title);
        var n = 2;
        while (usedNames.contains(name)) {
          name = _sheetName('${section.title} $n');
          n++;
        }
        usedNames.add(name);
        _writeSectionSheet(workbook.worksheets.addWithName(name), section);
      }

      return Uint8List.fromList(workbook.saveAsStream());
    } finally {
      workbook.dispose();
    }
  }

  static String _sheetName(String title) {
    final clean = title.replaceAll(RegExp(r'[\[\]\*\?/\\:]'), ' ').trim();
    return clean.length > 31 ? clean.substring(0, 31) : clean;
  }

  static void _writeSummarySheet(xls.Worksheet sheet, ReportDocument doc) {
    var row = 1;
    final title = sheet.getRangeByIndex(row, 1);
    title.setText(doc.title);
    title.cellStyle.bold = true;
    title.cellStyle.fontSize = 16;
    title.cellStyle.fontColor = _brandHex;
    row++;
    sheet
        .getRangeByIndex(row, 1)
        .setText('Generated ${_stamp.format(doc.generatedAt)} by ${doc.generatedBy}');
    sheet.getRangeByIndex(row, 1).cellStyle.fontColor = '#6B7280';
    row += 2;

    _sectionHeading(sheet, row, 'Filters');
    row++;
    for (final line in doc.filterLines) {
      sheet.getRangeByIndex(row, 1).setText(line);
      row++;
    }
    row++;

    _sectionHeading(sheet, row, 'Key figures');
    row++;
    for (final m in doc.metrics) {
      sheet.getRangeByIndex(row, 1).setText(m.label);
      final value = sheet.getRangeByIndex(row, 2);
      value.setText(m.value);
      value.cellStyle.bold = true;
      value.cellStyle.hAlign = xls.HAlignType.right;
      row++;
    }

    sheet.getRangeByIndex(1, 1).columnWidth = 34;
    sheet.getRangeByIndex(1, 2).columnWidth = 24;
  }

  static void _sectionHeading(xls.Worksheet sheet, int row, String text) {
    final r = sheet.getRangeByIndex(row, 1);
    r.setText(text);
    r.cellStyle.bold = true;
    r.cellStyle.fontSize = 12;
  }

  static void _writeSectionSheet(xls.Worksheet sheet, ReportSection section) {
    final cols = section.columns;
    final lastCol = cols.length;

    for (var c = 0; c < cols.length; c++) {
      final cell = sheet.getRangeByIndex(1, c + 1);
      cell.setText(cols[c].label);
    }
    final header = sheet.getRangeByIndex(1, 1, 1, lastCol);
    header.cellStyle.bold = true;
    header.cellStyle.fontColor = '#FFFFFF';
    header.cellStyle.backColor = _brandHex;

    var row = 2;
    for (final values in section.rows) {
      _writeRow(sheet, row, cols, values);
      row++;
    }
    final lastDataRow = row - 1;

    if (section.totals != null) {
      _writeRow(sheet, row, cols, section.totals!);
      final totals = sheet.getRangeByIndex(row, 1, row, lastCol);
      totals.cellStyle.bold = true;
      totals.cellStyle.backColor = '#EEF2FF';
    }

    if (section.rows.isNotEmpty) {
      sheet.autoFilters.filterRange =
          sheet.getRangeByIndex(1, 1, lastDataRow, lastCol);
    }
    sheet.getRangeByIndex(2, 1).freezePanes();

    for (var c = 0; c < cols.length; c++) {
      sheet.autoFitColumn(c + 1);
      final range = sheet.getRangeByIndex(1, c + 1);
      // Keep long text columns readable without making them huge.
      final width = range.columnWidth;
      if (width > 60) range.columnWidth = 60;
      if (width < 10) range.columnWidth = 10;
    }
  }

  static void _writeRow(
    xls.Worksheet sheet,
    int row,
    List<ReportColumn> cols,
    List<Object?> values,
  ) {
    for (var c = 0; c < cols.length && c < values.length; c++) {
      final v = values[c];
      if (v == null) continue;
      final cell = sheet.getRangeByIndex(row, c + 1);
      if (v is DateTime) {
        cell.setDateTime(v);
        cell.numberFormat = _dateFormat;
      } else if (v is num) {
        cell.setNumber(v.toDouble());
        cell.numberFormat =
            cols[c].kind == ReportCellKind.integer && v is int ? '0' : _moneyFormat;
      } else {
        cell.setText(v.toString());
      }
    }
  }

  // ─── PDF ───────────────────────────────────────────────────────────

  /// Landscape A4. Columns with `pdfFlex == 0` are Excel-only.
  static Future<Uint8List> buildPdf(ReportDocument doc) async {
    const brand = PdfColor.fromInt(0xFF4F46E5);
    const muted = PdfColor.fromInt(0xFF6B7280);
    const border = PdfColor.fromInt(0xFFE5E7EB);
    const totalsBg = PdfColor.fromInt(0xFFEEF2FF);
    const stripe = PdfColor.fromInt(0xFFF9FAFB);

    final theme = pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
    );
    final pdf = pw.Document(theme: theme, title: doc.title);

    pw.Widget header(pw.Context context) {
      if (context.pageNumber > 1) {
        return pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Text(
            doc.title,
            style: const pw.TextStyle(fontSize: 8, color: muted),
          ),
        );
      }
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      doc.title,
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: brand,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Generated ${_stamp.format(doc.generatedAt)} by ${doc.generatedBy}',
                      style: const pw.TextStyle(fontSize: 8, color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            _pdfSafe(doc.filterLines.join('   |   ')),
            style: const pw.TextStyle(fontSize: 8, color: muted),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              for (final m in doc.metrics)
                pw.Expanded(
                  child: pw.Container(
                    margin: const pw.EdgeInsets.only(right: 6),
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: border),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          _pdfSafe(m.label),
                          style: const pw.TextStyle(fontSize: 7, color: muted),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          m.value,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          pw.SizedBox(height: 12),
        ],
      );
    }

    pw.Widget cellText(
      Object? v,
      ReportColumn col, {
      bool bold = false,
      PdfColor? color,
    }) {
      String text;
      if (v == null) {
        text = '';
      } else if (v is DateTime) {
        text = _pdfDate.format(v);
      } else if (v is num) {
        text = col.kind == ReportCellKind.integer && v is int
            ? '$v'
            : _money.format(v);
      } else {
        text = _pdfSafe(v.toString());
      }
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: pw.Text(
          text,
          textAlign: col.isNumeric ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(
            fontSize: 7.5,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color,
          ),
        ),
      );
    }

    List<pw.Widget> sectionWidgets(ReportSection section) {
      final idx = [
        for (var i = 0; i < section.columns.length; i++)
          if (section.columns[i].inPdf) i,
      ];
      final cols = [for (final i in idx) section.columns[i]];
      return [
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 6, bottom: 6),
          child: pw.Text(
            '${section.title} (${section.rows.length})',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        ),
        if (section.rows.isEmpty)
          pw.Text(
            'Nothing matches the selected filters.',
            style: const pw.TextStyle(fontSize: 8, color: muted),
          )
        else
          pw.Table(
            border: const pw.TableBorder(
              horizontalInside: pw.BorderSide(color: border, width: 0.5),
              bottom: pw.BorderSide(color: border, width: 0.5),
            ),
            columnWidths: {
              for (var c = 0; c < cols.length; c++)
                c: pw.FlexColumnWidth(cols[c].pdfFlex),
            },
            children: [
              pw.TableRow(
                repeat: true,
                decoration: const pw.BoxDecoration(color: brand),
                children: [
                  for (final c in cols)
                    cellText(c.label, ReportColumn(c.label, kind: c.isNumeric ? ReportCellKind.money : ReportCellKind.text),
                        bold: true, color: PdfColors.white),
                ],
              ),
              for (var r = 0; r < section.rows.length; r++)
                pw.TableRow(
                  decoration: r.isOdd
                      ? const pw.BoxDecoration(color: stripe)
                      : null,
                  children: [
                    for (var c = 0; c < idx.length; c++)
                      cellText(
                        idx[c] < section.rows[r].length
                            ? section.rows[r][idx[c]]
                            : null,
                        cols[c],
                      ),
                  ],
                ),
              if (section.totals != null)
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: totalsBg),
                  children: [
                    for (var c = 0; c < idx.length; c++)
                      cellText(section.totals![idx[c]], cols[c], bold: true),
                  ],
                ),
            ],
          ),
        pw.SizedBox(height: 14),
      ];
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        maxPages: 1000,
        header: header,
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 6),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 7, color: muted),
          ),
        ),
        build: (context) => [
          for (final s in doc.sections) ...sectionWidgets(s),
        ],
      ),
    );

    return pdf.save();
  }
}
