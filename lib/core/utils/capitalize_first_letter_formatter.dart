import 'package:flutter/services.dart';

/// Upper-cases the first letter of a name as it is typed or pasted, so
/// "john" is stored as "John". Pair with [TextCapitalization.words] so
/// mobile keyboards start each word with a capital too.
class CapitalizeFirstLetterFormatter extends TextInputFormatter {
  const CapitalizeFirstLetterFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final index = text.indexOf(RegExp(r'\S'));
    if (index == -1) return newValue;

    final first = text[index];
    final upper = first.toUpperCase();
    // Skip letters without a single-character upper case (e.g. "ß") so the
    // text length, and therefore the cursor position, never changes.
    if (first == upper || upper.length != 1) return newValue;

    return newValue.copyWith(
      text: text.replaceRange(index, index + 1, upper),
    );
  }
}
