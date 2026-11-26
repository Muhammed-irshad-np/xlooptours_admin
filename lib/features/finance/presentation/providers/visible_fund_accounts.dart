import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:xloop_invoice/features/auth/presentation/providers/auth_provider.dart';
import 'package:xloop_invoice/features/employee/presentation/providers/employee_provider.dart';
import 'package:xloop_invoice/features/finance/domain/entities/fund_account_entity.dart';

import 'fund_account_provider.dart';

/// The fund accounts the signed-in user may see and use.
///
/// Admin / Super Admin get every active account; everyone else only the
/// accounts assigned to them, by name or through their role. Use this for
/// every list or picker of accounts, so a user never sees, filters by or
/// picks an account they are not assigned to.
extension VisibleFundAccounts on BuildContext {
  /// Active accounts the signed-in user may see. Pass [listen] from a build
  /// method that must rebuild when the accounts change.
  List<FundAccountEntity> visibleFundAccounts({
    bool listen = false,
    bool includeInactive = false,
  }) {
    final accounts = listen
        ? watch<FundAccountProvider>()
        : read<FundAccountProvider>();
    return accounts.visibleAccountsFor(
      read<AuthProvider>().user,
      employees: read<EmployeeProvider>().employees,
      includeInactive: includeInactive,
    );
  }

  /// Whether the signed-in user sees every account (Admin / Super Admin).
  bool get seesAllFundAccounts => read<AuthProvider>().user?.isAdmin ?? false;
}
