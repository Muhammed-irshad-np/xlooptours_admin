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

  /// Short code for display (e.g., "PETTY ACC#001").
  final String code;
  final FundAccountType type;

  /// Authoritative balance in minor units (halalas). Use these for all arithmetic.
  final int currentBalanceMinor;
  final int cashBalanceMinor;
  final int stcPayBalanceMinor;

  /// Convenience major-unit accessors for UI display. Derived from minor units.
  double get currentBalance => currentBalanceMinor / 100.0;
  double get cashBalance => cashBalanceMinor / 100.0;
  double get stcPayBalance => stcPayBalanceMinor / 100.0;

  final String currency;

  /// The coordinator or employee assigned to manage this account.
  final String? assignedTo;
  final String? assignedToId;
  final bool isActive;
  final DateTime createdAt;

  const FundAccountEntity({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    this.currentBalanceMinor = 0,
    this.cashBalanceMinor = 0,
    this.stcPayBalanceMinor = 0,
    required this.currency,
    this.assignedTo,
    this.assignedToId,
    this.isActive = true,
    required this.createdAt,
  });

  factory FundAccountEntity.empty() {
    return FundAccountEntity(
      id: '',
      name: '',
      code: '',
      type: FundAccountType.pettyCash,
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
    int? currentBalanceMinor,
    int? cashBalanceMinor,
    int? stcPayBalanceMinor,
    String? currency,
    String? assignedTo,
    String? assignedToId,
    bool? isActive,
    DateTime? createdAt,
    bool clearAssignedTo = false,
    bool clearAssignedToId = false,
  }) {
    return FundAccountEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      type: type ?? this.type,
      currentBalanceMinor: currentBalanceMinor ?? this.currentBalanceMinor,
      cashBalanceMinor: cashBalanceMinor ?? this.cashBalanceMinor,
      stcPayBalanceMinor: stcPayBalanceMinor ?? this.stcPayBalanceMinor,
      currency: currency ?? this.currency,
      assignedTo:
          clearAssignedTo ? null : (assignedTo ?? this.assignedTo),
      assignedToId:
          clearAssignedToId ? null : (assignedToId ?? this.assignedToId),
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        code,
        type,
        currentBalanceMinor,
        cashBalanceMinor,
        stcPayBalanceMinor,
        currency,
        assignedTo,
        assignedToId,
        isActive,
        createdAt,
      ];
}
