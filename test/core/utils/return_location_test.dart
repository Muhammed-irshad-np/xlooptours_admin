import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/core/utils/return_location.dart';

void main() {
  group('safeReturnLocation', () {
    test('returns the in-app location the user came from', () {
      expect(safeReturnLocation('/home?tab=employees'), '/home?tab=employees');
      expect(safeReturnLocation('/invoices'), '/invoices');
    });

    test('falls back to /home for missing or unsafe values', () {
      expect(safeReturnLocation(null), '/home');
      expect(safeReturnLocation('/'), '/home');
      expect(safeReturnLocation('/login?from=/home'), '/home');
      expect(safeReturnLocation('https://evil.example'), '/home');
      expect(safeReturnLocation('//evil.example'), '/home');
    });
  });
}
