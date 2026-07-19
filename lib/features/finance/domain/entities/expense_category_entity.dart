import 'package:equatable/equatable.dart';

/// Represents a single expense type within a category.
///
/// For example, under "VEHICLES" category, types could be
/// "Fuel", "Car Wash", "Maintenance", etc.
class ExpenseTypeEntity extends Equatable {
  final String id;
  final String name;

  /// How often this expense typically occurs.
  final String defaultDuration; // DAILY, WEEKLY, MONTHLY, QUARTERLY, YEARLY, ONE_TIME, etc.

  /// Whether this expense recurs automatically.
  final bool isRecurring;

  /// Default/expected amount for this type (0 means variable).
  final double? defaultAmount;

  /// Priority level for this expense type.
  final String priority; // MANDATORY, IF_REQUIRED

  /// Which role is expected to submit this expense.
  final String submittedByRole; // ADMIN, COORDINATOR, DRIVER

  final bool isActive;

  const ExpenseTypeEntity({
    required this.id,
    required this.name,
    required this.defaultDuration,
    this.isRecurring = false,
    this.defaultAmount,
    this.priority = 'MANDATORY',
    required this.submittedByRole,
    this.isActive = true,
  });

  ExpenseTypeEntity copyWith({
    String? id,
    String? name,
    String? defaultDuration,
    bool? isRecurring,
    double? defaultAmount,
    String? priority,
    String? submittedByRole,
    bool? isActive,
    bool clearDefaultAmount = false,
  }) {
    return ExpenseTypeEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      defaultDuration: defaultDuration ?? this.defaultDuration,
      isRecurring: isRecurring ?? this.isRecurring,
      defaultAmount: clearDefaultAmount
          ? null
          : (defaultAmount ?? this.defaultAmount),
      priority: priority ?? this.priority,
      submittedByRole: submittedByRole ?? this.submittedByRole,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        defaultDuration,
        isRecurring,
        defaultAmount,
        priority,
        submittedByRole,
        isActive,
      ];
}

/// Represents a top-level expense category (e.g., COMPANY, EMPLOYEES, VEHICLES).
///
/// Each category contains a list of expense types. Categories and types
/// are configurable by the admin through the settings page.
class ExpenseCategoryEntity extends Equatable {
  final String id;
  final String name;
  final List<ExpenseTypeEntity> expenseTypes;
  final bool isActive;
  final DateTime createdAt;

  const ExpenseCategoryEntity({
    required this.id,
    required this.name,
    this.expenseTypes = const [],
    this.isActive = true,
    required this.createdAt,
  });

  factory ExpenseCategoryEntity.empty() {
    return ExpenseCategoryEntity(
      id: '',
      name: '',
      createdAt: DateTime.now(),
    );
  }

  ExpenseCategoryEntity copyWith({
    String? id,
    String? name,
    List<ExpenseTypeEntity>? expenseTypes,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return ExpenseCategoryEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      expenseTypes: expenseTypes ?? this.expenseTypes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, name, expenseTypes, isActive, createdAt];
}
