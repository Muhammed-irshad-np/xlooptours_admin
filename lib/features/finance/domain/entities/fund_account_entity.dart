import 'package:equatable/equatable.dart';

/// The type of virtual fund account.
enum FundAccountType {
  pettyCash,
  driverAccount,
  tamkeen,
  admin,
  fuelCard,
  stcPay,
  bank,
  other;

  String get displayName {
    switch (this) {
      case FundAccountType.pettyCash:
        return 'Petty Cash';
      case FundAccountType.driverAccount:
        return 'Driver Account';
      case FundAccountType.tamkeen:
        return 'Tamkeen';
      case FundAccountType.admin:
        return 'Admin';
      case FundAccountType.fuelCard:
        return 'Fuel Card';
      case FundAccountType.stcPay:
        return 'STC Pay';
      case FundAccountType.bank:
        return 'Bank';
      case FundAccountType.other:
        return 'Other';
    }
  }

  String get codePrefix {
    switch (this) {
      case FundAccountType.pettyCash:
        return 'PC';
      case FundAccountType.driverAccount:
        return 'DRV';
      case FundAccountType.tamkeen:
        return 'TMK';
      case FundAccountType.admin:
        return 'ADM';
      case FundAccountType.fuelCard:
        return 'FL';
      case FundAccountType.stcPay:
        return 'STC';
      case FundAccountType.bank:
        return 'BNK';
      case FundAccountType.other:
        return 'ACC';
    }
  }
}

/// Represents a virtual fund account used for tracking money flow.
///
/// These are NOT real bank accounts — they are internal bookkeeping
/// buckets (e.g., Petty Cash #001, Driver Account #002).
class FundAccountEntity extends Equatable {
  final String id;
  final String name;

  /// Short code for display (e.g., "PETTY ACC#001", "DRV-001").
  final String code;
  final FundAccountType type;

  /// Dynamic account type ID (e.g., 'bank', 'pettyCash', 'stcPay', or custom type ID).
  final String? accountTypeId;

  /// Display name of the account type (e.g., 'Bank', 'Petty Cash', 'STC Pay', 'Driver Account').
  final String? accountTypeName;

  /// Display name for the account type. Prefers dynamic [accountTypeName], then enum [type.displayName].
  String get typeDisplayName {
    if (accountTypeName != null && accountTypeName!.trim().isNotEmpty) {
      return accountTypeName!.trim();
    }
    return type.displayName;
  }

  /// Convenience checks for standard system types
  bool get isPettyCash =>
      type == FundAccountType.pettyCash ||
      accountTypeId == 'pettyCash' ||
      accountTypeId == 'petty_cash' ||
      (accountTypeName?.toLowerCase() == 'petty cash');

  bool get isBank =>
      type == FundAccountType.bank ||
      accountTypeId == 'bank' ||
      (accountTypeName?.toLowerCase() == 'bank');

  bool get isStcPay =>
      type == FundAccountType.stcPay ||
      accountTypeId == 'stcPay' ||
      accountTypeId == 'stc_pay' ||
      (accountTypeName?.toLowerCase() == 'stc pay');

  /// Authoritative balance in minor units (halalas). Use these for all arithmetic.
  final int currentBalanceMinor;
  final int cashBalanceMinor;
  final int stcPayBalanceMinor;

  /// Convenience major-unit accessors for UI display. Derived from minor units.
  double get currentBalance => currentBalanceMinor / 100.0;
  double get cashBalance => cashBalanceMinor / 100.0;
  double get stcPayBalance => stcPayBalanceMinor / 100.0;

  final String currency;

  /// Legacy single coordinator: an employee name, and on very old accounts a
  /// login id. Kept for accounts saved before [assignedEmployeeIds] existed;
  /// new saves write the first assigned person here.
  final String? assignedTo;
  final String? assignedToId;

  /// Employees assigned to this account (parallel to
  /// [assignedEmployeeNames]). Everyone assigned, by name or through one of
  /// [assignedRoles], can see the account and record expenses on it.
  final List<String> assignedEmployeeIds;
  final List<String> assignedEmployeeNames;

  /// Login roles (normalized role ids, e.g. `coordinator`) whose users are
  /// assigned to this account.
  final List<String> assignedRoles;

  /// Names of everyone assigned by name, the legacy [assignedTo] included.
  List<String> get assigneeNames {
    if (assignedEmployeeNames.isNotEmpty) return assignedEmployeeNames;
    final legacy = assignedTo?.trim() ?? '';
    return legacy.isEmpty ? const [] : [legacy];
  }

  /// Whether anyone is assigned, by name or by role.
  bool get hasAssignees =>
      assigneeNames.isNotEmpty ||
      assignedRoles.isNotEmpty ||
      (assignedToId ?? '').isNotEmpty;

