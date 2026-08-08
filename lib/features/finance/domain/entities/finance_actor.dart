import 'package:equatable/equatable.dart';

/// Who performed a finance action — always a real person, never "Admin".
class FinanceActor extends Equatable {
  final String userId;
  final String displayName;
  final String? email;
  final String roleName;

  const FinanceActor({
    required this.userId,
    required this.displayName,
    this.email,
    required this.roleName,
  });

  String get label {
    if (displayName.trim().isNotEmpty) return displayName.trim();
    if (email != null && email!.trim().isNotEmpty) return email!.trim();
    return userId;
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'displayName': displayName,
        'email': email,
        'roleName': roleName,
      };

  factory FinanceActor.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const FinanceActor(
        userId: '',
        displayName: 'Unknown',
        roleName: 'viewer',
      );
    }
    return FinanceActor(
      userId: json['userId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Unknown',
      email: json['email'] as String?,
      roleName: json['roleName'] as String? ?? 'viewer',
    );
  }

  @override
  List<Object?> get props => [userId, displayName, email, roleName];
}
