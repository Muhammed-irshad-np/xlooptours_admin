import 'package:equatable/equatable.dart';

import 'approval_stage_entity.dart';
import 'workflow_permission_config.dart';

/// Configurable finance rules: approval chains, workflow permissions,
/// receipt thresholds, and safety toggles.
///
/// Stored as a single Firestore document (`finance_policy/config`).
/// All workflow permissions are fully configurable — no hardcoded roles.
class FinancePolicyEntity extends Equatable {
  // ─── Legacy: Role-based Approval Limits ─────────────────────
  // Kept for backward compatibility; superseded by [approvalChain]
  // when the chain is non-empty.

  /// Max amount each role can approve alone (major units). Null = unlimited.
  final Map<String, double> approvalLimits;

  // ─── Multi-Level Approval Chain ─────────────────────────────

  /// Whether multi-level approval is enabled. When false, single-step
  /// approval using [approvalLimits] is used.
  final bool multiLevelApprovalEnabled;

  /// Ordered approval stages. Stage 0 runs first.
  /// If the expense amount exceeds stage N's maxAmount, it escalates to N+1.
  final List<ApprovalStageEntity> approvalChain;

  // ─── Receipt & Integrity Rules ──────────────────────────────

  /// Expenses at or above this amount require a receipt URL.
  final double receiptRequiredAbove;

  /// Require vehicle on fuel-type expenses (name contains FUEL).
  final bool requireVehicleForFuel;

  /// Require employee on salary-type expenses.
  final bool requireEmployeeForSalary;

  /// Block self-approval even for admins when false for non-admin...
  /// Admins may still self-approve via flag in use case.
  final bool blockSelfApprove;

  // ─── Workflow Permissions (fully configurable) ──────────────
  //
  // Each action is a WorkflowPermissionConfig with allowedRoles
  // and/or allowedUserIds. Admin/SuperAdmin always bypass.

  /// Who can open a petty cash daily session.
  /// Default: admin, super_admin (account coordinator assigned via account entity).
  final WorkflowPermissionConfig sessionOpen;

  /// Who can close (declare cash count) a petty cash daily session.
  /// Default: coordinator (the person operating the account).
  final WorkflowPermissionConfig sessionClose;

  /// Who can verify & lock a closed session.
  /// Default: admin, super_admin.
  final WorkflowPermissionConfig sessionVerify;

  /// Who can approve pending expenses (combined with approval chain/limits).
  final WorkflowPermissionConfig expenseApproval;

  /// Who can void already-approved expenses.
  final WorkflowPermissionConfig expenseVoid;

  /// Who can submit/create new expenses.
  final WorkflowPermissionConfig expenseSubmit;

  /// Who can deposit/withdraw from fund accounts.
  final WorkflowPermissionConfig fundMovement;

  /// Who can transfer between fund accounts.
  final WorkflowPermissionConfig fundTransfer;

  /// Who can create/edit/delete fund accounts.
  final WorkflowPermissionConfig accountManagement;

  /// Who can manage master data (categories, types, policies).
  final WorkflowPermissionConfig masterDataManagement;

  /// Who can issue/settle cash advances.
  final WorkflowPermissionConfig cashAdvanceManagement;

  // ─── Maintenance Work Orders ────────────────────────────────

  /// Who can report a vehicle fault (raise a work order in `reported`).
  /// Deliberately wide — drivers and the fleet manager live here.
  final WorkflowPermissionConfig workOrderRaise;

  /// Who can turn a report into a costed work order and send it for approval.
  final WorkflowPermissionConfig workOrderIssue;

  /// Who can approve the spend commitment on a work order.
  final WorkflowPermissionConfig workOrderApproval;

  /// Who can close a completed work order (which posts the expense).
  final WorkflowPermissionConfig workOrderClose;

  /// Work orders estimated below this amount skip approval entirely
  /// (major units). 0 disables auto-approval.
  final double workOrderAutoApproveBelow;

  /// How far the actual cost may exceed the approved amount before the work
  /// order must go back for re-approval, as a percentage.
  final double workOrderVarianceTolerancePct;

