import 'package:equatable/equatable.dart';
import 'app_role.dart';

class UserEntity extends Equatable {
  final String id;
  final String? email;
  final String? displayName;

  /// Legacy flag; kept for existing UI. Prefer [role].
  final bool isAdmin;

  /// RBAC role loaded from `allowed_users`.
  final AppRole role;

  /// Whether the whitelist entry is active (default true).
  final bool isActive;

  const UserEntity({
    required this.id,
    this.email,
    this.displayName,
    this.isAdmin = false,
    this.role = AppRole.viewer,
    this.isActive = true,
  });

  /// Best display label for audit trails.
  String get actorLabel {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final mail = email?.trim();
    if (mail != null && mail.isNotEmpty) return mail;
    return id;
  }

  bool get canSubmitExpense => role.canSubmitExpense;
  bool get canApproveExpense => role.canApproveExpense;
  bool get canPostMoney => role.canPostMoney;
  bool get canReverseMoney => role.canReverseMoney;
  bool get canManageFundAccounts => role.canManageFundAccounts;
  bool get canManagePettyCash => role.canManagePettyCash;
  bool get canVerifyPettyCash => role.canVerifyPettyCash;
  bool get canManageCategories => role.canManageCategories;
  bool get canViewAllFinance => role.canViewAllFinance;

  @override
  List<Object?> get props => [id, email, displayName, isAdmin, role, isActive];
}
