import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/core/utils/input_validators.dart';

void main() {
  group('InputValidators.personName', () {
    test('accepts real names', () {
      for (final n in ['John', 'Mary Jane', "O'Neil", 'Anne-Marie', 'J. Smith', 'José Ñúñez', 'Muhammed Irshad']) {
        expect(InputValidators.personName(n), isNull, reason: n);
      }
    });
    test('rejects empty, digits and special characters', () {
      for (final n in ['', '   ', 'A', 'John123', 'John@', 'J#hn', '123', 'John_Doe', '--', 'John  Doe']) {
        expect(InputValidators.personName(n), isNotNull, reason: n);
      }
    });
  });

  group('InputValidators.email', () {
    test('accepts valid emails', () {
      for (final e in ['a@b.co', 'john.doe@example.com', 'x+tag@mail.example.org', 'A_B-c@sub-domain.io']) {
        expect(InputValidators.email(e), isNull, reason: e);
      }
    });
    test('rejects malformed emails', () {
      for (final e in ['', '@', 'a@', '@b.com', 'a@b', 'a@b.c', 'a@@b.com', 'a b@c.com', '.a@b.com', 'a.@b.com', 'a..b@c.com', 'a@-b.com', 'a@b-.com', 'a@b..com', 'a@b.c0m', 'a#b@c.com']) {
        expect(InputValidators.email(e), isNotNull, reason: e);
      }
    });
  });

  group('InputValidators.password', () {
    test('requires 6+ non-blank characters', () {
      expect(InputValidators.password(''), isNotNull);
      expect(InputValidators.password('      '), isNotNull);
      expect(InputValidators.password('abc12'), isNotNull);
      expect(InputValidators.password('abc123'), isNull);
    });
  });
}
