import '../../domain/entities/customer_entity.dart';

class CustomerModel extends CustomerEntity {
  const CustomerModel({
    required super.id,
    required super.name,
    required super.phone,
    super.email,
    super.companyId,
    super.companyName,
    super.assignedCaseCodes,
    super.status,
    required super.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'companyId': companyId,
      'companyName': companyName,
      'assignedCaseCodes': assignedCaseCodes,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    String rawPhone = json['phone'] as String;
    // Sanitize malformed phone numbers previously saved due to a bug
    // E.g., "<optimized out>#23704(+966).value 591984003" -> "+966 591984003"
    if (rawPhone.contains('<optimized out>') && rawPhone.contains('.value')) {
      final match = RegExp(r'\(([^)]+)\)\.value\s+(.+)').firstMatch(rawPhone);
      if (match != null && match.groupCount >= 2) {
        rawPhone = '${match.group(1)} ${match.group(2)}';
      }
    }

    return CustomerModel(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: rawPhone,
      email: json['email'] as String?,
      companyId: json['companyId'] as String?,
      companyName: json['companyName'] as String?,
      assignedCaseCodes:
          (json['assignedCaseCodes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      status: json['status'] as String? ?? 'ACTIVE',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(), // Fallback if missing
    );
  }

  factory CustomerModel.fromEntity(CustomerEntity entity) {
    return CustomerModel(
      id: entity.id,
      name: entity.name,
      phone: entity.phone,
      email: entity.email,
      companyId: entity.companyId,
      companyName: entity.companyName,
      assignedCaseCodes: entity.assignedCaseCodes,
      status: entity.status,
      createdAt: entity.createdAt,
    );
  }

  CustomerModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? companyId,
    String? companyName,
    List<String>? assignedCaseCodes,
    String? status,
    DateTime? createdAt,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      assignedCaseCodes: assignedCaseCodes ?? this.assignedCaseCodes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
