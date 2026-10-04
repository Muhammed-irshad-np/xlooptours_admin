import 'package:equatable/equatable.dart';

/// Which tab of the Employees list a role is grouped under.
class EmployeeRoleCategory {
  static const String management = 'Management';
  static const String office = 'Office';
  static const String other = 'Other';

  static const List<String> values = [management, office, other];
}

/// A position an employee can hold. The built-in [defaults] are fixed; new
/// roles are added from Employee Masters → Employee Roles.
///
/// Employees store the role [name] as their `position` string.
class EmployeeRoleEntity extends Equatable {
  final String id;
  final String name;
  final String category;

  const EmployeeRoleEntity({
    required this.id,
    required this.name,
    this.category = EmployeeRoleCategory.other,
  });

  EmployeeRoleEntity copyWith({String? id, String? name, String? category}) {
    return EmployeeRoleEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
    );
  }

  /// True for the built-in roles, which can't be edited or deleted.
  bool get isBuiltIn => defaults.any((d) => d.id == id);

  /// The built-in roles. Only roles created from the master are stored in
  /// Firestore.
  static const List<EmployeeRoleEntity> defaults = [
    EmployeeRoleEntity(
      id: 'ceo',
      name: 'CEO',
      category: EmployeeRoleCategory.management,
    ),
    EmployeeRoleEntity(
      id: 'coo',
      name: 'COO',
      category: EmployeeRoleCategory.management,
    ),
    EmployeeRoleEntity(
      id: 'cfo',
      name: 'CFO',
      category: EmployeeRoleCategory.management,
    ),
    EmployeeRoleEntity(id: 'driver', name: 'Driver'),
    EmployeeRoleEntity(
      id: 'senior-software-developer',
      name: 'Senior Software Developer',
      category: EmployeeRoleCategory.office,
    ),
    EmployeeRoleEntity(
      id: 'administrative-officer',
      name: 'Administrative Officer',
      category: EmployeeRoleCategory.office,
    ),
    EmployeeRoleEntity(id: 'other', name: 'Other'),
  ];

  @override
  List<Object?> get props => [id, name, category];
}
