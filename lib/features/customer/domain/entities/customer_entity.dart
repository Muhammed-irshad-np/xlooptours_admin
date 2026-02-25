import 'package:equatable/equatable.dart';

class CustomerEntity extends Equatable {
  final String id;
  final String name;
  final String phone;
  final String? companyId; // Null if independent
  final String? companyName; // Snapshot for easier display
  final List<String> assignedCaseCodes;
  final String? email;
  final String status;
  final DateTime createdAt;

  const CustomerEntity({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.companyId,
    this.companyName,
    this.assignedCaseCodes = const [],
    this.status = 'ACTIVE',
    required this.createdAt,
  });

  CustomerEntity copyWith({
    String? id,
    String? name,
    String? phone,
    String? companyId,
    String? companyName,
    List<String>? assignedCaseCodes,
    String? email,
    String? status,
    DateTime? createdAt,
  }) {
    return CustomerEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      assignedCaseCodes: assignedCaseCodes ?? this.assignedCaseCodes,
      email: email ?? this.email,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    phone,
    companyId,
    companyName,
    assignedCaseCodes,
    email,
    status,
    createdAt,
  ];
}
