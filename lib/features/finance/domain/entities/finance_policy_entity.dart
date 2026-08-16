import 'package:equatable/equatable.dart';

/// Configurable finance rules (approval limits, receipt threshold, etc.).
class FinancePolicyEntity extends Equatable {
  /// Max amount each role can approve alone (major units). Null = unlimited.
  final Map<String, double> approvalLimits;

  /// Expenses at or above this amount require a receipt URL.
  final double receiptRequiredAbove;

  /// Require vehicle on fuel-type expenses (name contains FUEL).
  final bool requireVehicleForFuel;

  /// Require employee on salary-type expenses.
  final bool requireEmployeeForSalary;

  /// Block self-approval even for admins when false for non-admin... 
  /// Admins may still self-approve via flag in use case.
  final bool blockSelfApprove;

  const FinancePolicyEntity({
    this.approvalLimits = const {
      'manager': 5000,
      'finance': 50000,
      'admin': 999999999,
      'coordinator': 0,
      'driver': 0,
      'viewer': 0,
    },
    this.receiptRequiredAbove = 100,
    this.requireVehicleForFuel = true,
    this.requireEmployeeForSalary = true,
    this.blockSelfApprove = true,
  });

  double? limitForRole(String roleName) {
    final key = roleName.toLowerCase();
    return approvalLimits[key];
  }

  bool canApproveAmount(String roleName, double amount) {
    final limit = limitForRole(roleName);
    if (limit == null) return true;
    return amount <= limit + 1e-9;
  }

  FinancePolicyEntity copyWith({
    Map<String, double>? approvalLimits,
    double? receiptRequiredAbove,
    bool? requireVehicleForFuel,
    bool? requireEmployeeForSalary,
    bool? blockSelfApprove,
  }) {
    return FinancePolicyEntity(
      approvalLimits: approvalLimits ?? this.approvalLimits,
      receiptRequiredAbove: receiptRequiredAbove ?? this.receiptRequiredAbove,
      requireVehicleForFuel:
          requireVehicleForFuel ?? this.requireVehicleForFuel,
      requireEmployeeForSalary:
          requireEmployeeForSalary ?? this.requireEmployeeForSalary,
      blockSelfApprove: blockSelfApprove ?? this.blockSelfApprove,
    );
  }

  Map<String, dynamic> toJson() => {
        'approvalLimits': approvalLimits,
        'receiptRequiredAbove': receiptRequiredAbove,
        'requireVehicleForFuel': requireVehicleForFuel,
        'requireEmployeeForSalary': requireEmployeeForSalary,
        'blockSelfApprove': blockSelfApprove,
      };

  factory FinancePolicyEntity.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const FinancePolicyEntity();
    final rawLimits = json['approvalLimits'];
    final limits = <String, double>{};
    if (rawLimits is Map) {
      rawLimits.forEach((k, v) {
        limits[k.toString()] = (v as num).toDouble();
      });
    }
    return FinancePolicyEntity(
      approvalLimits: limits.isEmpty
          ? const FinancePolicyEntity().approvalLimits
          : limits,
      receiptRequiredAbove:
          (json['receiptRequiredAbove'] as num?)?.toDouble() ?? 100,
      requireVehicleForFuel: json['requireVehicleForFuel'] as bool? ?? true,
      requireEmployeeForSalary:
          json['requireEmployeeForSalary'] as bool? ?? true,
      blockSelfApprove: json['blockSelfApprove'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [
        approvalLimits,
        receiptRequiredAbove,
        requireVehicleForFuel,
        requireEmployeeForSalary,
        blockSelfApprove,
      ];
}