  /// When true, the expense created on close is born `approved` provided the
  /// actual cost is within the approved amount — the work-order approval
  /// already authorised that spend, so asking twice adds nothing.
  final bool autoApproveExpenseWithinEstimate;

  /// Require at least one invoice attachment before a work order can be
  /// marked complete.
  final bool requireInvoiceOnWorkOrderComplete;

  const FinancePolicyEntity({
    // Legacy approval limits
    this.approvalLimits = const {
      'manager': 5000,
      'finance': 50000,
      'admin': 999999999,
      'coordinator': 0,
      'driver': 0,
      'viewer': 0,
    },
    // Multi-level approval
    this.multiLevelApprovalEnabled = false,
    this.approvalChain = const [],
    // Receipt & integrity
    this.receiptRequiredAbove = 100,
    this.requireVehicleForFuel = true,
    this.requireEmployeeForSalary = true,
    this.blockSelfApprove = true,
    // Workflow permissions — sensible defaults
    this.sessionOpen = const WorkflowPermissionConfig(
      allowedRoles: ['admin', 'super_admin'],
    ),
    this.sessionClose = const WorkflowPermissionConfig(
      allowedRoles: ['coordinator', 'admin', 'super_admin'],
    ),
    this.sessionVerify = const WorkflowPermissionConfig(
      allowedRoles: ['admin', 'super_admin'],
    ),
    this.expenseApproval = const WorkflowPermissionConfig(
      allowedRoles: ['manager', 'finance', 'admin', 'super_admin'],
    ),
    this.expenseVoid = const WorkflowPermissionConfig(
      allowedRoles: ['finance', 'admin', 'super_admin'],
    ),
    this.expenseSubmit = const WorkflowPermissionConfig(
      allowedRoles: [
        'driver',
        'coordinator',
        'manager',
        'finance',
        'admin',
        'super_admin',
      ],
    ),
    this.fundMovement = const WorkflowPermissionConfig(
      allowedRoles: ['coordinator', 'finance', 'admin', 'super_admin'],
    ),
    this.fundTransfer = const WorkflowPermissionConfig(
      allowedRoles: ['finance', 'admin', 'super_admin'],
    ),
    this.accountManagement = const WorkflowPermissionConfig(
      allowedRoles: ['finance', 'admin', 'super_admin'],
    ),
    this.masterDataManagement = const WorkflowPermissionConfig(
      allowedRoles: ['admin', 'super_admin'],
    ),
    this.cashAdvanceManagement = const WorkflowPermissionConfig(
      allowedRoles: ['finance', 'admin', 'super_admin'],
    ),
    // Maintenance work orders
    this.workOrderRaise = const WorkflowPermissionConfig(
      allowedRoles: [
        'driver',
        'coordinator',
        'manager',
        'finance',
        'admin',
        'super_admin',
      ],
    ),
    this.workOrderIssue = const WorkflowPermissionConfig(
      allowedRoles: ['coordinator', 'manager', 'finance', 'admin', 'super_admin'],
    ),
    this.workOrderApproval = const WorkflowPermissionConfig(
      allowedRoles: ['manager', 'finance', 'admin', 'super_admin'],
    ),
    this.workOrderClose = const WorkflowPermissionConfig(
      allowedRoles: ['coordinator', 'finance', 'admin', 'super_admin'],
    ),
    this.workOrderAutoApproveBelow = 300,
    this.workOrderVarianceTolerancePct = 10,
    this.autoApproveExpenseWithinEstimate = true,
    this.requireInvoiceOnWorkOrderComplete = true,
  });

  // ─── Query Helpers ──────────────────────────────────────────

  double? limitForRole(String roleName) {
    final key = roleName.toLowerCase();
    return approvalLimits[key];
  }

  bool canApproveAmount(String roleName, double amount) {
    final limit = limitForRole(roleName);
    if (limit == null) return true;
    return amount <= limit + 1e-9;
  }

  /// Find the appropriate approval stage for a given amount.
  /// Returns null if multi-level is disabled or no stage matches.
  ApprovalStageEntity? stageForAmount(double amount) {
    if (!multiLevelApprovalEnabled || approvalChain.isEmpty) return null;
    final sorted = [...approvalChain]..sort((a, b) => a.order.compareTo(b.order));
    for (final stage in sorted) {
      if (stage.canApproveAmount(amount)) return stage;
    }
    // Return last stage (should be unlimited) as fallback
    return sorted.last;
  }

