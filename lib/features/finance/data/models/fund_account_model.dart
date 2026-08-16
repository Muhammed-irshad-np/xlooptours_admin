import '../../domain/entities/fund_account_entity.dart';

/// Data model for [FundAccountEntity] with Firestore serialization.
///
/// Storage strategy:
///   - Writes: always store `currentBalanceMinor` (int) as the authoritative field
///     PLUS `currentBalance` (double) for backward compat with old app versions.
///   - Reads: prefer `currentBalanceMinor` when present; fall back to
///     `(currentBalance * 100).round()` for documents written before migration.
class FundAccountModel extends FundAccountEntity {
  const FundAccountModel({
    required super.id,
    required super.name,
    required super.code,
    required super.type,
    super.currentBalanceMinor = 0,
    super.cashBalanceMinor = 0,
    super.stcPayBalanceMinor = 0,
    required super.currency,
    super.assignedTo,
    super.assignedToId,
    super.isActive = true,
    required super.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'type': type.name,
      // Authoritative integer fields
      'currentBalanceMinor': currentBalanceMinor,
      'cashBalanceMinor': cashBalanceMinor,
      'stcPayBalanceMinor': stcPayBalanceMinor,
      // Legacy double fields kept so older app versions can still read balance
      'currentBalance': currentBalance,
      'cashBalance': cashBalance,
      'stcPayBalance': stcPayBalance,
      'currency': currency,
      'assignedTo': assignedTo,
      'assignedToId': assignedToId,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory FundAccountModel.fromJson(Map<String, dynamic> json) {
    // Robust parser: Handles documents where currentBalanceMinor might be 0
    // while the legacy currentBalance has a non-zero value, or vice-versa.
    int parseMinor(String minorKey, String majorKey) {
      final minorVal = json[minorKey] as int?;
      final majorVal = (json[majorKey] as num?)?.toDouble();

      if (minorVal == null) {
        return majorVal != null ? (majorVal * 100).round() : 0;
      }

      // If minor is 0 but major has funds, use major to recover the real balance
      if (minorVal == 0 && majorVal != null && majorVal != 0) {
        return (majorVal * 100).round();
      }

      return minorVal;
    }

    final currentMinor = parseMinor('currentBalanceMinor', 'currentBalance');
    final cashMinor = parseMinor('cashBalanceMinor', 'cashBalance');
    final stcMinor = parseMinor('stcPayBalanceMinor', 'stcPayBalance');

    return FundAccountModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      type: _parseType(json['type'] as String?),
      currentBalanceMinor: currentMinor,
      cashBalanceMinor: cashMinor,
      stcPayBalanceMinor: stcMinor,
      currency: json['currency'] as String? ?? 'SAR',
      assignedTo: json['assignedTo'] as String?,
      assignedToId: json['assignedToId'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  factory FundAccountModel.fromEntity(FundAccountEntity entity) {
    return FundAccountModel(
      id: entity.id,
      name: entity.name,
      code: entity.code,
      type: entity.type,
      currentBalanceMinor: entity.currentBalanceMinor,
      cashBalanceMinor: entity.cashBalanceMinor,
      stcPayBalanceMinor: entity.stcPayBalanceMinor,
      currency: entity.currency,
      assignedTo: entity.assignedTo,
      assignedToId: entity.assignedToId,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
    );
  }

  static FundAccountType _parseType(String? type) {
    if (type == null) return FundAccountType.pettyCash;
    return FundAccountType.values.firstWhere(
      (e) => e.name == type,
      orElse: () => FundAccountType.other,
    );
  }
}

