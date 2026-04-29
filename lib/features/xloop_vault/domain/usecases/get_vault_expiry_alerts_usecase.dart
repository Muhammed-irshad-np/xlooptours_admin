import '../entities/vault_expiry_alert.dart';
import '../repositories/vault_repository.dart';

class GetVaultExpiryAlertsUseCase {
  final VaultRepository repository;

  GetVaultExpiryAlertsUseCase(this.repository);

  Future<List<VaultExpiryAlert>> call() async {
    final vaultData = await repository.getVaultData();
    final List<VaultExpiryAlert> alerts = [];
    final now = DateTime.now();

    // Commercial License
    if (vaultData.license.expiryDate != null) {
      final days = vaultData.license.expiryDate!.difference(now).inDays;
      final alertDays = vaultData.license.alertDays;
      if (days <= alertDays) {
        alerts.add(
          VaultExpiryAlert(
            documentType: 'Commercial License',
            expiryDate: vaultData.license.expiryDate!,
            daysUntilExpiry: days,
          ),
        );
      }
    }

    // Sort alerts by urgency
    alerts.sort((a, b) => a.daysUntilExpiry.compareTo(b.daysUntilExpiry));

    return alerts;
  }
}