  /// Whether a work order estimated at [amount] can skip approval.
  bool workOrderSkipsApproval(double amount) =>
      workOrderAutoApproveBelow > 0 &&
      amount <= workOrderAutoApproveBelow + 1e-9;

  /// Highest actual cost a work order approved at [approvedAmount] may reach
  /// before it needs re-approval.
  double workOrderVarianceCeiling(double approvedAmount) =>
      approvedAmount * (1 + workOrderVarianceTolerancePct / 100);

  /// Whether [actual] is within tolerance of [approvedAmount].
  bool isWorkOrderVarianceAcceptable({
    required double approvedAmount,
    required double actual,
  }) =>
      actual <= workOrderVarianceCeiling(approvedAmount) + 1e-9;

  // ─── Copy / Serialization ──────────────────────────────────

  FinancePolicyEntity copyWith({
    Map<String, double>? approvalLimits,
    bool? multiLevelApprovalEnabled,
    List<ApprovalStageEntity>? approvalChain,
    double? receiptRequiredAbove,
    bool? requireVehicleForFuel,
    bool? requireEmployeeForSalary,
    bool? blockSelfApprove,
    WorkflowPermissionConfig? sessionOpen,
    WorkflowPermissionConfig? sessionClose,
    WorkflowPermissionConfig? sessionVerify,
    WorkflowPermissionConfig? expenseApproval,
    WorkflowPermissionConfig? expenseVoid,
    WorkflowPermissionConfig? expenseSubmit,
    WorkflowPermissionConfig? fundMovement,
    WorkflowPermissionConfig? fundTransfer,
    WorkflowPermissionConfig? accountManagement,
    WorkflowPermissionConfig? masterDataManagement,
    WorkflowPermissionConfig? cashAdvanceManagement,
    WorkflowPermissionConfig? workOrderRaise,
    WorkflowPermissionConfig? workOrderIssue,
    WorkflowPermissionConfig? workOrderApproval,
    WorkflowPermissionConfig? workOrderClose,
    double? workOrderAutoApproveBelow,
    double? workOrderVarianceTolerancePct,
    bool? autoApproveExpenseWithinEstimate,
    bool? requireInvoiceOnWorkOrderComplete,
  }) {
    return FinancePolicyEntity(
      approvalLimits: approvalLimits ?? this.approvalLimits,
      multiLevelApprovalEnabled:
          multiLevelApprovalEnabled ?? this.multiLevelApprovalEnabled,
      approvalChain: approvalChain ?? this.approvalChain,
      receiptRequiredAbove: receiptRequiredAbove ?? this.receiptRequiredAbove,
      requireVehicleForFuel:
          requireVehicleForFuel ?? this.requireVehicleForFuel,
      requireEmployeeForSalary:
          requireEmployeeForSalary ?? this.requireEmployeeForSalary,
      blockSelfApprove: blockSelfApprove ?? this.blockSelfApprove,
      sessionOpen: sessionOpen ?? this.sessionOpen,
      sessionClose: sessionClose ?? this.sessionClose,
      sessionVerify: sessionVerify ?? this.sessionVerify,
      expenseApproval: expenseApproval ?? this.expenseApproval,
      expenseVoid: expenseVoid ?? this.expenseVoid,
      expenseSubmit: expenseSubmit ?? this.expenseSubmit,
      fundMovement: fundMovement ?? this.fundMovement,
      fundTransfer: fundTransfer ?? this.fundTransfer,
      accountManagement: accountManagement ?? this.accountManagement,
      masterDataManagement: masterDataManagement ?? this.masterDataManagement,
      cashAdvanceManagement:
          cashAdvanceManagement ?? this.cashAdvanceManagement,
      workOrderRaise: workOrderRaise ?? this.workOrderRaise,
      workOrderIssue: workOrderIssue ?? this.workOrderIssue,
      workOrderApproval: workOrderApproval ?? this.workOrderApproval,
      workOrderClose: workOrderClose ?? this.workOrderClose,
      workOrderAutoApproveBelow:
          workOrderAutoApproveBelow ?? this.workOrderAutoApproveBelow,
      workOrderVarianceTolerancePct:
          workOrderVarianceTolerancePct ?? this.workOrderVarianceTolerancePct,
      autoApproveExpenseWithinEstimate: autoApproveExpenseWithinEstimate ??
          this.autoApproveExpenseWithinEstimate,
      requireInvoiceOnWorkOrderComplete: requireInvoiceOnWorkOrderComplete ??
          this.requireInvoiceOnWorkOrderComplete,
    );
  }

