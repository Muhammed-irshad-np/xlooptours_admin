import '../../domain/entities/fund_account_type_entity.dart';

/// Data model for [FundAccountTypeEntity] with Firestore serialization.
class FundAccountTypeModel extends FundAccountTypeEntity {
  const FundAccountTypeModel({
    required super.id,
    required super.name,
    required super.codePrefix,
    super.description,
    super.isSystemDefault = false,
    super.isActive = true,
    required super.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'codePrefix': codePrefix.toUpperCase(),
      'description': description,
      'isSystemDefault': isSystemDefault,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory FundAccountTypeModel.fromJson(Map<String, dynamic> json) {
    return FundAccountTypeModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      codePrefix: (json['codePrefix'] as String? ?? 'ACC').toUpperCase(),
      description: json['description'] as String?,
      isSystemDefault: json['isSystemDefault'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  factory FundAccountTypeModel.fromEntity(FundAccountTypeEntity entity) {
    return FundAccountTypeModel(
      id: entity.id,
      name: entity.name,
      codePrefix: entity.codePrefix,
      description: entity.description,
      isSystemDefault: entity.isSystemDefault,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
    );
  }
}
