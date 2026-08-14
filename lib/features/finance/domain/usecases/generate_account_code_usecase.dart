import '../entities/fund_account_entity.dart';

/// Generates a unique, standardized sequential account code for a [FundAccountType].
///
/// Output examples:
/// - Petty Cash: `PC-001`, `PC-002`
/// - Driver Account: `DRV-001`, `DRV-002`
/// - Tamkeen: `TMK-001`
/// - Admin: `ADM-001`
/// - Fuel Card: `FL-001`
/// - STC Pay: `STC-001`
/// - Bank: `BNK-001`
/// - Other: `ACC-001`
class GenerateAccountCodeUseCase {
  const GenerateAccountCodeUseCase();

  String call(FundAccountType type, List<FundAccountEntity> existingAccounts) {
    final prefix = type.codePrefix;
    final prefixPattern = RegExp('^${RegExp.escape(prefix)}-(\\d+)\$', caseSensitive: false);

    int maxSequence = 0;

    for (final account in existingAccounts) {
      final code = account.code.trim();
      final match = prefixPattern.firstMatch(code);
      if (match != null) {
        final parsed = int.tryParse(match.group(1) ?? '');
        if (parsed != null && parsed > maxSequence) {
          maxSequence = parsed;
        }
      }
    }

    int nextSequence = maxSequence + 1;
    String candidateCode = '$prefix-${nextSequence.toString().padLeft(3, '0')}';

    // Absolute collision prevention across all accounts (case-insensitive)
    final existingCodesUpper = existingAccounts
        .map((a) => a.code.trim().toUpperCase())
        .toSet();

    while (existingCodesUpper.contains(candidateCode.toUpperCase())) {
      nextSequence++;
      candidateCode = '$prefix-${nextSequence.toString().padLeft(3, '0')}';
    }

    return candidateCode;
  }
}
