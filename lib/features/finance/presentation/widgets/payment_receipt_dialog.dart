import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/utils/file_download.dart';
import '../../domain/entities/salary_entity.dart';
import '../../domain/services/payment_receipt_service.dart';
import '../pages/finance_dashboard_page.dart';
import 'finance_dialog_helpers.dart';

const _whatsAppGreen = Color(0xFF25D366);

/// Shows the receipt for a paid [payment] and lets the user send it to the
/// person who was paid: as a WhatsApp message to [phone], or as a PDF through
/// the share sheet (WhatsApp, email, ...) or a download.
Future<void> showPaymentReceiptDialog(
  BuildContext context, {
  required SalaryPaymentEntity payment,
  String? countryCode,
  String? phone,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _PaymentReceiptDialog(
      payment: payment,
      initialNumber: PaymentReceiptService.whatsAppNumber(countryCode, phone),
    ),
  );
}

class _PaymentReceiptDialog extends StatefulWidget {
  final SalaryPaymentEntity payment;
  final String initialNumber;

  const _PaymentReceiptDialog({
    required this.payment,
    required this.initialNumber,
  });

  @override
  State<_PaymentReceiptDialog> createState() => _PaymentReceiptDialogState();
}

class _PaymentReceiptDialogState extends State<_PaymentReceiptDialog> {
  late final TextEditingController _phoneCtrl;
  bool _busy = false;

  SalaryPaymentEntity get _p => widget.payment;

  @override
  void initState() {
    super.initState();
    _phoneCtrl = TextEditingController(
      text: widget.initialNumber.isEmpty ? '' : '+${widget.initialNumber}',
    );
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  String get _phoneForReceipt => _phoneCtrl.text.trim();

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  Future<void> _sendWhatsApp() async {
    final number = PaymentReceiptService.whatsAppNumber(null, _phoneCtrl.text);
    final text = Uri.encodeComponent(PaymentReceiptService.whatsAppText(_p));
    final uri = Uri.parse('https://wa.me/$number?text=$text');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _snack('Could not open WhatsApp.', FinDT.danger);
  }

  Future<void> _sharePdf({required bool download}) async {
    setState(() => _busy = true);
    try {
      final bytes =
          await PaymentReceiptService.buildPdf(_p, phone: _phoneForReceipt);
      final name = PaymentReceiptService.fileName(_p);
      if (download) {
        await saveFileBytes(
          bytes: bytes,
          fileName: name,
          mimeType: 'application/pdf',
        );
      } else {
        await Share.shareXFiles(
          [XFile.fromData(bytes, name: name, mimeType: 'application/pdf')],
          subject: 'Payment receipt - ${_p.employeeName}',
          text: 'Payment receipt ${PaymentReceiptService.receiptNumber(_p)}',
          fileNameOverrides: [name],
        );
      }
    } catch (e) {
      _snack('Could not prepare the receipt: $e', FinDT.danger);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: finDialogShape,
      title: finDialogTitle('Payment Receipt', icon: Icons.receipt_long_outlined),
      content: SizedBox(
        width: 440.w,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 8.h),
              _ReceiptPreview(payment: _p),
              SizedBox(height: 16.h),
              Text(
                'Driver\'s WhatsApp number',
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: FinDT.textSecondary,
                ),
              ),
              SizedBox(height: 6.h),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.inter(fontSize: 13.sp),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '+966 5X XXX XXXX',
                  helperText: _phoneCtrl.text.trim().isEmpty
                      ? 'No number on file — WhatsApp will ask who to send to.'
                      : null,
                  prefixIcon: Icon(Icons.phone_outlined, size: 18.sp),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
      actions: [
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8.w,
          runSpacing: 8.h,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _sharePdf(download: true),
              icon: Icon(Icons.download_outlined, size: 16.sp),
              label: const Text('Download PDF'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _sharePdf(download: false),
              icon: Icon(Icons.ios_share_outlined, size: 16.sp),
              label: const Text('Share PDF'),
            ),
            finDialogActionButton(
              onPressed: _busy ? null : _sendWhatsApp,
              label: 'Send on WhatsApp',
              icon: Icons.chat_outlined,
              backgroundColor: _whatsAppGreen,
              isLoading: _busy,
            ),
          ],
        ),
      ],
    );
  }
}

/// On-screen copy of the receipt, so the user sees what the driver will get.
class _ReceiptPreview extends StatelessWidget {
  final SalaryPaymentEntity payment;

  const _ReceiptPreview({required this.payment});

  @override
  Widget build(BuildContext context) {
    final p = payment;
    TextStyle muted([double size = 11]) =>
        GoogleFonts.inter(fontSize: size.sp, color: FinDT.textSecondary);

    Widget amount(ReceiptLine l) => Padding(
          padding: EdgeInsets.symmetric(vertical: 4.h),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.label,
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: FinDT.textPrimary,
                  ),
                ),
              ),
              Text(
                '${l.isDeduction ? '− ' : ''}'
                '${PaymentReceiptService.money(l.amount, p.currency)}',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: l.isDeduction ? FinDT.danger : FinDT.textPrimary,
                ),
              ),
            ],
          ),
        );

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: FinDT.bgPage,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: FinDT.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  PaymentReceiptService.companyName,
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: FinDT.brand,
                  ),
                ),
              ),
              Text(PaymentReceiptService.receiptNumber(p), style: muted(10)),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            p.employeeName,
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: FinDT.textPrimary,
            ),
          ),
          SizedBox(height: 2.h),
          Text(PaymentReceiptService.purpose(p), style: muted()),
          Text(
            'Paid ${PaymentReceiptService.paidOn(p)} · '
            '${PaymentReceiptService.methodLabel(p.paymentMethod)}',
            style: muted(),
          ),
          Divider(height: 20.h, color: FinDT.border),
          ...PaymentReceiptService.lines(p).map(amount),
          Divider(height: 16.h, color: FinDT.border),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Net paid',
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: FinDT.textPrimary,
                  ),
                ),
              ),
              Text(
                PaymentReceiptService.money(p.netAmount, p.currency),
                style: GoogleFonts.inter(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: FinDT.brand,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
