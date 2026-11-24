import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/features/finance/domain/entities/salary_entity.dart';
import 'package:xloop_invoice/features/finance/domain/services/payment_receipt_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final payment = SalaryPaymentEntity(
    id: 'trip_2026-11_emp123456',
    period: '2026-11',
    kind: SalaryPaymentKind.tripSettlement,
    employeeId: 'emp123456',
    employeeName: 'Ahmed Ali',
    basicSalary: 1200,
    tripCount: 12,
    extraAllowance: 50,
    extraAllowanceNote: 'fuel',
    advanceRecovery: 100,
    netAmount: 1150,
    paymentMethod: 'stcPay',
    status: SalaryPaymentStatus.paid,
    paidAt: DateTime(2026, 11, 24),
    paidBy: 'Coordinator',
    createdAt: DateTime(2026, 11, 1),
  );

  group('whatsAppNumber', () {
    test('adds the country code to a local number', () {
      expect(PaymentReceiptService.whatsAppNumber('+966', '0501234567'),
          '966501234567');
      expect(PaymentReceiptService.whatsAppNumber('+973', '33528661'),
          '97333528661');
    });
    test('keeps a number that already has its country code', () {
      expect(PaymentReceiptService.whatsAppNumber('+966', '966501234567'),
          '966501234567');
      expect(PaymentReceiptService.whatsAppNumber('+966', '+973 3352 8661'),
          '97333528661');
      expect(PaymentReceiptService.whatsAppNumber(null, '00966501234567'),
          '966501234567');
    });
    test('is empty without a number', () {
      expect(PaymentReceiptService.whatsAppNumber('+966', ''), '');
      expect(PaymentReceiptService.whatsAppNumber('+966', null), '');
    });
  });

  test('receipt number and text', () {
    expect(PaymentReceiptService.receiptNumber(payment), 'RCP-202611-123456');
    final text = PaymentReceiptService.whatsAppText(payment);
    expect(text, contains('Paid to: Ahmed Ali'));
    expect(text, contains('Trip payment - November 2026 (12 trips)'));
    expect(text, contains('Trip earnings: 1,200.00 SAR'));
    expect(text, contains('Extra (fuel): 50.00 SAR'));
    expect(text, contains('Advance recovered: - 100.00 SAR'));
    expect(text, contains('*Net paid: 1,150.00 SAR*'));
    expect(text, contains('Paid via: STC Pay'));
  });

  test('builds a PDF, even with non-Latin names', () async {
    final bytes = await PaymentReceiptService.buildPdf(
      SalaryPaymentEntity(
        id: 'x',
        period: '2026-11',
        kind: SalaryPaymentKind.tripSettlement,
        employeeId: 'e1',
        employeeName: 'أحمد — Ahmed',
        basicSalary: 500,
        netAmount: 500,
        createdAt: DateTime(2026, 11, 1),
      ),
      phone: '+966501234567',
    );
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