  /// Short label of who is assigned, e.g. "Nithin, Saleh · Coordinator".
  /// Empty when nobody is.
  String get assigneeLabel {
    final roles = assignedRoles.map(roleLabel);
    return [
      if (assigneeNames.isNotEmpty) assigneeNames.join(', '),
      if (assignedRoles.isNotEmpty) roles.join(', '),
    ].join(' · ');
  }

  /// "office_staff" → "Office Staff".
  static String roleLabel(String roleId) => roleId
      .split('_')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
  final bool isActive;
  final DateTime createdAt;

  /// Position in the accounts grid, set by dragging cards. Null for accounts
  /// never reordered; those come after the ordered ones, by name.
  final int? sortOrder;

  /// Whether expenses paid from this account need a receipt once they reach
  /// the policy threshold. Set off in the account form for accounts whose
  /// spends never come with a bill (e.g. a government-portal wallet).
  final bool receiptRequired;

  const FundAccountEntity({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    this.accountTypeId,
    this.accountTypeName,
    this.currentBalanceMinor = 0,
    this.cashBalanceMinor = 0,
    this.stcPayBalanceMinor = 0,
    required this.currency,
    this.assignedTo,
    this.assignedToId,
    this.assignedEmployeeIds = const [],
    this.assignedEmployeeNames = const [],
    this.assignedRoles = const [],
    this.isActive = true,
    required this.createdAt,
    this.sortOrder,
    this.receiptRequired = true,
  });

  factory FundAccountEntity.empty() {
    return FundAccountEntity(
      id: '',
      name: '',
      code: '',
      type: FundAccountType.pettyCash,
      accountTypeId: 'pettyCash',
      accountTypeName: 'Petty Cash',
      currency: 'SAR',
      createdAt: DateTime.now(),
    );
  }

  /// Create from legacy double major-unit values (migration helper).
  factory FundAccountEntity.fromMajor({
    required String id,
    required String name,
    required String code,
    required FundAccountType type,
    String? accountTypeId,
    String? accountTypeName,
    double currentBalance = 0.0,
    double cashBalance = 0.0,
    double stcPayBalance = 0.0,
    required String currency,
    String? assignedTo,
    String? assignedToId,
    bool isActive = true,
    required DateTime createdAt,
  }) {
    return FundAccountEntity(
      id: id,
      name: name,
      code: code,
      type: type,
      accountTypeId: accountTypeId,
      accountTypeName: accountTypeName,
      currentBalanceMinor: (currentBalance * 100).round(),
      cashBalanceMinor: (cashBalance * 100).round(),
      stcPayBalanceMinor: (stcPayBalance * 100).round(),
      currency: currency,
      assignedTo: assignedTo,
      assignedToId: assignedToId,
      isActive: isActive,
      createdAt: createdAt,
    );
  }

  FundAccountEntity copyWith({
    String? id,
    String? name,
    String? code,
    FundAccountType? type,
    String? accountTypeId,
    String? accountTypeName,
    int? currentBalanceMinor,
    int? cashBalanceMinor,
    int? stcPayBalanceMinor,
    String? currency,
    String? assignedTo,
    String? assignedToId,
    List<String>? assignedEmployeeIds,
    List<String>? assignedEmployeeNames,
    List<String>? assignedRoles,
    bool? isActive,
    DateTime? createdAt,
    int? sortOrder,
    bool? receiptRequired,
    bool clearAssignedTo = false,
    bool clearAssignedToId = false,
  }) {
    return FundAccountEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      type: type ?? this.type,
      accountTypeId: accountTypeId ?? this.accountTypeId,
      accountTypeName: accountTypeName ?? this.accountTypeName,
      currentBalanceMinor: currentBalanceMinor ?? this.currentBalanceMinor,
      cashBalanceMinor: cashBalanceMinor ?? this.cashBalanceMinor,
      stcPayBalanceMinor: stcPayBalanceMinor ?? this.stcPayBalanceMinor,
      currency: currency ?? this.currency,
      assignedTo:
          clearAssignedTo ? null : (assignedTo ?? this.assignedTo),
      assignedToId:
          clearAssignedToId ? null : (assignedToId ?? this.assignedToId),
      assignedEmployeeIds: assignedEmployeeIds ?? this.assignedEmployeeIds,
      assignedEmployeeNames:
          assignedEmployeeNames ?? this.assignedEmployeeNames,
      assignedRoles: assignedRoles ?? this.assignedRoles,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      sortOrder: sortOrder ?? this.sortOrder,
      receiptRequired: receiptRequired ?? this.receiptRequired,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        code,
        type,
        accountTypeId,
        accountTypeName,
        currentBalanceMinor,
        cashBalanceMinor,
        stcPayBalanceMinor,
        currency,
        assignedTo,
        assignedToId,
        assignedEmployeeIds,
        assignedEmployeeNames,
        assignedRoles,
        isActive,
        createdAt,
        sortOrder,
        receiptRequired,
      ];
}
