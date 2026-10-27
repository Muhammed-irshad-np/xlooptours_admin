import '../../domain/entities/expense_category_entity.dart';

/// Data model for [ExpenseTypeEntity] with JSON serialization.
class ExpenseTypeModel extends ExpenseTypeEntity {
  const ExpenseTypeModel({
    required super.id,
    required super.name,
    super.defaultAmount,
    super.priority = 'MANDATORY',
    super.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'defaultAmount': defaultAmount,
      'priority': priority,
      'isActive': isActive,
    };
  }

  factory ExpenseTypeModel.fromJson(Map<String, dynamic> json) {
    return ExpenseTypeModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      defaultAmount: (json['defaultAmount'] as num?)?.toDouble(),
      priority: json['priority'] as String? ?? 'MANDATORY',
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  factory ExpenseTypeModel.fromEntity(ExpenseTypeEntity entity) {
    return ExpenseTypeModel(
      id: entity.id,
      name: entity.name,
      defaultAmount: entity.defaultAmount,
      priority: entity.priority,
      isActive: entity.isActive,
    );
  }
}

/// Data model for [ExpenseCategoryEntity] with Firestore serialization.
class ExpenseCategoryModel extends ExpenseCategoryEntity {
  const ExpenseCategoryModel({
    required super.id,
    required super.name,
    super.expenseTypes = const [],
    super.isActive = true,
    required super.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'expenseTypes': expenseTypes
          .map((e) => ExpenseTypeModel.fromEntity(e).toJson())
          .toList(),
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ExpenseCategoryModel.fromJson(Map<String, dynamic> json) {
    return ExpenseCategoryModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      expenseTypes: (json['expenseTypes'] as List<dynamic>?)
              ?.map(
                (e) => ExpenseTypeModel.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  factory ExpenseCategoryModel.fromEntity(ExpenseCategoryEntity entity) {
    return ExpenseCategoryModel(
      id: entity.id,
      name: entity.name,
      expenseTypes: entity.expenseTypes,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
    );
  }
}
