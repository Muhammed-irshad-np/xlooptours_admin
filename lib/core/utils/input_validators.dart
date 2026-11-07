/// Shared field validators for forms. Each returns an error message, or
/// `null` when the value is valid, so they plug straight into
/// `TextFormField.validator`.
class InputValidators {
  InputValidators._();

  // Letters (any language), joined by single spaces, apostrophes, hyphens or
  // periods: "Mary-Jane O'Neil", "J. Smith". No digits or other symbols.
  static final RegExp _personName = RegExp(
    r"^\p{L}+(?:(?:[ '\-]|\. ?)\p{L}+)*\.?$",
    unicode: true,
  );

  // local@domain.tld — local part of letters, digits and ._%+- (no leading,
  // trailing or doubled dots); domain labels that don't start or end with a
  // hyphen; a top-level domain of at least two letters.
  static final RegExp _email = RegExp(
    r'^[A-Za-z0-9%+_-]+(?:\.[A-Za-z0-9%+_-]+)*'
    r'@(?:[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?\.)+[A-Za-z]{2,}$',
  );

  static const int minPasswordLength = 6;

  static String? personName(String? value, {String label = 'Name'}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '$label is required';
    if (v.length < 2) return '$label must be at least 2 characters';
    if (v.length > 60) return '$label must be at most 60 characters';
    if (!_personName.hasMatch(v)) {
      return '$label can only contain letters, spaces, hyphens, apostrophes and periods';
    }
    return null;
  }

  static bool isValidEmail(String? value) {
    final v = value?.trim() ?? '';
    return v.length <= 254 && _email.hasMatch(v);
  }

  static String? email(String? value, {String label = 'Email'}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '$label is required';
    if (!isValidEmail(v)) return 'Enter a valid email address (e.g. name@example.com)';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.trim().isEmpty) return 'Password cannot be only spaces';
    if (v.length < minPasswordLength) {
      return 'Password must be at least $minPasswordLength characters';
    }
    return null;
  }
}
