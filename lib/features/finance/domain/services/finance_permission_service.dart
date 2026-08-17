import 'package:xloop_invoice/core/rbac/rbac_manager.dart';
import 'package:xloop_invoice/features/auth/domain/entities/user_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/finance_policy_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/fund_account_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/workflow_permission_config.dart';

/// Centralized permission gate for all finance module actions.
///
/// **No hardcoded roles.** Every check delegates to [FinancePolicyEntity]
/// which stores configurable [WorkflowPermissionConfig] per action.
///
/// Admin / Super Admin always bypass all checks.
class FinancePermissionService {
  FinancePermissionService._();

  // ─── Core Check ──────────────────────────────────────────────

  /// Generic check: is [user] authorized by [config]?
  static bool _check(UserEntity? user, WorkflowPermissionConfig config) {
    if (user == null) return false;
    // Admin / Super Admin always pass
    if (user.isAdmin) return true;
    final roleId = RbacManager.normalizeRoleId(user.roleId);
    return config.isAuthorized(roleId, user.id);
  }

  // ─── Petty Cash Session ──────────────────────────────────────

  /// Can [user] open a petty cash session on [account]?
  ///
  /// Checks policy.sessionOpen AND whether the user is the assigned
  /// coordinator for this specific account.
  static bool canOpenSession({
    required UserEntity? user,
    required FundAccountEntity account,
    required FinancePolicyEntity policy,
  }) {
    if (user == null) return false;
    if (user.isAdmin) return true;

    // If user is the assigned coordinator for this account → always allow
    if (_isAssignedToAccount(user, account)) return true;

    return _check(user, policy.sessionOpen);
  }

  /// Can [user] close (declare cash count) this session?
  ///
  /// The assigned coordinator of the account can always close.
  static bool canCloseSession({
    required UserEntity? user,
    required FundAccountEntity account,
    required FinancePolicyEntity policy,
  }) {
    if (user == null) return false;
    if (user.isAdmin) return true;

    // Assigned coordinator can always close their own account session
    if (_isAssignedToAccount(user, account)) return true;

    return _check(user, policy.sessionClose);
  }

  /// Can [user] verify and lock a closed session?
  static bool canVerifySession({
    required UserEntity? user,
    required FinancePolicyEntity policy,
  }) {
    return _check(user, policy.sessionVerify);
  }

  // ─── Expenses ────────────────────────────────────────────────

  /// Can [user] submit / create a new expense?
  static bool canSubmitExpense({
    required UserEntity? user,
    required FinancePolicyEntity policy,
  }) {
    return _check(user, policy.expenseSubmit);
  }

  /// Can [user] approve an expense of [amount] SAR?
  ///
  /// When multi-level approval is enabled, checks if user is authorized
  /// for the applicable stage. Otherwise uses legacy approval limits.
  static bool canApproveExpense({
    required UserEntity? user,
    required FinancePolicyEntity policy,
    required double amount,
  }) {
    if (user == null) return false;
    if (user.isAdmin) return true;

    // Step 1: Must be in the expenseApproval permission config
    if (!_check(user, policy.expenseApproval)) return false;

    final roleId = RbacManager.normalizeRoleId(user.roleId);

    // Step 2: Check amount limit
    if (policy.multiLevelApprovalEnabled && policy.approvalChain.isNotEmpty) {
      // Multi-level: find the stage this user belongs to
      final sorted = [...policy.approvalChain]
        ..sort((a, b) => a.order.compareTo(b.order));
      for (final stage in sorted) {
        if (stage.isUserAuthorized(roleId, user.id)) {
          return stage.canApproveAmount(amount);
        }
      }
      return false; // User not in any stage
    }

    // Legacy single-step: check role limit
    return policy.canApproveAmount(roleId, amount);
  }

  /// Can [user] void an already-approved expense?
  static bool canVoidExpense({
    required UserEntity? user,
    required FinancePolicyEntity policy,
  }) {
    return _check(user, policy.expenseVoid);
  }

  // ─── Fund Operations ─────────────────────────────────────────

  /// Can [user] deposit/withdraw from [account]?
  static bool canMoveFunds({
    required UserEntity? user,
    required FundAccountEntity? account,
    required FinancePolicyEntity policy,
  }) {
    if (user == null) return false;
    if (user.isAdmin) return true;

    // Assigned coordinator can move funds on their own account
    if (account != null && _isAssignedToAccount(user, account)) return true;

    return _check(user, policy.fundMovement);
  }

  /// Can [user] transfer between accounts?
  static bool canTransferFunds({
    required UserEntity? user,
    required FinancePolicyEntity policy,
  }) {
    return _check(user, policy.fundTransfer);
  }

  // ─── Account & Master Data Management ────────────────────────

  /// Can [user] create/edit/delete fund accounts?
  static bool canManageAccounts({
    required UserEntity? user,
    required FinancePolicyEntity policy,
  }) {
    return _check(user, policy.accountManagement);
  }

  /// Can [user] manage master data (categories, types, policies)?
  static bool canManageMasterData({
    required UserEntity? user,
    required FinancePolicyEntity policy,
  }) {
    return _check(user, policy.masterDataManagement);
  }

  /// Can [user] issue/settle cash advances?
  static bool canManageCashAdvances({
    required UserEntity? user,
    required FinancePolicyEntity policy,
  }) {
    return _check(user, policy.cashAdvanceManagement);
  }

  // ─── View Access ─────────────────────────────────────────────

  /// Can [user] view the finance module at all?
  /// Anyone with any finance-related permission can view.
  static bool canViewFinance({
    required UserEntity? user,
    required FinancePolicyEntity policy,
  }) {
    if (user == null) return false;
    if (user.isAdmin) return true;

    // If user has ANY workflow permission → can view
    final roleId = RbacManager.normalizeRoleId(user.roleId);
    final configs = [
      policy.sessionOpen,
      policy.sessionClose,
      policy.sessionVerify,
      policy.expenseApproval,
      policy.expenseVoid,
      policy.expenseSubmit,
      policy.fundMovement,
      policy.fundTransfer,
      policy.accountManagement,
      policy.masterDataManagement,
      policy.cashAdvanceManagement,
    ];
    return configs.any((c) => c.isAuthorized(roleId, user.id));
  }

  // ─── Helpers ─────────────────────────────────────────────────

  /// Check if [user] is the assigned coordinator for [account].
  static bool _isAssignedToAccount(
    UserEntity user,
    FundAccountEntity account,
  ) {
    if (account.assignedToId != null &&
        account.assignedToId!.isNotEmpty &&
        account.assignedToId == user.id) {
      return true;
    }
    // Fallback: match by display name (legacy accounts without assignedToId)
    if (account.assignedTo != null &&
        account.assignedTo!.isNotEmpty &&
        account.assignedTo == user.actorLabel) {
      return true;
    }
    return false;
  }
}
