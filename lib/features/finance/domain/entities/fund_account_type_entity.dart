import 'package:equatable/equatable.dart';

/// Represents a configurable virtual fund account type (e.g., Bank, Petty Cash, STC Pay, Driver Account).
class FundAccountTypeEntity extends Equatable {
  final String id;
  final String name;
  final String codePrefix;
  final String? description;

  /// System default types (Bank, Petty Cash, STC Pay) cannot be deleted.
  final bool isSystemDefault;
  final bool isActive;
  final DateTime createdAt;

  const FundAccountTypeEntity({
    required this.id,
    required this.name,
    required this.codePrefix,
    this.description,
    this.isSystemDefault = false,
    this.isActive = true,
    required this.createdAt,
  });

  /// The standard system default account types: Bank, Petty Cash, and STC Pay.
  static List<FundAccountTypeEntity> get defaultTypes => [
        FundAccountTypeEntity(
          id: 'bank',
          name: 'Bank',
          codePrefix: 'BNK',
          description: 'Standard corporate or operating bank account',
          isSystemDefault: true,
          isActive: true,
          createdAt: DateTime(2026, 1, 1),
        ),
        FundAccountTypeEntity(
          id: 'pettyCash',
          name: 'Petty Cash',
          codePrefix: 'PC',
          description: 'Physical cash drawer or petty cash fund',
          isSystemDefault: true,
          isActive: true,
          createdAt: DateTime(2026, 1, 1),
        ),
        FundAccountTypeEntity(
          id: 'stcPay',
          name: 'STC Pay',
          codePrefix: 'STC',
          description: 'Digital STC Pay wallet or account',
          isSystemDefault: true,
          isActive: true,
          createdAt: DateTime(2026, 1, 1),
        ),
      ];

  FundAccountTypeEntity copyWith({
    String? id,
    String? name,
    String? codePrefix,
    String? description,
    bool? isSystemDefault,
    bool? isActive,
    DateTime? createdAt,
    bool clearDescription = false,
  }) {
    return FundAccountTypeEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      codePrefix: codePrefix ?? this.codePrefix,
      description:
          clearDescription ? null : (description ?? this.description),
      isSystemDefault: isSystemDefault ?? this.isSystemDefault,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        codePrefix,
        description,
        isSystemDefault,
        isActive,
        createdAt,
      ];
}
