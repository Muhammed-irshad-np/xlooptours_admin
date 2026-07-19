import '../../domain/entities/expense_category_entity.dart';

/// Data model for [ExpenseTypeEntity] with JSON serialization.
class ExpenseTypeModel extends ExpenseTypeEntity {
  const ExpenseTypeModel({
    required super.id,
    required super.name,
    required super.defaultDuration,
    super.isRecurring = false,
    super.defaultAmount,
    super.priority = 'MANDATORY',
    required super.submittedByRole,
    super.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'defaultDuration': defaultDuration,
      'isRecurring': isRecurring,
      'defaultAmount': defaultAmount,
      'priority': priority,
      'submittedByRole': submittedByRole,
      'isActive': isActive,
    };
  }

  factory ExpenseTypeModel.fromJson(Map<String, dynamic> json) {
    return ExpenseTypeModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      defaultDuration: json['defaultDuration'] as String? ?? 'MONTHLY',
      isRecurring: json['isRecurring'] as bool? ?? false,
      defaultAmount: (json['defaultAmount'] as num?)?.toDouble(),
      priority: json['priority'] as String? ?? 'MANDATORY',
      submittedByRole: json['submittedByRole'] as String? ?? 'ADMIN',
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  factory ExpenseTypeModel.fromEntity(ExpenseTypeEntity entity) {
    return ExpenseTypeModel(
      id: entity.id,
      name: entity.name,
      defaultDuration: entity.defaultDuration,
      isRecurring: entity.isRecurring,
      defaultAmount: entity.defaultAmount,
      priority: entity.priority,
      submittedByRole: entity.submittedByRole,
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
