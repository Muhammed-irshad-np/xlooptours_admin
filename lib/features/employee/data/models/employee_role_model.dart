import '../../domain/entities/employee_role_entity.dart';

class EmployeeRoleModel extends EmployeeRoleEntity {
  const EmployeeRoleModel({
    required super.id,
    required super.name,
    super.category,
  });

  factory EmployeeRoleModel.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as String?;
    return EmployeeRoleModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: EmployeeRoleCategory.values.contains(category)
          ? category!
          : EmployeeRoleCategory.other,
    );
  }

  factory EmployeeRoleModel.fromEntity(EmployeeRoleEntity entity) {
    return EmployeeRoleModel(
      id: entity.id,
      name: entity.name,
      category: entity.category,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'category': category};
  }
}
