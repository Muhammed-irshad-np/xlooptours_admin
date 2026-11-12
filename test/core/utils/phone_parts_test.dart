import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/core/utils/phone_parts.dart';

void main() {
  void expectSplit(String raw, String code, String number) {
    final parts = splitStoredPhone(raw);
    expect(parts.code, code, reason: 'code for "$raw"');
    expect(parts.number, number, reason: 'number for "$raw"');
  }

  test('current format splits at the space', () {
    expectSplit('+966 501234567', '+966', '501234567');
    expectSplit('+44 7700900123', '+44', '7700900123');
  });

  test('legacy Saudi number without a space moves 966 into the prefix', () {
    expectSplit('966501234567', '+966', '501234567');
    expectSplit('+966501234567', '+966', '501234567');
    expectSplit('966 501234567', '+966', '501234567');
  });

  test('doubled country code from the old bug is repaired', () {
    expectSplit('+966 966501234567', '+966', '501234567');
  });

  test('numbers without a recognisable code are left as they are', () {
    expectSplit('501234567', '+966', '501234567');
    expectSplit('0501234567', '+966', '0501234567');
    expectSplit('96650123', '+966', '96650123');
  });
}
