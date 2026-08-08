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
  final double currentBalance;
  final double cashBalance;
  final double stcPayBalance;
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
    this.currentBalance = 0.0,
    this.cashBalance = 0.0,
    this.stcPayBalance = 0.0,
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

  FundAccountEntity copyWith({
    String? id,
    String? name,
    String? code,
    FundAccountType? type,
    double? currentBalance,
    double? cashBalance,
    double? stcPayBalance,
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
      currentBalance: currentBalance ?? this.currentBalance,
      cashBalance: cashBalance ?? this.cashBalance,
      stcPayBalance: stcPayBalance ?? this.stcPayBalance,
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
        currentBalance,
        cashBalance,
        stcPayBalance,
        currency,
        assignedTo,
        assignedToId,
        isActive,
        createdAt,
      ];
}
