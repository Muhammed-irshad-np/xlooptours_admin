import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../models/invoice_model.dart';
import '../services/pdf_service.dart';
import '../widgets/responsive_layout.dart';

// Conditional imports for platform-specific APIs
import 'dart:io' show File if (dart.library.html) '';
import 'dart:html' as html if (dart.library.io) '';

class PDFPreviewScreen extends StatelessWidget {
  final InvoiceModel invoice;
  final bool showActionButtons;

  const PDFPreviewScreen({
    super.key,
    required this.invoice,
    this.showActionButtons = true,
  });

  Future<void> _savePDF(BuildContext context, Uint8List pdfBytes) async {
    if (kIsWeb) {
      _savePDFWeb(context, pdfBytes);
    } else {
      _savePDFMobile(context, pdfBytes);
    }
  }

  void _savePDFWeb(BuildContext context, Uint8List pdfBytes) {
    try {
      final customerName = invoice.company?.companyName ?? 'Customer';
      final sanitizedCustomerName = customerName.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_');
      final fileName = '${invoice.invoiceNumber}_$sanitizedCustomerName.pdf';

      // Create a blob from the PDF bytes
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);

      // Create anchor element and trigger download
      final anchor = html.AnchorElement()
        ..href = url
        ..download = fileName
        ..click();

      // Clean up
      html.Url.revokeObjectUrl(url);

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('PDF downloaded: $fileName')));
      }
    } catch (e) {
      debugPrint('Error saving PDF on web: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving PDF: $e')));
      }
    }
  }

  Future<void> _savePDFMobile(BuildContext context, Uint8List pdfBytes) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final customerName = invoice.company?.companyName ?? 'Customer';
      final sanitizedCustomerName = customerName.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_');
      final fileName = '${invoice.invoiceNumber}_$sanitizedCustomerName.pdf';
      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(pdfBytes);

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('PDF saved to: ${file.path}')));
      }
    } catch (e) {
      debugPrint('Error saving PDF: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving PDF: $e')));
      }
    }
  }

  Future<void> _sharePDF(BuildContext context, Uint8List pdfBytes) async {
    if (kIsWeb) {
      _sharePDFWeb(context, pdfBytes);
    } else {
      _sharePDFMobile(context, pdfBytes);
    }
  }

  void _sharePDFWeb(BuildContext context, Uint8List pdfBytes) {
    try {
      final customerName = invoice.company?.companyName ?? 'Customer';
      final sanitizedCustomerName = customerName.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_');
      final fileName = '${invoice.invoiceNumber}_$sanitizedCustomerName.pdf';

      // On web, we'll just download the file (Web Share API has limited support for PDFs)
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);

      final anchor = html.AnchorElement()
        ..href = url
        ..download = fileName
        ..click();

      html.Url.revokeObjectUrl(url);

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('PDF downloaded: $fileName')));
      }
    } catch (e) {
      debugPrint('Error sharing PDF on web: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sharing PDF: $e')));
      }
    }
  }

  Future<void> _sharePDFMobile(BuildContext context, Uint8List pdfBytes) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final customerName = invoice.company?.companyName ?? 'Customer';
      final sanitizedCustomerName = customerName.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_');
      final fileName = '${invoice.invoiceNumber}_$sanitizedCustomerName.pdf';
      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(pdfBytes);

      if (file.existsSync()) {
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'Invoice ${invoice.invoiceNumber}');
      }
    } catch (e) {
      debugPrint('Error sharing PDF: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sharing PDF: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invoice Preview')),
      body: FutureBuilder<List<int>>(
        future: PDFService().generateInvoicePDF(invoice),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error generating PDF: ${snapshot.error}'),
                ],
              ),
            );
          }

          final pdfBytes = Uint8List.fromList(snapshot.data!);

          return Column(
            children: [
              Expanded(
                child: PdfPreview(
                  build: (format) async => pdfBytes,
                  useActions: false,
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  canDebug: false,
                ),
              ),
              if (showActionButtons)
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: ResponsiveLayout(
                    mobile: Row(
                      children: _buildActionButtons(context, pdfBytes),
                    ),
                    desktop: Center(
                      child: SizedBox(
                        width: 600,
                        child: Row(
                          children: _buildActionButtons(context, pdfBytes),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildActionButtons(BuildContext context, Uint8List pdfBytes) {
    if (kIsWeb) {
      // On web, only show Save button (share does the same thing)
      return [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _savePDF(context, pdfBytes),
            icon: const Icon(Icons.download),
            label: const Text('Download PDF'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ];
    }
    
    // On mobile, show both Save and Share buttons
    return [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () => _savePDF(context, pdfBytes),
          icon: const Icon(Icons.save_alt),
          label: const Text('Save PDF'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: ElevatedButton.icon(
          onPressed: () => _sharePDF(context, pdfBytes),
          icon: const Icon(Icons.share),
          label: const Text('Share PDF'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    ];
  }
}
