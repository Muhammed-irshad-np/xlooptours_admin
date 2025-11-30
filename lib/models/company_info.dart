class CompanyInfo {
  // Company Name
  static const String companyNameEn = 'X L O O P';
  static const String companyNameEn2 = 'TOURS W.L.L';
  static const String companyNameAr = 'اكس لوب';
  static const String companyNameAr2 = 'ت ورس ذ.ل.ل';
  // Registration
  static const String crNumber = 'C.R 160615-1';

  // Tax Registration
  static const String trnNumber = '220019841400002';
  static const String trnNumberAr = '٢٢٠٠١٩٨٤١٤٠٠٠٠٢';

  // Address
  // Full address for the first page header
  static const String addressEnFull =
      'Flat-32, Bldg 106, Road 333 Block 321, Alqudaybiyah, Kingdom of Bahrain';
  // Shorter address for footer if needed, or just use the same.
  // The user said "give this adress... all other headers dont need this".
  // I'll keep a shorter version for the footer to avoid clutter, or use the full one if it fits.
  // Let's use a slightly more compact version for the footer or the same one.
  // Given the length, I'll use the full one for now but maybe split it if needed.
  static const String addressEn =
      'Kingdom of Bahrain - Manama Centre'; // Keeping this for footer as per previous design or update?
  // User said: "give this adress... all other headers dont need this".
  // This implies the footer (which appears on all pages) might not need the FULL detailed address.
  // I will add a specific field for the full header address.

  static const String addressAr = 'مملكة البحرين - مركز المنامة';

  // Contact
  static const String contact = '+966502691607 | +97333528661';
  static const String contactAr = '٩٧٣٣٣٥٢٨٦٦١+ | ٩٦٦٥٠٢٦٩١٦٠٧+';
  static const String email = 'enquiries@xlooptours.com';

  // Bank Details
  static const String accountName = 'XLOOP TOURS W.L.L';
  static const String accountNumber = '0012 328654 001';
  static const String iban = 'BH78AUBB00012328654001';
  static const String bankName = 'AHLI UNITED BANK';
  static const String swiftCode = 'AUBBBHBM';
  static const String currency = 'SAR/BHD';

  // Logo path
  static const String logoPath = 'assets/logo/xloop_logo.png';
}
