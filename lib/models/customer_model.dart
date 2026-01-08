class CustomerModel {
  final String id;
  final String name;
  final String phone;
  final String? companyId; // Null if independent
  final String? companyName; // Snapshot for easier display
  final List<String> assignedCaseCodes;
  final String status;
  final DateTime createdAt;

  CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    this.companyId,
    this.companyName,
    this.assignedCaseCodes = const [],
    this.status = 'ACTIVE',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'companyId': companyId,
      'companyName': companyName,
      'assignedCaseCodes': assignedCaseCodes,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
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
          : null,
    );
  }

  CustomerModel copyWith({
    String? id,
    String? name,
    String? phone,
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
