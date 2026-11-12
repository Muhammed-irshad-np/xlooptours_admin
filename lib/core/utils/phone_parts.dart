/// Splits a stored phone ("+966 501234567") into the dial code shown in the
/// form's prefix and the number shown in the field.
///
/// Older records were saved as "966501234567" or "+966501234567" (no space),
/// and editing one of those used to save "+966 966501234567". For Saudi
/// numbers the 966 is moved into the prefix, which also repairs records that
/// already have the code doubled.
({String code, String number}) splitStoredPhone(
  String raw, {
  String defaultCode = '+966',
}) {
  final trimmed = raw.trim();
  var code = defaultCode;
  var number = trimmed;

  final space = trimmed.indexOf(' ');
  if (space > 0) {
    code = trimmed.substring(0, space);
    number = trimmed.substring(space + 1).trim();
    if (!code.startsWith('+')) code = '+$code';
  }

  if (code == '+966') {
    final digits = number
        .replaceAll(RegExp(r'\s'), '')
        .replaceFirst(RegExp(r'^\+'), '');
    if (RegExp(r'^966\d{9}$').hasMatch(digits)) {
      number = digits.substring(3);
    }
  }

  return (code: code, number: number);
}
