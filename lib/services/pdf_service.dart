import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/invoice_model.dart';
import '../models/company_info.dart';
import 'number_to_words_service.dart';

class PDFService {
  static const double pageMargin = 20.0;
  static const double headerHeight = 120.0;
  static const double footerHeight = 80.0;
  static double get availableHeight =>
      PdfPageFormat.a4.height - (pageMargin * 2) - headerHeight - footerHeight;

  Future<Uint8List> generateInvoicePDF(InvoiceModel invoice) async {
    final pdf = pw.Document();
    // Always use placeholder - logo is optional
    // Skip logo loading to avoid any errors - placeholder will be shown
    pw.ImageProvider? logo;
    pw.ImageProvider? signatureImage;

    // Try to load logo only if needed
    try {
      final logoData = await rootBundle.load(CompanyInfo.logoPath);
      final logoBytes = logoData.buffer.asUint8List();
      logo = pw.MemoryImage(logoBytes);
    } catch (e) {
      logo = null;
    }

    // Load signature image for bank details
    try {
      final signatureData = await rootBundle.load('assets/images/sign.png');
      final signatureBytes = signatureData.buffer.asUint8List();
      signatureImage = pw.MemoryImage(signatureBytes);
    } catch (e) {
      signatureImage = null;
    }

    // Load fonts for multilingual support
    pw.Font arabicFont;
    pw.Font arabicBoldFont;
    pw.Font englishFont;
    pw.Font englishBoldFont;

    try {
      final arabicFontData = await rootBundle.load(
        'assets/fonts/Amiri-Regular.ttf',
      );
      final arabicBoldFontData = await rootBundle.load(
        'assets/fonts/Amiri-Bold.ttf',
      );

      // Verify fonts are not empty
      if (arabicFontData.lengthInBytes == 0 ||
          arabicBoldFontData.lengthInBytes == 0) {
        throw Exception('Font files are empty');
      }

      // pw.Font.ttf expects ByteData directly
      arabicFont = pw.Font.ttf(arabicFontData);
      arabicBoldFont = pw.Font.ttf(arabicBoldFontData);
      englishFont = pw.Font.times();
      englishBoldFont = pw.Font.timesBold();
    } catch (e) {
      // Fallback: Use default fonts if Arabic fonts fail to load
      print('Warning: Failed to load Arabic fonts: $e');
      // Use default fonts - Arabic will show as symbols but won't crash
      arabicFont = pw.Font.helvetica();
      arabicBoldFont = pw.Font.helveticaBold();
      englishFont = pw.Font.times();
      englishBoldFont = pw.Font.timesBold();
    }

    // Calculate how many pages we need for line items
    // First page: 8 items, subsequent pages: 12 items each
    final hasLineItems = invoice.lineItems.isNotEmpty;
    int firstPageLineItemCount = 0;
    int additionalLineItemPages = 0;
    final List<int> lineItemPageSizes = [];

    if (hasLineItems) {
      int remaining = invoice.lineItems.length;
      // First page gets 8 items (or less if total items < 8)
      firstPageLineItemCount = remaining <= 8 ? remaining : 8;
      remaining -= firstPageLineItemCount;

      // Calculate additional pages needed (12 items per page)
      while (remaining > 0) {
        final nextCount = remaining >= 12 ? 12 : remaining;
        lineItemPageSizes.add(nextCount);
        remaining -= nextCount;
      }
      additionalLineItemPages = lineItemPageSizes.length;
    }

    final rowsOnLastPage = additionalLineItemPages > 0
        ? lineItemPageSizes.last
        : firstPageLineItemCount;
    final totalsCanShareLastPage =
        hasLineItems && rowsOnLastPage > 0 && rowsOnLastPage <= 8;
    final needsSeparateTotalsPage = !hasLineItems || !totalsCanShareLastPage;

    // Total pages = 1 (first page with line items) + additional line item pages + (optional totals page) + 1 (bank details page)
    final totalPages =
        1 + additionalLineItemPages + (needsSeparateTotalsPage ? 1 : 0) + 1;
    var lineItemIndex = 0; // Track which line item we're on

    // Page 1: Header + Invoice Details + Bill To + Line Items (4) + Footer
    final firstPageLineItems = hasLineItems && firstPageLineItemCount > 0
        ? invoice.lineItems.sublist(0, firstPageLineItemCount)
        : [];
    lineItemIndex = firstPageLineItemCount;

    final isOnlyPage = additionalLineItemPages == 0 && hasLineItems;
    final appendTotalsOnFirstPage = isOnlyPage && totalsCanShareLastPage;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(pageMargin),
        theme: pw.ThemeData.withFont(
          base: englishFont,
          bold: englishBoldFont,
          fontFallback: [arabicFont, arabicBoldFont],
        ),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 1),
            ),
            padding: const pw.EdgeInsets.all(8),
            child: pw.Column(
              children: [
                // Header
                _buildHeader(logo, arabicBoldFont),
                pw.SizedBox(height: 10),

                // Invoice Details and Bill To Row
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Invoice Details (Left side, more space)
                    pw.Expanded(
                      flex: 3,
                      child: _buildInvoiceDetails(invoice, arabicBoldFont),
                    ),
                    pw.SizedBox(width: 10),
                    // Bill To Section (Right side, less space)
                    pw.Expanded(
                      flex: 2,
                      child: _buildBillToSection(invoice.customer),
                    ),
                  ],
                ),

                // Line Items (first 4 items with header)
                if (firstPageLineItems.isNotEmpty) ...[
                  pw.SizedBox(height: 10),
                  _buildLineItemsTable(
                    firstPageLineItems,
                    1, // Start numbering from 1
                    arabicBoldFont,
                    arabicFont,
                    showHeader: true, // Show header on first page
                    showFooter:
                        isOnlyPage, // Show footer only if this is the only page with items
                    invoice: invoice,
                  ),
                ],

                // Totals if all items fit on first page
                if (appendTotalsOnFirstPage) ...[
                  pw.SizedBox(height: 16),
                  _buildTotalsSection(invoice, arabicFont, arabicBoldFont),
                ],

                // Footer
                pw.Spacer(),
                _buildFooter(1, totalPages),
              ],
            ),
          );
        },
      ),
    );

    // Pages 2+: Header + Line Items (without header) + Footer
    for (int pageIndex = 0; pageIndex < additionalLineItemPages; pageIndex++) {
      final currentPageSize = lineItemPageSizes[pageIndex];
      final startIndex = lineItemIndex;
      final endIndex = (startIndex + currentPageSize).clamp(
        0,
        invoice.lineItems.length,
      );
      final pageLineItems = invoice.lineItems.sublist(startIndex, endIndex);
      lineItemIndex = endIndex;
      final currentPageNumber = 2 + pageIndex; // Page 2, 3, 4, etc.
      final isLastLineItemPage = pageIndex == additionalLineItemPages - 1;
      final appendTotalsHere = totalsCanShareLastPage && isLastLineItemPage;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.all(pageMargin),
          theme: pw.ThemeData.withFont(
            base: englishFont,
            bold: englishBoldFont,
            fontFallback: [arabicFont, arabicBoldFont],
          ),
          build: (pw.Context context) {
            return pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1),
              ),
              padding: const pw.EdgeInsets.all(8),
              child: pw.Column(
                children: [
                  // Header (on every page)
                  _buildHeader(logo, arabicBoldFont),
                  pw.SizedBox(height: 20),

                  // Line Items Table (NO header on pages 2+)
                  _buildLineItemsTable(
                    pageLineItems,
                    startIndex + 1,
                    arabicBoldFont,
                    arabicFont,
                    showHeader: false, // Never show header on pages 2+
                    showFooter: isLastLineItemPage,
                    invoice: invoice,
                  ),

                  if (appendTotalsHere) ...[
                    pw.SizedBox(height: 16),
                    _buildTotalsSection(invoice, arabicFont, arabicBoldFont),
                  ],

                  // Footer (on every page)
                  pw.Spacer(),
                  _buildFooter(currentPageNumber, totalPages),
                ],
              ),
            );
          },
        ),
      );
    }

    // Totals section (only if it didn't fit on the last line-item page)
    if (hasLineItems && needsSeparateTotalsPage) {
      final totalsPageNumber = 2 + additionalLineItemPages;
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.all(pageMargin),
          theme: pw.ThemeData.withFont(
            base: englishFont,
            bold: englishBoldFont,
            fontFallback: [arabicFont, arabicBoldFont],
          ),
          build: (pw.Context context) {
            return pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1),
              ),
              padding: const pw.EdgeInsets.all(8),
              child: pw.Column(
                children: [
                  // Header
                  _buildHeader(logo, arabicBoldFont),
                  pw.SizedBox(height: 20),

                  // Totals Section
                  _buildTotalsSection(invoice, arabicFont, arabicBoldFont),

                  // Footer
                  pw.Spacer(),
                  _buildFooter(totalsPageNumber, totalPages),
                ],
              ),
            );
          },
        ),
      );
    }

    // Bank Details Page (separate page after totals/line items)
    if (hasLineItems) {
      final bankDetailsPageNumber = totalPages;
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.all(pageMargin),
          theme: pw.ThemeData.withFont(
            base: englishFont,
            bold: englishBoldFont,
            fontFallback: [arabicFont, arabicBoldFont],
          ),
          build: (pw.Context context) {
            return pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1),
              ),
              padding: const pw.EdgeInsets.all(8),
              child: pw.Column(
                children: [
                  // Header
                  _buildHeader(logo, arabicBoldFont),
                  pw.SizedBox(height: 20),

                  // Bank Details and Prepared By in same row
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(flex: 2, child: _buildBankDetails()),
                      pw.SizedBox(width: 20),
                      pw.Expanded(
                        flex: 1,
                        child: _buildPreparedBy(signatureImage),
                      ),
                    ],
                  ),

                  // Footer
                  pw.Spacer(),
                  _buildFooter(bankDetailsPageNumber, totalPages),
                ],
              ),
            );
          },
        ),
      );
    } else {
      // If no line items: Page 2 = Totals, Page 3 = Bank Details
      // Add Totals page
      final totalsPageNumber = 2;
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.all(pageMargin),
          theme: pw.ThemeData.withFont(
            base: englishFont,
            bold: englishBoldFont,
            fontFallback: [arabicFont, arabicBoldFont],
          ),
          build: (pw.Context context) {
            return pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1),
              ),
              padding: const pw.EdgeInsets.all(8),
              child: pw.Column(
                children: [
                  // Header
                  _buildHeader(logo, arabicBoldFont),
                  pw.SizedBox(height: 20),

                  // Totals Section
                  _buildTotalsSection(invoice, arabicFont, arabicBoldFont),

                  // Footer
                  pw.Spacer(),
                  _buildFooter(totalsPageNumber, totalPages),
                ],
              ),
            );
          },
        ),
      );

      // Add Bank Details page
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.all(pageMargin),
          theme: pw.ThemeData.withFont(
            base: englishFont,
            bold: englishBoldFont,
            fontFallback: [arabicFont, arabicBoldFont],
          ),
          build: (pw.Context context) {
            return pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1),
              ),
              padding: const pw.EdgeInsets.all(8),
              child: pw.Column(
                children: [
                  // Header
                  _buildHeader(logo, arabicBoldFont),
                  pw.SizedBox(height: 20),

                  // Bank Details and Prepared By in same row
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(flex: 2, child: _buildBankDetails()),
                      pw.SizedBox(width: 20),
                      pw.Expanded(
                        flex: 1,
                        child: _buildPreparedBy(signatureImage),
                      ),
                    ],
                  ),

                  // Footer
                  pw.Spacer(),
                  _buildFooter(totalPages, totalPages),
                ],
              ),
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  pw.Widget _buildHeader(pw.ImageProvider? logo, pw.Font arabicBoldFont) {
    return pw.Container(
      width: 450,
      height: 100,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1.2),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 1),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Padding(
                padding: pw.EdgeInsets.only(top: 20),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      CompanyInfo.companyNameEn,
                      style: pw.TextStyle(
                        fontSize: 26,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      CompanyInfo.companyNameEn2,
                      style: pw.TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),

              // Logo placeholder
              pw.Column(
                children: [
                  pw.Container(
                    width: 80,
                    height: 80,
                    child: logo != null
                        ? pw.Image(logo, fit: pw.BoxFit.contain)
                        : pw.Center(
                            child: pw.Text(
                              'XK',
                              style: pw.TextStyle(
                                fontSize: 30,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey700,
                              ),
                            ),
                          ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    CompanyInfo.crNumber,
                    style: pw.TextStyle(fontSize: 10),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      CompanyInfo.companyNameAr,
                      style: pw.TextStyle(
                        fontSize: 26,
                        fontWeight: pw.FontWeight.bold,
                        height: 0.6,
                        font: arabicBoldFont,
                      ),
                      textDirection: pw.TextDirection.rtl,
                    ),
                    pw.Transform.translate(
                      offset: const PdfPoint(0, 12),
                      child: pw.Text(
                        CompanyInfo.companyNameAr2,
                        style: pw.TextStyle(fontSize: 18, height: 0.6),
                        textDirection: pw.TextDirection.rtl,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildInvoiceDetails(InvoiceModel invoice, pw.Font arabicBoldFont) {
    final dateFormat = DateFormat('yyyy-MM-dd');

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 1.2),
      columnWidths: {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(2),
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 4,
              ),
              child: pw.Text(
                'INVOICE',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 4,
              ),
              child: pw.Text(
                'فاتورة',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  font: arabicBoldFont,
                ),
                textAlign: pw.TextAlign.right,
                textDirection: pw.TextDirection.rtl,
              ),
            ),
          ],
        ),
        // Date row
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 4,
              ),
              child: pw.Text('Date', style: pw.TextStyle(fontSize: 11)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 4,
              ),
              child: pw.Text(
                style: pw.TextStyle(fontSize: 11),
                dateFormat.format(invoice.date),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
        // Invoice Number row
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 4,
              ),
              child: pw.Text(
                'Invoice Number',
                style: pw.TextStyle(fontSize: 11),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 4,
              ),
              child: pw.Text(
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
                invoice.invoiceNumber,
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
        // Contract reference row
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 4,
              ),
              child: pw.Text(
                'Contract reference',
                style: pw.TextStyle(fontSize: 11),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 4,
              ),
              child: pw.Text(
                style: pw.TextStyle(fontSize: 11),
                invoice.contractReference,
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
        // Payment terms row
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 4,
              ),
              child: pw.Text(
                'Payment terms',
                style: pw.TextStyle(fontSize: 11),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 4,
              ),
              child: pw.Text(
                style: pw.TextStyle(fontSize: 11),
                invoice.paymentTerms,
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildBillToSection(dynamic customer) {
    return pw.SizedBox(
      width: double.infinity,
      child: pw.Container(
        height: 128,
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black, width: 1.2),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'BILL TO:',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                decoration: pw.TextDecoration.underline,
              ),
            ),
            pw.SizedBox(height: 3),
            if (customer != null) ...[
              pw.Text(
                customer.companyName,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 1),
              if (customer.country != null && customer.country!.isNotEmpty)
                pw.Text(
                  customer.country!,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              if (customer.country != null && customer.country!.isNotEmpty)
                pw.SizedBox(height: 1),
              if (customer.streetAddress != null &&
                  customer.buildingNumber != null)
                pw.Text(
                  '${customer.streetAddress}, Bldg ${customer.buildingNumber}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              if (customer.streetAddress != null &&
                  customer.buildingNumber != null)
                pw.SizedBox(height: 1),
              if (customer.district != null)
                pw.Text(
                  customer.addressAdditionalNumber != null &&
                          customer.addressAdditionalNumber!.isNotEmpty
                      ? '${customer.district}, Addl. No: ${customer.addressAdditionalNumber}'
                      : customer.district!,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              if (customer.district != null) pw.SizedBox(height: 2),
              if (customer.city != null && customer.postalCode != null)
                pw.Text(
                  '${customer.city}, ${customer.postalCode}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              if (customer.city != null && customer.postalCode != null)
                pw.SizedBox(height: 2),
              if (customer.taxRegistrationNumber != null &&
                  customer.taxRegistrationNumber!.isNotEmpty)
                pw.Text(
                  'VAT No #: ${customer.taxRegistrationNumber}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              if (customer.taxRegistrationNumber != null &&
                  customer.taxRegistrationNumber!.isNotEmpty)
                pw.SizedBox(height: 1),
              if (customer.email != null && customer.email!.isNotEmpty) ...[
                pw.Text(
                  'Attn:',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  customer.email!,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ] else
              pw.Text(
                '(Customer Name & Address)',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildLineItemsTable(
    List<dynamic> lineItems,
    int startIndex,
    pw.Font arabicBoldFont,
    pw.Font arabicFont, {
    bool showHeader = true,
    bool showFooter = false,
    InvoiceModel? invoice,
  }) {
    if (lineItems.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(12),
        child: pw.Text(
          'No line items',
          style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
        ),
      );
    }

    // Helper for formatting numbers
    String formatNumber(double value) {
      return NumberFormat.currency(symbol: '', decimalDigits: 2).format(value);
    }

    String formatArabicNumber(double value) {
      String formatted = NumberFormat.currency(
        symbol: '',
        decimalDigits: 2,
      ).format(value);
      return _toArabicString(formatted);
    }

    // Check if discount column should be shown
    final bool showDiscountColumn = invoice != null && invoice.discount > 0;

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: showDiscountColumn
          ? {
              0: const pw.FlexColumnWidth(0.7),
              1: const pw.FlexColumnWidth(2.6),
              2: const pw.FlexColumnWidth(0.9),
              3: const pw.FlexColumnWidth(0.9),
              4: const pw.FlexColumnWidth(1.3),
              5: const pw.FlexColumnWidth(1.3),
              6: const pw.FlexColumnWidth(1.3),
            }
          : {
              0: const pw.FlexColumnWidth(0.7),
              1: const pw.FlexColumnWidth(2.6),
              2: const pw.FlexColumnWidth(0.9),
              3: const pw.FlexColumnWidth(0.9),
              4: const pw.FlexColumnWidth(1.3),
              5: const pw.FlexColumnWidth(1.3),
            },
      children: [
        if (showHeader)
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              _buildHeaderCell('L/I', 'البند', arabicBoldFont),
              _buildHeaderCell('DESCRIPTION', 'الأوصاف', arabicBoldFont),
              _buildHeaderCell(
                'QTY',
                'الكمية',
                arabicBoldFont,
                alignCenter: true,
              ),
              _buildHeaderCell(
                'UNIT',
                'الوحدة',
                arabicBoldFont,
                alignCenter: true,
              ),
              _buildHeaderCell(
                'SUBTOTAL AMOUNT',
                'المجموع الفرعي',
                arabicBoldFont,
                alignCenter: true,
              ),
              if (showDiscountColumn)
                _buildHeaderCell(
                  'DISCOUNT RATE ${invoice.discount == invoice.discount.toInt() ? invoice.discount.toInt() : invoice.discount}%',
                  'تخفيض',
                  arabicBoldFont,
                  alignCenter: true,
                ),
              _buildHeaderCell(
                'TOTAL AMOUNT',
                'الإجمالي',
                arabicBoldFont,
                alignCenter: true,
              ),
            ],
          ),
        // Data rows
        ...lineItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final rowNumber = startIndex + index;
          final englishDescription = item.description.isNotEmpty
              ? item.description
              : 'TRANSPORTATION CHARGES';
          final referenceCode = item.referenceCode?.trim() ?? '';
          const arabicDescription = 'رسوم خدمة التحويل';
          final unitQuantity = item.unit.isNotEmpty ? item.unit : '1';
          final unitType = (item.unitType.isNotEmpty ? item.unitType : 'LOT')
              .toUpperCase();
          final unitTypeArabic = unitType == 'EA' ? 'حبة' : 'لوط';

          final discountAmount = invoice != null
              ? item.subtotalAmount * (invoice.discount / 100)
              : 0.0;

          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: rowNumber % 2 == 0 ? PdfColors.white : PdfColors.grey100,
            ),
            children: [
              _buildDualLangCell(
                english: '$rowNumber',
                arabic: _toArabicNumber(rowNumber),
              ),
              _buildDescriptionCell(
                englishDescription,
                referenceCode,
                arabicDescription,
                arabicFont,
              ),
              _buildDualLangCell(
                english: unitQuantity,
                arabic: _toArabicString(unitQuantity),
                alignCenter: true,
              ),
              _buildDualLangCell(
                english: unitType,
                arabic: unitTypeArabic,
                alignCenter: true,
                isRtl: true,
              ),
              _buildDualLangCell(
                english: formatNumber(item.subtotalAmount),
                arabic: formatArabicNumber(item.subtotalAmount),
                alignCenter: true,
              ),
              if (showDiscountColumn)
                _buildDualLangCell(
                  english: formatNumber(discountAmount),
                  arabic: formatArabicNumber(discountAmount),
                  alignCenter: true,
                ),
              _buildDualLangCell(
                english: formatNumber(item.totalAmount - discountAmount),
                arabic: formatArabicNumber(item.totalAmount - discountAmount),
                alignCenter: true,
                isBold: false,
              ),
            ],
          );
        }),
        // Footer Row with Totals
        if (showFooter && invoice != null)
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              _buildTableCell('', isHeader: true), // L/I
              _buildHeaderCell(
                'TOTALS',
                'المجاميع',
                arabicBoldFont,
              ), // Description
              _buildTableCell('', isHeader: true), // Qty
              _buildTableCell('', isHeader: true), // Unit
              _buildDualLangCell(
                english: formatNumber(invoice.subtotalAmount),
                arabic: formatArabicNumber(invoice.subtotalAmount),
                alignCenter: true,
                isBold: true,
              ), // Subtotal
              if (showDiscountColumn)
                _buildDualLangCell(
                  english: formatNumber(invoice.totalDiscount),
                  arabic: formatArabicNumber(invoice.totalDiscount),
                  alignCenter: true,
                  isBold: true,
                ), // Discount
              _buildDualLangCell(
                english: formatNumber(invoice.totalAmount),
                arabic: formatArabicNumber(invoice.totalAmount),
                alignCenter: true,
                isBold: true,
              ), // Total
            ],
          ),
      ],
    );
  }

  pw.Widget _buildHeaderCell(
    String english,
    String arabic,
    pw.Font arabicBoldFont, {
    bool alignCenter = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Column(
        crossAxisAlignment: alignCenter
            ? pw.CrossAxisAlignment.center
            : pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            english,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            textAlign: alignCenter ? pw.TextAlign.center : pw.TextAlign.left,
          ),
          pw.Text(
            arabic,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              font: arabicBoldFont,
            ),
            textAlign: alignCenter ? pw.TextAlign.center : pw.TextAlign.right,
            textDirection: pw.TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  String _toArabicString(String input) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return input.split('').map((char) {
      if (RegExp(r'[0-9]').hasMatch(char)) {
        return arabicDigits[int.parse(char)];
      }
      return char;
    }).join();
  }

  pw.Widget _buildDualLangCell({
    required String english,
    required String arabic,
    bool alignCenter = false,
    bool alignRight = false,
    bool isBold = false,
    bool isRtl = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Column(
        crossAxisAlignment: alignCenter
            ? pw.CrossAxisAlignment.center
            : (alignRight
                  ? pw.CrossAxisAlignment.end
                  : pw.CrossAxisAlignment.start),
        children: [
          pw.Text(
            english,
            style: pw.TextStyle(
              fontSize: isBold ? 9 : 8,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
            textAlign: alignCenter
                ? pw.TextAlign.center
                : (alignRight ? pw.TextAlign.right : pw.TextAlign.left),
          ),
          pw.Text(
            arabic,
            style: pw.TextStyle(
              fontSize: isBold ? 9 : 8,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
            textAlign: alignCenter
                ? pw.TextAlign.center
                : (alignRight ? pw.TextAlign.right : pw.TextAlign.right),
            textDirection: isRtl ? pw.TextDirection.rtl : null,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    bool isArabic = false,
    bool alignRight = false,
    bool alignCenter = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 9 : 8,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: alignCenter
            ? pw.TextAlign.center
            : (alignRight ? pw.TextAlign.right : pw.TextAlign.left),
        textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      ),
    );
  }

  pw.Widget _buildDescriptionCell(
    String englishDescription,
    String referenceCode,
    String arabicDescription,
    pw.Font arabicFont,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(englishDescription, style: pw.TextStyle(fontSize: 9)),
          if (referenceCode.isNotEmpty)
            pw.Text(
              referenceCode,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),

          pw.Text(
            arabicDescription,
            style: pw.TextStyle(fontSize: 9, font: arabicFont),
            textDirection: pw.TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  String _toArabicNumber(int number) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return number
        .toString()
        .split('')
        .map((digit) => arabicDigits[int.parse(digit)])
        .join();
  }

  pw.Widget _buildTotalsSection(
    InvoiceModel invoice,
    pw.Font arabicFont,
    pw.Font arabicBoldFont,
  ) {
    // Helper for formatting numbers
    String formatNumber(double value) {
      return NumberFormat.currency(symbol: '', decimalDigits: 2).format(value);
    }

    String formatArabicNumber(double value) {
      String formatted = NumberFormat.currency(
        symbol: '',
        decimalDigits: 2,
      ).format(value);
      return _toArabicString(formatted);
    }

    // Helper to build a bordered box
    pw.Widget buildBox({
      required pw.Widget child,
      double? width,
      double? height,
      pw.BoxBorder? border,
    }) {
      return pw.Container(
        width: width,
        height: height,
        decoration: pw.BoxDecoration(
          border: border ?? pw.Border.all(color: PdfColors.black),
        ),
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: child,
      );
    }

    // Helper for the right-side rows
    pw.Widget buildRightRow(
      String labelEn,
      String labelAr,
      double value, {
      bool isBold = false,
    }) {
      return pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  '$labelEn: SR',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: isBold
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal,
                  ),
                ),
                pw.Text(
                  '$labelAr: ريال سعودي',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: isBold
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal,
                    font: isBold ? arabicBoldFont : arabicFont,
                  ),
                  textDirection: pw.TextDirection.rtl,
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                formatNumber(value),
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: isBold
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                ),
              ),
              pw.Text(
                formatArabicNumber(value),
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: isBold
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                ),
              ),
            ],
          ),
        ],
      );
    }

    const double rightColWidth = 220;
    const double bottomRowHeight = 50;

    return pw.Column(
      children: [
        // Row 1: Empty Left + Total Amount Right
        pw.Row(
          children: [
            pw.Expanded(child: pw.Container()), // Empty space
            buildBox(
              width: rightColWidth,
              child: buildRightRow(
                'Sub Total',
                'الإجمالي',
                invoice.totalAmount,
              ),
            ),
          ],
        ),
        // Row 2: Empty Left + WHT or Discount Right (depending on taxRate)
        pw.Row(
          children: [
            pw.Expanded(child: pw.Container()), // Empty space
            buildBox(
              width: rightColWidth,
              border: const pw.Border(
                left: pw.BorderSide(),
                right: pw.BorderSide(),
                bottom: pw.BorderSide(),
              ), // No top border
              child: invoice.taxRate > 0
                  ? buildRightRow(
                      'WHT ${invoice.taxRate}%',
                      'ضريبة الاستقطاع',
                      invoice.taxAmount,
                    )
                  : buildRightRow('Discount ${invoice.discount}%', 'خصم', 0.0),
            ),
          ],
        ),
        // Row 3: Words Left + Grand Total Right
        pw.Row(
          children: [
            pw.Expanded(
              child: buildBox(
                height: bottomRowHeight,
                border: const pw.Border(
                  top: pw.BorderSide(),
                  left: pw.BorderSide(),
                  bottom: pw.BorderSide(),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.RichText(
                      text: pw.TextSpan(
                        children: [
                          pw.TextSpan(
                            text: 'Total: ',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.TextSpan(
                            text:
                                '${NumberToWordsService.convertEn(invoice.grandTotal)} Saudi Riyals Only',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.RichText(
                      textDirection: pw.TextDirection.rtl,
                      text: pw.TextSpan(
                        children: [
                          pw.TextSpan(
                            text: 'الإجمالي: ',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              font: arabicBoldFont,
                            ),
                          ),
                          pw.TextSpan(
                            text:
                                '${NumberToWordsService.convertAr(invoice.grandTotal)} ريال سعودي فقط',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              font: arabicBoldFont,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            buildBox(
              width: rightColWidth,
              height: bottomRowHeight,
              border: const pw.Border(
                left: pw.BorderSide(),
                right: pw.BorderSide(),
                bottom: pw.BorderSide(),
              ),
              child: buildRightRow(
                'Grand Total',
                'المجموع الكلي',
                invoice.grandTotal,
                isBold: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildBankDetails() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1.2),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Bank Details',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 16),
          _buildBankDetailRow('Account Name:', CompanyInfo.accountName),
          _buildBankDetailRow('Account Number:', CompanyInfo.accountNumber),
          _buildBankDetailRow('IBAN:', CompanyInfo.iban),
          _buildBankDetailRow('Bank Name:', CompanyInfo.bankName),
          _buildBankDetailRow('SWIFT Code:', CompanyInfo.swiftCode),
          _buildBankDetailRow('Currency:', CompanyInfo.currency),
        ],
      ),
    );
  }

  pw.Widget _buildPreparedBy(pw.ImageProvider? signatureImage) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (signatureImage != null) pw.Image(signatureImage, height: 90),
        if (signatureImage != null) pw.SizedBox(height: 8),
        pw.Text(
          'Prepared By',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text('Muhammed Saleh', style: pw.TextStyle(fontSize: 11)),
      ],
    );
  }

  pw.Widget _buildBankDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(width: 8),
          pw.Text(value, style: pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(int pageNumber, int totalPages) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 1),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,

                  children: [
                    pw.Text(
                      'TRN No# ${CompanyInfo.trnNumber}',
                      style: pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      CompanyInfo.addressEn,
                      style: pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      'Contact: ${CompanyInfo.contact}',
                      style: pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      'Email: ${CompanyInfo.email}',
                      style: pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),

              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'رقم الضريبة # ${CompanyInfo.trnNumberAr}',
                      style: pw.TextStyle(fontSize: 9, height: 0.0),
                      textDirection: pw.TextDirection.rtl,
                    ),
                    pw.Transform.translate(
                      offset: const PdfPoint(0, 4),
                      child: pw.Text(
                        CompanyInfo.addressAr,
                        style: pw.TextStyle(fontSize: 9, height: 0.0),
                        textDirection: pw.TextDirection.rtl,
                      ),
                    ),
                    pw.Transform.translate(
                      offset: const PdfPoint(0, 8),
                      child: pw.Text(
                        'الاتصال: ${CompanyInfo.contactAr}',
                        style: pw.TextStyle(fontSize: 9, height: 0.0),
                        textDirection: pw.TextDirection.rtl,
                      ),
                    ),
                    pw.Transform.translate(
                      offset: const PdfPoint(0, 12),
                      child: pw.Text(
                        'البريد الإلكتروني: ${CompanyInfo.email}',
                        style: pw.TextStyle(fontSize: 9, height: 0.0),
                        textDirection: pw.TextDirection.rtl,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Center(
            child: pw.Text('$pageNumber', style: pw.TextStyle(fontSize: 9)),
          ),
        ],
      ),
    );
  }
}