  Map<String, dynamic> toJson() => {
        'approvalLimits': approvalLimits,
        'multiLevelApprovalEnabled': multiLevelApprovalEnabled,
        'approvalChain': approvalChain.map((s) => s.toJson()).toList(),
        'receiptRequiredAbove': receiptRequiredAbove,
        'requireVehicleForFuel': requireVehicleForFuel,
        'requireEmployeeForSalary': requireEmployeeForSalary,
        'blockSelfApprove': blockSelfApprove,
        'sessionOpen': sessionOpen.toJson(),
        'sessionClose': sessionClose.toJson(),
        'sessionVerify': sessionVerify.toJson(),
        'expenseApproval': expenseApproval.toJson(),
        'expenseVoid': expenseVoid.toJson(),
        'expenseSubmit': expenseSubmit.toJson(),
        'fundMovement': fundMovement.toJson(),
        'fundTransfer': fundTransfer.toJson(),
        'accountManagement': accountManagement.toJson(),
        'masterDataManagement': masterDataManagement.toJson(),
        'cashAdvanceManagement': cashAdvanceManagement.toJson(),
        'workOrderRaise': workOrderRaise.toJson(),
        'workOrderIssue': workOrderIssue.toJson(),
        'workOrderApproval': workOrderApproval.toJson(),
        'workOrderClose': workOrderClose.toJson(),
        'workOrderAutoApproveBelow': workOrderAutoApproveBelow,
        'workOrderVarianceTolerancePct': workOrderVarianceTolerancePct,
        'autoApproveExpenseWithinEstimate': autoApproveExpenseWithinEstimate,
        'requireInvoiceOnWorkOrderComplete':
            requireInvoiceOnWorkOrderComplete,
      };

  factory FinancePolicyEntity.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const FinancePolicyEntity();

    // Parse legacy approval limits
    final rawLimits = json['approvalLimits'];
    final limits = <String, double>{};
    if (rawLimits is Map) {
      rawLimits.forEach((k, v) {
        limits[k.toString()] = (v as num).toDouble();
      });
    }

