import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/core/utils/capitalize_first_letter_formatter.dart';

void main() {
  const formatter = CapitalizeFirstLetterFormatter();

  String format(String text) => formatter
      .formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        ),
      )
      .text;

  test('capitalizes the first letter', () {
    expect(format('john'), 'John');
    expect(format('john doe'), 'John doe');
  });

  test('skips leading whitespace', () {
    expect(format('  ali'), '  Ali');
  });

  test('leaves already-capitalized, empty and caseless text alone', () {
    expect(format('John'), 'John');
    expect(format(''), '');
    expect(format('   '), '   ');
    expect(format('محمد'), 'محمد');
    expect(format('1st Choice'), '1st Choice');
  });

  test('keeps the cursor position', () {
    final result = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(
        text: 'jo',
        selection: TextSelection.collapsed(offset: 2),
      ),
    );
    expect(result.selection, const TextSelection.collapsed(offset: 2));
  });
}
