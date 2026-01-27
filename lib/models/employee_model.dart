class EmployeeModel {
  final String id;
  final String fullName;
  final String position;
  final String email;
  final String phoneNumber;
  final String nationality;
  final String idType;
  final String idNumber;
  final DateTime? joinDate;
  final DateTime? birthDate;
  final String gender;
  final String? driverType; // Internal or External (only for Drivers)
  final bool isActive;

  EmployeeModel({
    required this.id,
    required this.fullName,
    required this.position,
    required this.email,
    required this.phoneNumber,
    required this.nationality,
    required this.idType,
    required this.idNumber,
    this.joinDate,
    this.birthDate,
    required this.gender,
    this.driverType,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'position': position,
      'email': email,
      'phoneNumber': phoneNumber,
      'nationality': nationality,
      'idType': idType,
      'idNumber': idNumber,
      'joinDate': joinDate?.toIso8601String(),
      'birthDate': birthDate?.toIso8601String(),
      'gender': gender,
      'driverType': driverType,
      'isActive': isActive,
    };
  }

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      position: json['position'] as String,
      email: json['email'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      nationality: json['nationality'] as String? ?? '',
      idType: json['idType'] as String? ?? '',
      idNumber: json['idNumber'] as String? ?? '',
      joinDate: json['joinDate'] != null
          ? DateTime.tryParse(json['joinDate'] as String)
          : null,
      birthDate: json['birthDate'] != null
          ? DateTime.tryParse(json['birthDate'] as String)
          : null,
      gender: json['gender'] as String? ?? '',
      driverType: json['driverType'] as String?,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  EmployeeModel copyWith({
    String? id,
    String? fullName,
    String? position,
    String? email,
    String? phoneNumber,
    String? nationality,
    String? idType,
    String? idNumber,
    DateTime? joinDate,
    DateTime? birthDate,
    String? gender,
    String? driverType,
    bool? isActive,
  }) {
    return EmployeeModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      position: position ?? this.position,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      nationality: nationality ?? this.nationality,
      idType: idType ?? this.idType,
      idNumber: idNumber ?? this.idNumber,
      joinDate: joinDate ?? this.joinDate,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      driverType: driverType ?? this.driverType,
      isActive: isActive ?? this.isActive,
    );
  }
}
