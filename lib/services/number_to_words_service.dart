class NumberToWordsService {
  static const List<String> _ones = [
    '',
    'One',
    'Two',
    'Three',
    'Four',
    'Five',
    'Six',
    'Seven',
    'Eight',
    'Nine',
  ];
  static const List<String> _teens = [
    'Ten',
    'Eleven',
    'Twelve',
    'Thirteen',
    'Fourteen',
    'Fifteen',
    'Sixteen',
    'Seventeen',
    'Eighteen',
    'Nineteen',
  ];
  static const List<String> _tens = [
    '',
    '',
    'Twenty',
    'Thirty',
    'Forty',
    'Fifty',
    'Sixty',
    'Seventy',
    'Eighty',
    'Ninety',
  ];
  static const List<String> _thousands = ['', 'Thousand', 'Million', 'Billion'];

  static String convertEn(double amount) {
    if (amount == 0) return 'Zero';

    int integerPart = amount.floor();
    int decimalPart = ((amount - integerPart) * 100).round();

    String words = _convertIntegerEn(integerPart);

    if (decimalPart > 0) {
      return '$words & $decimalPart/100';
    } else {
      return words;
    }
  }

  static String _convertIntegerEn(int n) {
    if (n == 0) return '';

    String words = '';
    int i = 0;

    while (n > 0) {
      if (n % 1000 != 0) {
        String part = _convertHundredsEn(n % 1000);
        if (_thousands[i].isNotEmpty) {
          part += ' ${_thousands[i]}';
        }
        if (words.isNotEmpty) {
          words = '$part $words';
        } else {
          words = part;
        }
      }
      n ~/= 1000;
      i++;
    }

    return words.trim();
  }

  static String _convertHundredsEn(int n) {
    String words = '';

    if (n >= 100) {
      words += '${_ones[n ~/ 100]} Hundred';
      n %= 100;
      if (n > 0) words += ' ';
    }

    if (n >= 20) {
      words += _tens[n ~/ 10];
      n %= 10;
      if (n > 0) words += '-${_ones[n]}';
    } else if (n >= 10) {
      words += _teens[n - 10];
    } else if (n > 0) {
      words += _ones[n];
    }

    return words;
  }

  // Arabic Conversion
  static String convertAr(double amount) {
    if (amount == 0) return 'صفر';

    int integerPart = amount.floor();
    int decimalPart = ((amount - integerPart) * 100).round();

    String words = _convertIntegerAr(integerPart);

    if (decimalPart > 0) {
      return '$words و 100/$decimalPart';
    } else {
      return words;
    }
  }

  static String _convertIntegerAr(int n) {
    if (n == 0) return '';

    // Arabic number to words logic is complex.
    // We will implement a simplified version sufficient for invoices.
    // Handling up to Billions.

    if (n < 0) return 'ناقص ${_convertIntegerAr(-n)}';
    if (n == 0) return 'صفر';

    String words = '';

    // Billions
    int billions = n ~/ 1000000000;
    n %= 1000000000;
    if (billions > 0) {
      words += '${_convertGroupAr(billions)} مليار';
      if (n > 0) words += ' و';
    }

    // Millions
    int millions = n ~/ 1000000;
    n %= 1000000;
    if (millions > 0) {
      words += '${_convertGroupAr(millions)} مليون';
      if (n > 0) words += ' و';
    }

    // Thousands
    int thousands = n ~/ 1000;
    n %= 1000;
    if (thousands > 0) {
      // Special handling for 1000, 2000
      if (thousands == 1) {
        words += 'ألف';
      } else if (thousands == 2) {
        words += 'ألفين';
      } else if (thousands >= 3 && thousands <= 10) {
        words += '${_convertGroupAr(thousands)} آلاف';
      } else {
        words += '${_convertGroupAr(thousands)} ألفاً';
      }

      if (n > 0) words += ' و';
    }

    // Hundreds/Tens/Units
    if (n > 0) {
      words += _convertGroupAr(n);
    }

    return words;
  }

  static String _convertGroupAr(int n) {
    if (n == 0) return '';

    String words = '';

    // Hundreds
    int hundreds = n ~/ 100;
    int remainder = n % 100;

    if (hundreds > 0) {
      if (hundreds == 1) {
        words += 'مائة';
      } else if (hundreds == 2) {
        words += 'مائتان';
      } else if (hundreds == 3) {
        words += 'ثلاثمائة';
      } else if (hundreds == 4) {
        words += 'أربعمائة';
      } else if (hundreds == 5) {
        words += 'خمسمائة';
      } else if (hundreds == 6) {
        words += 'ستمائة';
      } else if (hundreds == 7) {
        words += 'سبعمائة';
      } else if (hundreds == 8) {
        words += 'ثمانمائة';
      } else if (hundreds == 9) {
        words += 'تسعمائة';
      }

      if (remainder > 0) words += ' و';
    }

    if (remainder > 0) {
      if (remainder < 10) {
        words += _onesAr[remainder];
      } else if (remainder < 20) {
        words += _teensAr[remainder - 10];
      } else {
        int unit = remainder % 10;
        int ten = remainder ~/ 10;

        if (unit > 0) {
          words += '${_onesAr[unit]} و${_tensAr[ten]}';
        } else {
          words += _tensAr[ten];
        }
      }
    }

    return words;
  }

  static const List<String> _onesAr = [
    '',
    'واحد',
    'اثنان',
    'ثلاثة',
    'أربعة',
    'خمسة',
    'ستة',
    'سبعة',
    'ثمانية',
    'تسعة',
  ];

  static const List<String> _teensAr = [
    'عشرة',
    'أحد عشر',
    'اثنا عشر',
    'ثلاثة عشر',
    'أربعة عشر',
    'خمسة عشر',
    'ستة عشر',
    'سبعة عشر',
    'ثمانية عشر',
    'تسعة عشر',
  ];

  static const List<String> _tensAr = [
    '',
    'عشرة',
    'عشرون',
    'ثلاثون',
    'أربعون',
    'خمسون',
    'ستون',
    'سبعون',
    'ثمانون',
    'تسعون',
  ];
}
