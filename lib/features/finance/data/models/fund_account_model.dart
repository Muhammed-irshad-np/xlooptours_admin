import '../../domain/entities/fund_account_entity.dart';

/// Data model for [FundAccountEntity] with Firestore serialization.
class FundAccountModel extends FundAccountEntity {
  const FundAccountModel({
    required super.id,
    required super.name,
    required super.code,
    required super.type,
    super.currentBalance = 0.0,
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
      'currentBalance': currentBalance,
      'currency': currency,
      'assignedTo': assignedTo,
      'assignedToId': assignedToId,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory FundAccountModel.fromJson(Map<String, dynamic> json) {
    return FundAccountModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      type: _parseType(json['type'] as String?),
      currentBalance: (json['currentBalance'] as num?)?.toDouble() ?? 0.0,
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
      currentBalance: entity.currentBalance,
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
