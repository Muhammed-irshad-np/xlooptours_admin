import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/core/utils/session_expiry.dart';

void main() {
  group('loginPredatesCutoff', () {
    test('keeps a login from the same working day', () {
      expect(
        loginPredatesCutoff(DateTime(2026, 10, 28, 9),
            now: DateTime(2026, 10, 28, 18)),
        isFalse,
      );
    });

    test('keeps an evening login alive until 4 AM', () {
      expect(
        loginPredatesCutoff(DateTime(2026, 10, 27, 18),
            now: DateTime(2026, 10, 28, 3, 59)),
        isFalse,
      );
    });

    test('expires a login once 4 AM passes', () {
      expect(
        loginPredatesCutoff(DateTime(2026, 10, 27, 18),
            now: DateTime(2026, 10, 28, 4)),
        isTrue,
      );
      expect(
        loginPredatesCutoff(DateTime(2026, 10, 28, 2),
            now: DateTime(2026, 10, 28, 5)),
        isTrue,
      );
    });

    test('treats an unknown sign-in time as expired', () {
      expect(loginPredatesCutoff(null), isTrue);
    });
  });
}
