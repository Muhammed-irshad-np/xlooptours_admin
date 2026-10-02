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
    super.accountTypeId,
    super.accountTypeName,
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
      'accountTypeId': accountTypeId ?? type.name,
      'accountTypeName': accountTypeName ?? typeDisplayName,
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

    var currentMinor = parseMinor('currentBalanceMinor', 'currentBalance');
    var cashMinor = parseMinor('cashBalanceMinor', 'cashBalance');
    var stcMinor = parseMinor('stcPayBalanceMinor', 'stcPayBalance');

    // Self-healing: Ensure cash and STC balances stay bounded by currentBalance
    if (stcMinor == 0 && cashMinor > currentMinor) {
      cashMinor = currentMinor;
    } else if (cashMinor + stcMinor > currentMinor && currentMinor >= 0) {
      if (cashMinor >= currentMinor) {
        cashMinor = currentMinor;
        stcMinor = 0;
      } else {
        stcMinor = currentMinor - cashMinor;
      }
    }

    final parsedType = _parseType(json['type'] as String?);
    final rawTypeId = json['accountTypeId'] as String? ?? json['type'] as String?;
    final rawTypeName = json['accountTypeName'] as String?;

    return FundAccountModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      type: parsedType,
      accountTypeId: rawTypeId,
      accountTypeName: rawTypeName ?? parsedType.displayName,
      currentBalanceMinor: currentMinor,
      cashBalanceMinor: cashMinor,
      stcPayBalanceMinor: stcMinor,
      currency: json['currency'] as String? ?? 'SAR',
      assignedTo: json['assignedTo'] as String?,
      assignedToId: json['assignedToId'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
    );
  }

  static DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val;
    if (val is String) return DateTime.tryParse(val);
    try {
      final dynamic d = val;
      if (d.toDate != null) {
        return (d.toDate() as DateTime);
      }
    } catch (_) {}
    return null;
  }

  factory FundAccountModel.fromEntity(FundAccountEntity entity) {
    return FundAccountModel(
      id: entity.id,
      name: entity.name,
      code: entity.code,
      type: entity.type,
      accountTypeId: entity.accountTypeId,
      accountTypeName: entity.accountTypeName,
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

