import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/features/finance/data/models/fund_transaction_model.dart';

void main() {
  Map<String, dynamic> baseJson() => {
        'id': '3f9a2c1b-7e4d-4a0b-9c2e-1234567890ab',
        'fundAccountId': 'acc-1',
        'type': 'deposit',
        'amount': 500.0,
        'currency': 'SAR',
        'description': 'Cash deposit',
        'performedBy': 'Tester',
        'date': '2026-11-19T10:00:00.000',
        'createdAt': '2026-11-19T10:00:00.000',
        'balanceBefore': 0.0,
        'balanceAfter': 500.0,
      };

  test('referenceNumber survives a JSON round trip and is displayed', () {
    final tx = FundTransactionModel.fromJson(
      {...baseJson(), 'referenceNumber': 'TXN-10042'},
    );
    expect(tx.referenceNumber, 'TXN-10042');
    expect(tx.displayReference, 'TXN-10042');
    expect(tx.toJson()['referenceNumber'], 'TXN-10042');
    expect(FundTransactionModel.fromEntity(tx).referenceNumber, 'TXN-10042');
  });

  test('unnumbered rows fall back to a short form of the document id', () {
    final tx = FundTransactionModel.fromJson(baseJson());
    expect(tx.referenceNumber, isNull);
    expect(tx.displayReference, 'TX-3F9A2C1B');
  });
}