    // Parse approval chain
    final rawChain = json['approvalChain'] as List<dynamic>?;
    final chain = rawChain
            ?.map((e) =>
                ApprovalStageEntity.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return FinancePolicyEntity(
      approvalLimits: limits.isEmpty
          ? const FinancePolicyEntity().approvalLimits
          : limits,
      multiLevelApprovalEnabled:
          json['multiLevelApprovalEnabled'] as bool? ?? false,
      approvalChain: chain,
      receiptRequiredAbove:
          (json['receiptRequiredAbove'] as num?)?.toDouble() ?? 100,
      requireVehicleForFuel: json['requireVehicleForFuel'] as bool? ?? true,
      requireEmployeeForSalary:
          json['requireEmployeeForSalary'] as bool? ?? true,
      blockSelfApprove: json['blockSelfApprove'] as bool? ?? true,
      // Workflow permissions — backward compatible (missing → defaults)
      sessionOpen: json['sessionOpen'] != null
          ? WorkflowPermissionConfig.fromJson(
              json['sessionOpen'] as Map<String, dynamic>?)
          : const FinancePolicyEntity().sessionOpen,
      sessionClose: json['sessionClose'] != null
          ? WorkflowPermissionConfig.fromJson(
              json['sessionClose'] as Map<String, dynamic>?)
          : const FinancePolicyEntity().sessionClose,
      sessionVerify: json['sessionVerify'] != null
          ? WorkflowPermissionConfig.fromJson(
              json['sessionVerify'] as Map<String, dynamic>?)
          : const FinancePolicyEntity().sessionVerify,
      expenseApproval: json['expenseApproval'] != null
          ? WorkflowPermissionConfig.fromJson(
              json['expenseApproval'] as Map<String, dynamic>?)
          : const FinancePolicyEntity().expenseApproval,
      expenseVoid: json['expenseVoid'] != null
          ? WorkflowPermissionConfig.fromJson(
              json['expenseVoid'] as Map<String, dynamic>?)
          : const FinancePolicyEntity().expenseVoid,
      expenseSubmit: json['expenseSubmit'] != null
          ? WorkflowPermissionConfig.fromJson(
              json['expenseSubmit'] as Map<String, dynamic>?)
          : const FinancePolicyEntity().expenseSubmit,
      fundMovement: json['fundMovement'] != null
          ? WorkflowPermissionConfig.fromJson(
              json['fundMovement'] as Map<String, dynamic>?)
          : const FinancePolicyEntity().fundMovement,
      fundTransfer: json['fundTransfer'] != null
          ? WorkflowPermissionConfig.fromJson(
              json['fundTransfer'] as Map<String, dynamic>?)
          : const FinancePolicyEntity().fundTransfer,
      accountManagement: json['accountManagement'] != null
          ? WorkflowPermissionConfig.fromJson(
              json['accountManagement'] as Map<String, dynamic>?)
          : const FinancePolicyEntity().accountManagement,
      masterDataManagement: json['masterDataManagement'] != null
          ? WorkflowPermissionConfig.fromJson(
              json['masterDataManagement'] as Map<String, dynamic>?)
          : const FinancePolicyEntity().masterDataManagement,
      cashAdvanceManagement: json['cashAdvanceManagement'] != null
          ? WorkflowPermissionConfig.fromJson(
              json['cashAdvanceManagement'] as Map<String, dynamic>?)
          : const FinancePolicyEntity().cashAdvanceManagement,
      workOrderRaise: json['workOrderRaise'] != null
          ? WorkflowPermissionConfig.fromJson(
              json['workOrderRaise'] as Map<String, dynamic>?)
          : const FinancePolicyEntity().workOrderRaise,
      workOrderIssue: json['workOrderIssue'] != null
          ? WorkflowPermissionConfig.fromJson(
              json['workOrderIssue'] as Map<String, dynamic>?)
          : const FinancePolicyEntity().workOrderIssue,
      workOrderApproval: json['workOrderApproval'] != null
          ? WorkflowPermissionConfig.fromJson(
              json['workOrderApproval'] as Map<String, dynamic>?)
          : const FinancePolicyEntity().workOrderApproval,
      workOrderClose: json['workOrderClose'] != null
          ? WorkflowPermissionConfig.fromJson(
              json['workOrderClose'] as Map<String, dynamic>?)
          : const FinancePolicyEntity().workOrderClose,
      workOrderAutoApproveBelow:
          (json['workOrderAutoApproveBelow'] as num?)?.toDouble() ?? 300,
      workOrderVarianceTolerancePct:
          (json['workOrderVarianceTolerancePct'] as num?)?.toDouble() ?? 10,
      autoApproveExpenseWithinEstimate:
          json['autoApproveExpenseWithinEstimate'] as bool? ?? true,
      requireInvoiceOnWorkOrderComplete:
          json['requireInvoiceOnWorkOrderComplete'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [
        approvalLimits,
        multiLevelApprovalEnabled,
        approvalChain,
        receiptRequiredAbove,
        requireVehicleForFuel,
        requireEmployeeForSalary,
        blockSelfApprove,
        sessionOpen,
        sessionClose,
        sessionVerify,
        expenseApproval,
        expenseVoid,
        expenseSubmit,
        fundMovement,
        fundTransfer,
        accountManagement,
        masterDataManagement,
        cashAdvanceManagement,
        workOrderRaise,
        workOrderIssue,
        workOrderApproval,
        workOrderClose,
        workOrderAutoApproveBelow,
        workOrderVarianceTolerancePct,
        autoApproveExpenseWithinEstimate,
        requireInvoiceOnWorkOrderComplete,
      ];
}
