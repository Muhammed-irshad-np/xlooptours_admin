import '../entities/fund_account_entity.dart';
import '../entities/fund_account_type_entity.dart';

/// Generates a unique, standardized sequential account code for a fund account type or prefix.
///
/// Output examples:
/// - Petty Cash: `PC-001`, `PC-002`
/// - Bank: `BNK-001`, `BNK-002`
/// - STC Pay: `STC-001`
/// - Driver Account: `DRV-001`
/// - Custom: `ACC-001`, `TMK-001`
class GenerateAccountCodeUseCase {
  const GenerateAccountCodeUseCase();

  String call(dynamic typeOrPrefix, List<FundAccountEntity> existingAccounts) {
    final String prefix;
    if (typeOrPrefix is FundAccountType) {
      prefix = typeOrPrefix.codePrefix;
    } else if (typeOrPrefix is FundAccountTypeEntity) {
      prefix = typeOrPrefix.codePrefix.trim().toUpperCase();
    } else if (typeOrPrefix is String && typeOrPrefix.trim().isNotEmpty) {
      prefix = typeOrPrefix.trim().toUpperCase();
    } else {
      prefix = 'ACC';
    }

    final effectivePrefix = prefix.isEmpty ? 'ACC' : prefix;
    final prefixPattern = RegExp('^${RegExp.escape(effectivePrefix)}-(\\d+)\$', caseSensitive: false);

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
    String candidateCode = '$effectivePrefix-${nextSequence.toString().padLeft(3, '0')}';

    // Absolute collision prevention across all accounts (case-insensitive)
    final existingCodesUpper = existingAccounts
        .map((a) => a.code.trim().toUpperCase())
        .toSet();

    while (existingCodesUpper.contains(candidateCode.toUpperCase())) {
      nextSequence++;
      candidateCode = '$effectivePrefix-${nextSequence.toString().padLeft(3, '0')}';
    }

    return candidateCode;
  }
}
