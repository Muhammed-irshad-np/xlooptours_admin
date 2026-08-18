import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:xloop_invoice/features/finance/domain/entities/approval_stage_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/finance_policy_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/workflow_permission_config.dart';
import 'package:xloop_invoice/features/finance/presentation/pages/finance_dashboard_page.dart';
import 'package:xloop_invoice/features/finance/presentation/providers/finance_provider.dart';
import 'package:xloop_invoice/features/finance/presentation/widgets/finance_dialog_helpers.dart';
import 'package:xloop_invoice/features/user_management/domain/entities/managed_user_entity.dart';
import 'package:xloop_invoice/features/user_management/domain/entities/role_entity.dart';
import 'package:xloop_invoice/features/user_management/presentation/providers/user_management_provider.dart';

/// Comprehensive Master Data view for Finance Roles, Workflow Permissions & Multi-Level Approvals.
///
/// Features:
/// 1. Zero hardcoded roles: Every finance operation is driven by policy configuration.
/// 2. Dual Assignment: Supports selecting allowed Roles, specific Users, or a combination.
/// 3. Petty Cash Session Permissions: Open, Close, Verify & Lock.
/// 4. Multi-Level Approval Chain: Toggleable ordered approval stages with custom thresholds.
/// 5. Single-Step Approval & Limits: Role thresholds + specific approver assignments.
/// 6. Fund & Account Operations: Movement, transfers, account creation, master data access.
/// 7. Safety & Compliance Controls: Receipt mandatory threshold, fuel/salary tagging, self-approval block.
class FinanceWorkflowPolicyView extends StatefulWidget {
  const FinanceWorkflowPolicyView({super.key});

  @override
  State<FinanceWorkflowPolicyView> createState() =>
      _FinanceWorkflowPolicyViewState();
}

class _FinanceWorkflowPolicyViewState extends State<FinanceWorkflowPolicyView> {
  int _activeCategoryIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userMgmt = context.read<UserManagementProvider>();
      if (userMgmt.roles.isEmpty || userMgmt.users.isEmpty) {
        userMgmt.loadInitialData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final finProv = context.watch<FinanceProvider>();
    final userMgmt = context.watch<UserManagementProvider>();
    final policy = finProv.policy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Action Bar ──────────────────────────────────────────
        Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: FinDT.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: FinDT.brand.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 20.sp,
                      color: FinDT.brand,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Finance Workflow & Role Governance',
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: FinDT.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'Configure who can perform each finance action (by system role or specific user assignments)',
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          color: FinDT.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _confirmResetDefaults(context, finProv),
                    icon: Icon(Icons.restore_rounded, size: 15.sp),
                    label: Text(
                      'Reset Defaults',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FinDT.textSecondary,
                      side: const BorderSide(color: FinDT.border),
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 10.h,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  ElevatedButton.icon(
                    onPressed: () =>
                        _showComplianceSettingsDialog(context, finProv, policy),
                    icon: Icon(Icons.tune_rounded, size: 15.sp),
                    label: Text(
                      'Compliance Rules',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FinDT.brand,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 10.h,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),

        // ── Governance Category Tabs ────────────────────────────
        _buildCategoryPills(),
        SizedBox(height: 16.h),

        // ── Active Governance View ──────────────────────────────
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _buildActiveCategoryContent(finProv, userMgmt, policy),
        ),
      ],
    );
  }

  Widget _buildCategoryPills() {
    final categories = [
      _PolicyCategoryItem(
        title: 'Petty Cash Sessions',
        icon: Icons.book_outlined,
        subtitle: 'Open, close & audit daily registers',
      ),
      _PolicyCategoryItem(
        title: 'Expense Approvals & Chain',
        icon: Icons.checklist_rounded,
        subtitle: 'Multi-level approvals, limits & voiding',
      ),
      _PolicyCategoryItem(
        title: 'Fund Operations & Accounts',
        icon: Icons.account_balance_wallet_outlined,
        subtitle: 'Movement, transfers & account setup',
      ),
      _PolicyCategoryItem(
        title: 'Compliance & Safety Limits',
        icon: Icons.shield_outlined,
        subtitle: 'Receipt thresholds & integrity rules',
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(categories.length, (index) {
          final isSelected = _activeCategoryIndex == index;
          final item = categories[index];
          return Padding(
            padding: EdgeInsets.only(right: 10.w),
            child: InkWell(
              onTap: () => setState(() => _activeCategoryIndex = index),
              borderRadius: BorderRadius.circular(12.r),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: isSelected ? FinDT.brand : FinDT.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: FinDT.brand.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      size: 18.sp,
                      color: isSelected ? FinDT.brand : FinDT.textSecondary,
                    ),
                    SizedBox(width: 8.w),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.title,
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: isSelected
                                ? FinDT.brand
                                : FinDT.textPrimary,
                          ),
                        ),
                        Text(
                          item.subtitle,
                          style: GoogleFonts.inter(
                            fontSize: 10.sp,
                            color: FinDT.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildActiveCategoryContent(
    FinanceProvider finProv,
    UserManagementProvider userMgmt,
    FinancePolicyEntity policy,
  ) {
    switch (_activeCategoryIndex) {
      case 0:
        return _buildPettyCashSection(finProv, userMgmt, policy);
      case 1:
        return _buildExpenseApprovalSection(finProv, userMgmt, policy);
      case 2:
        return _buildFundOperationsSection(finProv, userMgmt, policy);
      case 3:
        return _buildComplianceSummarySection(finProv, policy);
      default:
        return const SizedBox.shrink();
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // 1. PETTY CASH WORKFLOW SECTION
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildPettyCashSection(
    FinanceProvider finProv,
    UserManagementProvider userMgmt,
    FinancePolicyEntity policy,
  ) {
    return Column(
      key: const ValueKey('petty_cash_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoBanner(
          icon: Icons.info_outline_rounded,
          title: 'Petty Cash Daily Session Governance',
          message:
              'In standard operation, an Admin or assigned personnel opens the session in the morning, the Coordinator executes expenses during the day and closes the register with a declared cash count, and an Admin/SuperAdmin performs the final audit to verify & lock the session.',
        ),
        SizedBox(height: 16.h),

        _buildPermissionConfigCard(
          title: 'Open Daily Session',
          description:
              'Authorized to unlock the drawer in the morning and record opening balances (Cash + STC Pay). Note: The assigned coordinator of the account always retains access.',
          icon: Icons.lock_open_rounded,
          color: const Color(0xFF0284C7),
          config: policy.sessionOpen,
          allRoles: userMgmt.roles,
          allUsers: userMgmt.users,
          onSave: (newConfig) async {
            final updated = policy.copyWith(sessionOpen: newConfig);
            await _savePolicy(finProv, updated, 'Open session permission updated');
          },
        ),
        SizedBox(height: 12.h),

        _buildPermissionConfigCard(
          title: 'Close Daily Session & Declare Cash Count',
          description:
              'Authorized to end daily operations, count remaining physical cash/STC float, upload receipt tally sheets, and submit for audit. Note: The assigned coordinator always retains access.',
          icon: Icons.lock_clock_outlined,
          color: const Color(0xFFD97706),
          config: policy.sessionClose,
          allRoles: userMgmt.roles,
          allUsers: userMgmt.users,
          onSave: (newConfig) async {
            final updated = policy.copyWith(sessionClose: newConfig);
            await _savePolicy(finProv, updated, 'Close session permission updated');
          },
        ),
        SizedBox(height: 12.h),

        _buildPermissionConfigCard(
          title: 'Verify & Lock Day (Final Audit)',
          description:
              'Authorized to review discrepancies (overage/shortage), audit receipt attachments, and permanently lock the day against further modification.',
          icon: Icons.verified_user_outlined,
          color: const Color(0xFF16A34A),
          config: policy.sessionVerify,
          allRoles: userMgmt.roles,
          allUsers: userMgmt.users,
          onSave: (newConfig) async {
            final updated = policy.copyWith(sessionVerify: newConfig);
            await _savePolicy(finProv, updated, 'Verify & lock permission updated');
          },
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // 2. EXPENSE APPROVAL & MULTI-LEVEL CHAIN SECTION
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildExpenseApprovalSection(
    FinanceProvider finProv,
    UserManagementProvider userMgmt,
    FinancePolicyEntity policy,
  ) {
    final formatter = NumberFormat('#,##0.00', 'en_US');

    return Column(
      key: const ValueKey('expense_approval_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Multi-Level Toggle Banner
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: FinDT.border),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: policy.multiLevelApprovalEnabled
                      ? FinDT.brand.withValues(alpha: 0.1)
                      : FinDT.bgPage,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  Icons.account_tree_outlined,
                  size: 22.sp,
                  color: policy.multiLevelApprovalEnabled
                      ? FinDT.brand
                      : FinDT.textSecondary,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Multi-Level Approval Chain',
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: FinDT.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      policy.multiLevelApprovalEnabled
                          ? 'Expenses follow ordered stages based on amount thresholds. Higher amounts require escalation.'
                          : 'Single-step approvals using standard role limits and assigned approver list.',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        color: FinDT.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: policy.multiLevelApprovalEnabled,
                activeTrackColor: FinDT.brand,
                onChanged: (val) async {
                  // If enabling and chain is empty, create initial default stages
                  List<ApprovalStageEntity> chain = policy.approvalChain;
                  if (val && chain.isEmpty) {
                    chain = [
                      const ApprovalStageEntity(
                        name: 'Stage 1: Operational Review',
                        order: 0,
                        maxAmount: 5000,
                        approverRoles: ['coordinator', 'manager', 'admin'],
                      ),
                      const ApprovalStageEntity(
                        name: 'Stage 2: Finance Director Sign-off',
                        order: 1,
                        maxAmount: 50000,
                        approverRoles: ['finance', 'manager', 'admin'],
                      ),
                      const ApprovalStageEntity(
                        name: 'Stage 3: Executive Approval',
                        order: 2,
                        maxAmount: null, // Unlimited
                        approverRoles: ['admin', 'super_admin'],
                      ),
                    ];
                  }
                  final updated = policy.copyWith(
                    multiLevelApprovalEnabled: val,
                    approvalChain: chain,
                  );
                  await _savePolicy(
                    finProv,
                    updated,
                    val
                        ? 'Multi-level approval chain activated'
                        : 'Single-step approval mode activated',
                  );
                },
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),

        // Conditional Body: Multi-Level Stages or Single-Step Grid
        if (policy.multiLevelApprovalEnabled)
          _buildMultiLevelChainBuilder(finProv, userMgmt, policy, formatter)
        else
          _buildSingleStepApprovalConfig(finProv, userMgmt, policy, formatter),

        SizedBox(height: 16.h),

        // Void & Submission Permissions
        _buildPermissionConfigCard(
          title: 'Void & Reverse Approved Expenses',
          description:
              'Authorized to void an already approved/paid expense, restoring funds back to the originating wallet and marking ledger audit tags.',
          icon: Icons.undo_rounded,
          color: const Color(0xFF7C3AED),
          config: policy.expenseVoid,
          allRoles: userMgmt.roles,
          allUsers: userMgmt.users,
          onSave: (newConfig) async {
            final updated = policy.copyWith(expenseVoid: newConfig);
            await _savePolicy(finProv, updated, 'Void expense permission updated');
          },
        ),
        SizedBox(height: 12.h),

        _buildPermissionConfigCard(
          title: 'Submit & Create New Expenses',
          description:
              'Authorized to create expense drafts and submit claims for approval against active funds.',
          icon: Icons.receipt_long_outlined,
          color: const Color(0xFF0284C7),
          config: policy.expenseSubmit,
          allRoles: userMgmt.roles,
          allUsers: userMgmt.users,
          onSave: (newConfig) async {
            final updated = policy.copyWith(expenseSubmit: newConfig);
            await _savePolicy(finProv, updated, 'Submit expense permission updated');
          },
        ),
      ],
    );
  }

  Widget _buildMultiLevelChainBuilder(
    FinanceProvider finProv,
    UserManagementProvider userMgmt,
    FinancePolicyEntity policy,
    NumberFormat formatter,
  ) {
    final stages = [...policy.approvalChain]
      ..sort((a, b) => a.order.compareTo(b.order));

    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: FinDT.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.format_list_numbered_rounded,
                      size: 18.sp, color: FinDT.brand),
                  SizedBox(width: 8.w),
                  Text(
                    'Approval Escalation Stages (${stages.length})',
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: FinDT.textPrimary,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddOrEditStageDialog(
                  context,
                  finProv,
                  policy,
                  userMgmt,
                  null,
                  stages.length,
                ),
                icon: Icon(Icons.add_rounded, size: 15.sp),
                label: Text(
                  'Add Approval Stage',
                  style: GoogleFonts.inter(
                      fontSize: 11.sp, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FinDT.brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),

          if (stages.isEmpty)
            Container(
              padding: EdgeInsets.all(20.w),
              alignment: Alignment.center,
              child: Text(
                'No approval stages configured yet. Click "Add Approval Stage" to define your chain.',
                style: GoogleFonts.inter(
                    fontSize: 12.sp, color: FinDT.textSecondary),
              ),
            )
          else
            ...stages.asMap().entries.map((entry) {
              final idx = entry.key;
              final stage = entry.value;
              return _buildStageCard(
                context: context,
                finProv: finProv,
                userMgmt: userMgmt,
                policy: policy,
                stage: stage,
                index: idx,
                total: stages.length,
                formatter: formatter,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildStageCard({
    required BuildContext context,
    required FinanceProvider finProv,
    required UserManagementProvider userMgmt,
    required FinancePolicyEntity policy,
    required ApprovalStageEntity stage,
    required int index,
    required int total,
    required NumberFormat formatter,
  }) {
    final isUnlimited = stage.maxAmount == null;

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: FinDT.bgPage,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: FinDT.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stage Number Badge
            Container(
              width: 32.w,
              height: 32.h,
              decoration: BoxDecoration(
                color: FinDT.brand,
                borderRadius: BorderRadius.circular(8.r),
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(width: 12.w),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        stage.name,
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: FinDT.textPrimary,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: isUnlimited
                              ? FinDT.brand.withValues(alpha: 0.1)
                              : const Color(0xFF16A34A).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          isUnlimited
                              ? 'Unlimited SAR'
                              : 'Up to ${formatter.format(stage.maxAmount)} SAR',
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            color: isUnlimited
                                ? FinDT.brand
                                : const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),

                  // Authorized Roles / Users chips
                  Wrap(
                    spacing: 6.w,
                    runSpacing: 4.h,
                    children: [
                      if (stage.approverRoles.isEmpty &&
                          stage.approverUserIds.isEmpty)
                        Text(
                          'Admins only (no roles or users assigned)',
                          style: GoogleFonts.inter(
                              fontSize: 11.sp, color: FinDT.textMuted),
                        ),
                      ...stage.approverRoles.map((r) => _buildRoleChip(r)),
                      ...stage.approverUserNames
                          .map((u) => _buildUserChip(u)),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.w),

            // Action Buttons (Edit, Delete, Move)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _showAddOrEditStageDialog(
                    context,
                    finProv,
                    policy,
                    userMgmt,
                    stage,
                    index,
                  ),
                  icon: Icon(Icons.edit_outlined,
                      size: 16.sp, color: FinDT.textSecondary),
                  tooltip: 'Edit Stage',
                ),
                IconButton(
                  onPressed: () async {
                    await showFinConfirmationDialog(
                      context: context,
                      title: 'Delete Approval Stage?',
                      message:
                          'Are you sure you want to remove "${stage.name}" from the approval chain?',
                      confirmLabel: 'Delete',
                      confirmColor: FinDT.danger,
                      onConfirm: () async {
                        final updatedList = policy.approvalChain
                            .where((s) => s.order != stage.order)
                            .toList();
                        // Re-index
                        final reindexed = List.generate(
                          updatedList.length,
                          (i) => updatedList[i].copyWith(order: i),
                        );
                        final updated =
                            policy.copyWith(approvalChain: reindexed);
                        await _savePolicy(
                          finProv,
                          updated,
                          'Approval stage deleted',
                        );
                      },
                    );
                  },
                  icon: Icon(Icons.delete_outline,
                      size: 16.sp, color: FinDT.danger),
                  tooltip: 'Delete Stage',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleStepApprovalConfig(
    FinanceProvider finProv,
    UserManagementProvider userMgmt,
    FinancePolicyEntity policy,
    NumberFormat formatter,
  ) {
    return Column(
      children: [
        _buildPermissionConfigCard(
          title: 'General Expense Approvers',
          description:
              'Roles and specific users authorized to review, approve, and authorize payments for claims within their configured financial limits.',
          icon: Icons.fact_check_outlined,
          color: const Color(0xFF16A34A),
          config: policy.expenseApproval,
          allRoles: userMgmt.roles,
          allUsers: userMgmt.users,
          onSave: (newConfig) async {
            final updated = policy.copyWith(expenseApproval: newConfig);
            await _savePolicy(
                finProv, updated, 'Expense approvers updated');
          },
        ),
        SizedBox(height: 12.h),

        // Role Limits Summary Card
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: FinDT.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.payments_outlined,
                          size: 18.sp, color: FinDT.brand),
                      SizedBox(width: 8.w),
                      Text(
                        'Role Approval Amount Thresholds',
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: FinDT.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        _showEditRoleLimitsDialog(context, finProv, policy),
                    icon: Icon(Icons.edit_outlined, size: 14.sp),
                    label: Text(
                      'Edit Limits',
                      style: GoogleFonts.inter(
                          fontSize: 11.sp, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Wrap(
                spacing: 10.w,
                runSpacing: 8.h,
                children: policy.approvalLimits.entries.map((entry) {
                  final isUnlimited = entry.value >= 99999999;
                  final isZero = entry.value <= 0;
                  return Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 12.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: FinDT.bgPage,
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: FinDT.borderLight),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          entry.key.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            color: FinDT.textPrimary,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          isUnlimited
                              ? 'Unlimited'
                              : isZero
                                  ? '0 SAR'
                                  : '${formatter.format(entry.value)} SAR',
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: isUnlimited
                                ? FinDT.brand
                                : isZero
                                    ? FinDT.textMuted
                                    : FinDT.success,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // 3. FUND OPERATIONS & ACCOUNTS SECTION
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildFundOperationsSection(
    FinanceProvider finProv,
    UserManagementProvider userMgmt,
    FinancePolicyEntity policy,
  ) {
    return Column(
      key: const ValueKey('fund_operations_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPermissionConfigCard(
          title: 'Fund Movements (Deposit / Withdraw / Adjust)',
          description:
              'Authorized to perform cash top-ups, cash withdrawals, and audit adjustments on active virtual accounts. Note: Account coordinators always have movement access on their own accounts.',
          icon: Icons.account_balance_wallet_outlined,
          color: const Color(0xFF16A34A),
          config: policy.fundMovement,
          allRoles: userMgmt.roles,
          allUsers: userMgmt.users,
          onSave: (newConfig) async {
            final updated = policy.copyWith(fundMovement: newConfig);
            await _savePolicy(finProv, updated, 'Fund movement permission updated');
          },
        ),
        SizedBox(height: 12.h),

        _buildPermissionConfigCard(
          title: 'Fund Transfers Between Accounts',
          description:
              'Authorized to transfer balances between bank accounts, petty cash drawers, STC wallets, and custom accounts with atomic ledger verification.',
          icon: Icons.swap_horiz_rounded,
          color: const Color(0xFF0284C7),
          config: policy.fundTransfer,
          allRoles: userMgmt.roles,
          allUsers: userMgmt.users,
          onSave: (newConfig) async {
            final updated = policy.copyWith(fundTransfer: newConfig);
            await _savePolicy(finProv, updated, 'Fund transfer permission updated');
          },
        ),
        SizedBox(height: 12.h),

        _buildPermissionConfigCard(
          title: 'Account Management (Create / Edit / Archive)',
          description:
              'Authorized to provision new virtual fund accounts, change assigned coordinators, rename accounts, and manage active status.',
          icon: Icons.settings_suggest_outlined,
          color: const Color(0xFFD97706),
          config: policy.accountManagement,
          allRoles: userMgmt.roles,
          allUsers: userMgmt.users,
          onSave: (newConfig) async {
            final updated = policy.copyWith(accountManagement: newConfig);
            await _savePolicy(
                finProv, updated, 'Account management permission updated');
          },
        ),
        SizedBox(height: 12.h),

        _buildPermissionConfigCard(
          title: 'Master Data Management',
          description:
              'Authorized to create/edit Expense Categories, Account Types, and modify corporate Finance Policies.',
          icon: Icons.dns_outlined,
          color: const Color(0xFFDC2626),
          config: policy.masterDataManagement,
          allRoles: userMgmt.roles,
          allUsers: userMgmt.users,
          onSave: (newConfig) async {
            final updated = policy.copyWith(masterDataManagement: newConfig);
            await _savePolicy(
                finProv, updated, 'Master data permission updated');
          },
        ),
        SizedBox(height: 12.h),

        _buildPermissionConfigCard(
          title: 'Cash Advance Management',
          description:
              'Authorized to issue cash advances to drivers and coordinators and record subsequent settlement deductions.',
          icon: Icons.payments_outlined,
          color: const Color(0xFF7C3AED),
          config: policy.cashAdvanceManagement,
          allRoles: userMgmt.roles,
          allUsers: userMgmt.users,
          onSave: (newConfig) async {
            final updated = policy.copyWith(cashAdvanceManagement: newConfig);
            await _savePolicy(
                finProv, updated, 'Cash advance permission updated');
          },
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // 4. COMPLIANCE & SAFETY SUMMARY SECTION
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildComplianceSummarySection(
    FinanceProvider finProv,
    FinancePolicyEntity policy,
  ) {
    final formatter = NumberFormat('#,##0.00', 'en_US');

    return Container(
      key: const ValueKey('compliance_summary_section'),
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: FinDT.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.shield_outlined,
                      size: 20.sp, color: FinDT.brand),
                  SizedBox(width: 8.w),
                  Text(
                    'Corporate Compliance & Safety Controls',
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: FinDT.textPrimary,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () =>
                    _showComplianceSettingsDialog(context, finProv, policy),
                icon: Icon(Icons.edit_outlined, size: 14.sp),
                label: Text(
                  'Edit Rules',
                  style: GoogleFonts.inter(
                      fontSize: 11.sp, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FinDT.brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          _buildRuleTile(
            title: 'Receipt Attachment Requirement',
            subtitle:
                'Mandatory for all expense submissions at or above ${formatter.format(policy.receiptRequiredAbove)} SAR',
            isActive: true,
          ),
          SizedBox(height: 10.h),

          _buildRuleTile(
            title: 'Vehicle Tagging on Fuel Expenses',
            subtitle:
                'Fuel expense entries strictly require selecting a registered fleet vehicle',
            isActive: policy.requireVehicleForFuel,
          ),
          SizedBox(height: 10.h),

          _buildRuleTile(
            title: 'Employee Tagging on Payroll Expenses',
            subtitle:
                'Salary and wage payments strictly require selecting an active employee profile',
            isActive: policy.requireEmployeeForSalary,
          ),
          SizedBox(height: 10.h),

          _buildRuleTile(
            title: 'Block Self-Approval on Expense Claims',
            subtitle:
                'Users are strictly blocked from approving their own submitted expense claims',
            isActive: policy.blockSelfApprove,
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // REUSABLE WORKFLOW PERMISSION CARD
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildPermissionConfigCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required WorkflowPermissionConfig config,
    required List<RoleEntity> allRoles,
    required List<ManagedUserEntity> allUsers,
    required Future<void> Function(WorkflowPermissionConfig newConfig) onSave,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: FinDT.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(icon, size: 20.sp, color: color),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: FinDT.textPrimary,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      description,
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        color: FinDT.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              OutlinedButton.icon(
                onPressed: () => _showPermissionEditorDialog(
                  context: context,
                  title: title,
                  config: config,
                  allRoles: allRoles,
                  allUsers: allUsers,
                  onSave: onSave,
                ),
                icon: Icon(Icons.edit_outlined, size: 14.sp),
                label: Text(
                  'Configure',
                  style: GoogleFonts.inter(
                      fontSize: 11.sp, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: FinDT.brand,
                  side: BorderSide(color: FinDT.brand.withValues(alpha: 0.4)),
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),

          // Active Configurations Chips
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: FinDT.bgPage,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6.w,
              runSpacing: 6.h,
              children: [
                Text(
                  'Authorized Access:',
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: FinDT.textSecondary,
                  ),
                ),
                if (config.allowedRoles.isEmpty &&
                    config.allowedUserIds.isEmpty)
                  Text(
                    'Admins Only (Default fallback)',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: FinDT.textMuted,
                    ),
                  ),
                ...config.allowedRoles.map((r) => _buildRoleChip(r)),
                ...config.allowedUserNames.map((u) => _buildUserChip(u)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChip(String roleId) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: FinDT.brand.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: FinDT.brand.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, size: 11.sp, color: FinDT.brand),
          SizedBox(width: 4.w),
          Text(
            roleId.replaceAll('_', ' ').toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              color: FinDT.brand,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserChip(String userName) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: const Color(0xFF16A34A).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6.r),
        border:
            Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_outline_rounded,
              size: 11.sp, color: const Color(0xFF16A34A)),
          SizedBox(width: 4.w),
          Text(
            userName,
            style: GoogleFonts.inter(
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF16A34A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: FinDT.brand.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: FinDT.brand.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18.sp, color: FinDT.brand),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: FinDT.brand,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    color: FinDT.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleTile({
    required String title,
    required String subtitle,
    required bool isActive,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: FinDT.bgPage,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 16.sp,
            color: isActive ? FinDT.success : FinDT.danger,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: FinDT.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    color: FinDT.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // DIALOGS & EDITORS
  // ═════════════════════════════════════════════════════════════════════════════

  void _showPermissionEditorDialog({
    required BuildContext context,
    required String title,
    required WorkflowPermissionConfig config,
    required List<RoleEntity> allRoles,
    required List<ManagedUserEntity> allUsers,
    required Future<void> Function(WorkflowPermissionConfig newConfig) onSave,
  }) {
    final selectedRoles = List<String>.from(config.allowedRoles);
    final selectedUserIds = List<String>.from(config.allowedUserIds);
    final selectedUserNames = List<String>.from(config.allowedUserNames);
    bool isSaving = false;

    // Build role list including standard roles
    final standardRoleIds = [
      'admin',
      'super_admin',
      'coordinator',
      'manager',
      'finance',
      'driver',
      'office_staff',
    ];
    final allRoleOptions = <String>{
      ...standardRoleIds,
      ...allRoles.map((r) => r.id),
    }.toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: finDialogShape,
          title: finDialogTitle('Configure: $title',
              icon: Icons.manage_accounts_outlined),
          content: SizedBox(
            width: 520.w,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: FinDT.brand.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 16.sp, color: FinDT.brand),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Admins & SuperAdmins always have full bypass permissions. Select authorized system roles, assign specific individuals, or combine both.',
                            style: GoogleFonts.inter(
                                fontSize: 11.sp, color: FinDT.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Option 1: Role Multi-Select
                  Text(
                    'Option A: Assign by System Roles',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: FinDT.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Wrap(
                    spacing: 6.w,
                    runSpacing: 6.h,
                    children: allRoleOptions.map((roleId) {
                      final isSelected = selectedRoles.contains(roleId);
                      return FilterChip(
                        selected: isSelected,
                        label: Text(roleId.replaceAll('_', ' ').toUpperCase()),
                        labelStyle: GoogleFonts.inter(
                          fontSize: 11.sp,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? FinDT.brand : FinDT.textPrimary,
                        ),
                        selectedColor: FinDT.brand.withValues(alpha: 0.12),
                        checkmarkColor: FinDT.brand,
                        backgroundColor: FinDT.bgPage,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          side: BorderSide(
                            color: isSelected
                                ? FinDT.brand
                                : FinDT.border,
                          ),
                        ),
                        onSelected: isSaving ? null : (val) {
                          setDialogState(() {
                            if (val) {
                              selectedRoles.add(roleId);
                            } else {
                              selectedRoles.remove(roleId);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 20.h),
                  const Divider(),
                  SizedBox(height: 10.h),

                  // Option 2: Specific Users Picker
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Option B: Assign Specific Users (${selectedUserIds.length})',
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: FinDT.textPrimary,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: isSaving ? null : () => _openUserSearchPickerDialog(
                          ctx: ctx,
                          allUsers: allUsers,
                          alreadySelectedIds: selectedUserIds,
                          onUserSelected: (user) {
                            setDialogState(() {
                              if (!selectedUserIds.contains(user.uid)) {
                                selectedUserIds.add(user.uid);
                                selectedUserNames.add(user.displayName.isNotEmpty
                                    ? user.displayName
                                    : user.email);
                              }
                            });
                          },
                        ),
                        icon: Icon(Icons.person_add_alt_1_outlined, size: 14.sp),
                        label: Text(
                          'Pick User',
                          style: GoogleFonts.inter(
                              fontSize: 11.sp, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),

                  if (selectedUserIds.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: FinDT.bgPage,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        'No specific individual users assigned. (Role-based access will apply)',
                        style: GoogleFonts.inter(
                            fontSize: 11.sp, color: FinDT.textSecondary),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 6.w,
                      runSpacing: 6.h,
                      children: List.generate(selectedUserIds.length, (i) {
                        final uId = selectedUserIds[i];
                        final uName = selectedUserNames.length > i
                            ? selectedUserNames[i]
                            : uId;
                        return Chip(
                          avatar: Icon(Icons.person_rounded,
                              size: 14.sp, color: const Color(0xFF16A34A)),
                          label: Text(uName),
                          labelStyle: GoogleFonts.inter(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: FinDT.textPrimary,
                          ),
                          backgroundColor: const Color(0xFF16A34A)
                              .withValues(alpha: 0.1),
                          deleteIcon:
                              Icon(Icons.close_rounded, size: 14.sp),
                          onDeleted: isSaving ? null : () {
                            setDialogState(() {
                              selectedUserIds.removeAt(i);
                              if (selectedUserNames.length > i) {
                                selectedUserNames.removeAt(i);
                              }
                            });
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                            side: BorderSide(
                              color: const Color(0xFF16A34A)
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                        );
                      }),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            finDialogCancelButton(
              ctx,
              onPressed: isSaving ? () {} : null,
            ),
            finDialogActionButton(
              onPressed: () async {
                setDialogState(() => isSaving = true);
                final updatedConfig = WorkflowPermissionConfig(
                  allowedRoles: selectedRoles,
                  allowedUserIds: selectedUserIds,
                  allowedUserNames: selectedUserNames,
                );
                try {
                  await onSave(updatedConfig);
                  if (ctx.mounted) finSafePop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    setDialogState(() => isSaving = false);
                  }
                }
              },
              label: 'Save Permission',
              backgroundColor: FinDT.brand,
              isLoading: isSaving,
            ),
          ],
        ),
      ),
    );
  }

  void _openUserSearchPickerDialog({
    required BuildContext ctx,
    required List<ManagedUserEntity> allUsers,
    required List<String> alreadySelectedIds,
    required ValueChanged<ManagedUserEntity> onUserSelected,
  }) {
    String searchQuery = '';

    showDialog(
      context: ctx,
      builder: (pickerCtx) => StatefulBuilder(
        builder: (pickerCtx, setPickerState) {
          final filtered = allUsers.where((u) {
            if (alreadySelectedIds.contains(u.uid)) return false;
            if (searchQuery.isEmpty) return true;
            final q = searchQuery.toLowerCase();
            return u.displayName.toLowerCase().contains(q) ||
                u.email.toLowerCase().contains(q) ||
                u.roleName.toLowerCase().contains(q);
          }).toList();

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: finDialogShape,
            title: finDialogTitle('Select User from Directory',
                icon: Icons.person_search_outlined),
            content: SizedBox(
              width: 440.w,
              height: 380.h,
              child: Column(
                children: [
                  TextField(
                    autofocus: true,
                    decoration: finDialogInputDecoration(
                      label: 'Search Directory',
                      hint: 'Search by name, email, or role...',
                      prefixIcon: Icons.search,
                    ),
                    style: GoogleFonts.inter(fontSize: 12.sp),
                    onChanged: (v) => setPickerState(() => searchQuery = v),
                  ),
                  SizedBox(height: 12.h),
                  Expanded(
                    child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            allUsers.isEmpty
                                ? 'No users loaded in directory'
                                : 'No matching users found',
                            style: GoogleFonts.inter(
                                fontSize: 12.sp,
                                color: FinDT.textSecondary),
                          ),
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: FinDT.borderLight),
                          itemBuilder: (_, idx) {
                            final user = filtered[idx];
                            return ListTile(
                              leading: CircleAvatar(
                                radius: 16.r,
                                backgroundColor:
                                    FinDT.brand.withValues(alpha: 0.1),
                                child: Text(
                                  user.displayName.isNotEmpty
                                      ? user.displayName[0].toUpperCase()
                                      : 'U',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w700,
                                    color: FinDT.brand,
                                  ),
                                ),
                              ),
                              title: Text(
                                user.displayName.isNotEmpty
                                    ? user.displayName
                                    : user.email,
                                style: GoogleFonts.inter(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: FinDT.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                '${user.roleName} • ${user.email}',
                                style: GoogleFonts.inter(
                                  fontSize: 10.sp,
                                  color: FinDT.textSecondary,
                                ),
                              ),
                              onTap: () {
                                onUserSelected(user);
                                finSafePop(pickerCtx);
                              },
                            );
                          },
                        ),
                  ),
                ],
              ),
            ),
            actions: [
              finDialogCancelButton(pickerCtx),
            ],
          );
        },
      ),
    );
  }

  void _showAddOrEditStageDialog(
    BuildContext context,
    FinanceProvider finProv,
    FinancePolicyEntity policy,
    UserManagementProvider userMgmt,
    ApprovalStageEntity? existingStage,
    int targetIndex,
  ) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(
        text: existingStage?.name ?? 'Stage ${targetIndex + 1}: Approval Review');
    final amountCtrl = TextEditingController(
        text: existingStage?.maxAmount?.toString() ?? '');
    bool isUnlimited = existingStage?.maxAmount == null;
    bool isSaving = false;

    final selectedRoles = List<String>.from(existingStage?.approverRoles ?? []);
    final selectedUserIds =
        List<String>.from(existingStage?.approverUserIds ?? []);
    final selectedUserNames =
        List<String>.from(existingStage?.approverUserNames ?? []);

    final allRoleOptions = <String>{
      'admin',
      'super_admin',
      'coordinator',
      'manager',
      'finance',
      'driver',
      'office_staff',
      ...userMgmt.roles.map((r) => r.id),
    }.toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: finDialogShape,
          title: finDialogTitle(
            existingStage == null
                ? 'Add Approval Stage'
                : 'Edit Approval Stage',
            icon: Icons.account_tree_outlined,
          ),
          content: SizedBox(
            width: 480.w,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: finDialogInputDecoration(
                        label: 'Stage Name *',
                        hint: 'e.g. Stage 1: Operational Review',
                        prefixIcon: Icons.label_outline,
                      ),
                      style: GoogleFonts.inter(fontSize: 12.sp),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    SizedBox(height: 14.h),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: amountCtrl,
                            enabled: !isUnlimited,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d*')),
                            ],
                            decoration: finDialogInputDecoration(
                              label: 'Max Amount (SAR) *',
                              hint: isUnlimited ? 'Unlimited' : 'e.g. 5000',
                              prefixIcon: Icons.payments_outlined,
                            ),
                            style: GoogleFonts.inter(fontSize: 12.sp),
                            validator: (v) {
                              if (isUnlimited) return null;
                              if (v == null || v.trim().isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(width: 12.w),
                        FilterChip(
                          selected: isUnlimited,
                          label: const Text('Unlimited SAR'),
                          labelStyle: GoogleFonts.inter(
                            fontSize: 11.sp,
                            fontWeight: isUnlimited
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isUnlimited
                                ? FinDT.brand
                                : FinDT.textPrimary,
                          ),
                          selectedColor: FinDT.brand.withValues(alpha: 0.12),
                          onSelected: isSaving ? null : (val) {
                            setDialogState(() {
                              isUnlimited = val;
                              if (isUnlimited) amountCtrl.clear();
                            });
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    const Divider(),
                    SizedBox(height: 8.h),

                    // Approver Roles
                    Text(
                      'Authorized Roles for this Stage',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: FinDT.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Wrap(
                      spacing: 6.w,
                      runSpacing: 6.h,
                      children: allRoleOptions.map((r) {
                        final isSel = selectedRoles.contains(r);
                        return FilterChip(
                          selected: isSel,
                          label: Text(r.replaceAll('_', ' ').toUpperCase()),
                          labelStyle: GoogleFonts.inter(
                            fontSize: 10.sp,
                            fontWeight:
                                isSel ? FontWeight.w700 : FontWeight.w500,
                            color: isSel ? FinDT.brand : FinDT.textPrimary,
                          ),
                          selectedColor: FinDT.brand.withValues(alpha: 0.12),
                          onSelected: isSaving ? null : (v) {
                            setDialogState(() {
                              if (v) {
                                selectedRoles.add(r);
                              } else {
                                selectedRoles.remove(r);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 14.h),

                    // Approver Users
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Specific User Approvers (${selectedUserIds.length})',
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: FinDT.textPrimary,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: isSaving ? null : () => _openUserSearchPickerDialog(
                            ctx: ctx,
                            allUsers: userMgmt.users,
                            alreadySelectedIds: selectedUserIds,
                            onUserSelected: (u) {
                              setDialogState(() {
                                selectedUserIds.add(u.uid);
                                selectedUserNames.add(u.displayName.isNotEmpty
                                    ? u.displayName
                                    : u.email);
                              });
                            },
                          ),
                          icon: Icon(Icons.add, size: 14.sp),
                          label: const Text('Add User'),
                        ),
                      ],
                    ),
                    if (selectedUserNames.isNotEmpty)
                      Wrap(
                        spacing: 6.w,
                        runSpacing: 6.h,
                        children: List.generate(selectedUserNames.length, (i) {
                          return Chip(
                            label: Text(selectedUserNames[i]),
                            labelStyle: GoogleFonts.inter(fontSize: 10.sp),
                            onDeleted: isSaving ? null : () {
                              setDialogState(() {
                                selectedUserIds.removeAt(i);
                                selectedUserNames.removeAt(i);
                              });
                            },
                          );
                        }),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            finDialogCancelButton(
              ctx,
              onPressed: isSaving ? () {} : null,
            ),
            finDialogActionButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                
                final maxAmt = isUnlimited
                    ? null
                    : double.tryParse(amountCtrl.text.trim());

                final stage = ApprovalStageEntity(
                  name: nameCtrl.text.trim(),
                  order: existingStage?.order ?? targetIndex,
                  maxAmount: maxAmt,
                  approverRoles: selectedRoles,
                  approverUserIds: selectedUserIds,
                  approverUserNames: selectedUserNames,
                );

                List<ApprovalStageEntity> updatedChain =
                    List.from(policy.approvalChain);
                if (existingStage != null) {
                  final idx = updatedChain
                      .indexWhere((s) => s.order == existingStage.order);
                  if (idx != -1) {
                    updatedChain[idx] = stage;
                  }
                } else {
                  updatedChain.add(stage);
                }

                final updatedPolicy =
                    policy.copyWith(approvalChain: updatedChain);
                
                setDialogState(() => isSaving = true);
                try {
                  await _savePolicy(
                    finProv,
                    updatedPolicy,
                    existingStage == null
                        ? 'Approval stage added'
                        : 'Approval stage updated',
                  );
                  if (ctx.mounted) finSafePop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    setDialogState(() => isSaving = false);
                  }
                }
              },
              label: 'Save Stage',
              backgroundColor: FinDT.brand,
              isLoading: isSaving,
            ),
          ],
        ),
      ),
    );
  }

  void _showEditRoleLimitsDialog(
    BuildContext context,
    FinanceProvider finProv,
    FinancePolicyEntity policy,
  ) {
    final formKey = GlobalKey<FormState>();
    final managerCtrl = TextEditingController(
        text: policy.limitForRole('manager')?.toString() ?? '5000');
    final financeCtrl = TextEditingController(
        text: policy.limitForRole('finance')?.toString() ?? '50000');
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: finDialogShape,
          title: finDialogTitle('Edit Role Approval Limits',
              icon: Icons.payments_outlined),
          content: SizedBox(
            width: 420.w,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: managerCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: finDialogInputDecoration(
                      label: 'Manager Approval Limit (SAR) *',
                      prefixIcon: Icons.payments_outlined,
                    ),
                    style: GoogleFonts.inter(fontSize: 12.sp),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  SizedBox(height: 12.h),
                  TextFormField(
                    controller: financeCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: finDialogInputDecoration(
                      label: 'Finance Role Approval Limit (SAR) *',
                      prefixIcon: Icons.account_balance_outlined,
                    ),
                    style: GoogleFonts.inter(fontSize: 12.sp),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            finDialogCancelButton(
              ctx,
              onPressed: isSaving ? () {} : null,
            ),
            finDialogActionButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                
                final updated = policy.copyWith(
                  approvalLimits: {
                    ...policy.approvalLimits,
                    'manager': double.tryParse(managerCtrl.text) ?? 5000,
                    'finance': double.tryParse(financeCtrl.text) ?? 50000,
                  },
                );
                
                setDialogState(() => isSaving = true);
                try {
                  await _savePolicy(finProv, updated, 'Approval limits updated');
                  if (ctx.mounted) finSafePop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    setDialogState(() => isSaving = false);
                  }
                }
              },
              label: 'Save Limits',
              backgroundColor: FinDT.brand,
              isLoading: isSaving,
            ),
          ],
        ),
      ),
    );
  }

  void _showComplianceSettingsDialog(
    BuildContext context,
    FinanceProvider finProv,
    FinancePolicyEntity policy,
  ) {
    final formKey = GlobalKey<FormState>();
    final receiptCtrl =
        TextEditingController(text: policy.receiptRequiredAbove.toString());
    bool requireFuel = policy.requireVehicleForFuel;
    bool requireSalary = policy.requireEmployeeForSalary;
    bool blockSelf = policy.blockSelfApprove;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: finDialogShape,
          title: finDialogTitle('Compliance & Integrity Settings',
              icon: Icons.shield_outlined),
          content: SizedBox(
            width: 440.w,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: receiptCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*')),
                      ],
                      decoration: finDialogInputDecoration(
                        label: 'Receipt Mandatory Above (SAR) *',
                        prefixIcon: Icons.receipt_long_outlined,
                      ),
                      style: GoogleFonts.inter(fontSize: 12.sp),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    SizedBox(height: 14.h),
                    const Divider(),
                    SwitchListTile(
                      title: Text('Require Vehicle Tagging on Fuel',
                          style: GoogleFonts.inter(
                              fontSize: 12.sp, fontWeight: FontWeight.w600)),
                      contentPadding: EdgeInsets.zero,
                      value: requireFuel,
                      activeTrackColor: FinDT.brand,
                      onChanged: isSaving ? null : (v) => setDialogState(() => requireFuel = v),
                    ),
                    SwitchListTile(
                      title: Text('Require Employee Tagging on Payroll',
                          style: GoogleFonts.inter(
                              fontSize: 12.sp, fontWeight: FontWeight.w600)),
                      contentPadding: EdgeInsets.zero,
                      value: requireSalary,
                      activeTrackColor: FinDT.brand,
                      onChanged: isSaving ? null : (v) => setDialogState(() => requireSalary = v),
                    ),
                    SwitchListTile(
                      title: Text('Block Self-Approval on Expenses',
                          style: GoogleFonts.inter(
                              fontSize: 12.sp, fontWeight: FontWeight.w600)),
                      contentPadding: EdgeInsets.zero,
                      value: blockSelf,
                      activeTrackColor: FinDT.brand,
                      onChanged: (v) => setDialogState(() => blockSelf = v),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            finDialogCancelButton(
              ctx,
              onPressed: isSaving ? () {} : null,
            ),
            finDialogActionButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final updated = policy.copyWith(
                  receiptRequiredAbove:
                      double.tryParse(receiptCtrl.text) ?? 100,
                  requireVehicleForFuel: requireFuel,
                  requireEmployeeForSalary: requireSalary,
                  blockSelfApprove: blockSelf,
                );

                setDialogState(() => isSaving = true);
                try {
                  await _savePolicy(
                      finProv, updated, 'Compliance rules updated');
                  if (ctx.mounted) finSafePop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    setDialogState(() => isSaving = false);
                  }
                }
              },
              label: 'Save Settings',
              backgroundColor: FinDT.brand,
              isLoading: isSaving,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmResetDefaults(
    BuildContext context,
    FinanceProvider finProv,
  ) async {
    await showFinConfirmationDialog(
      context: context,
      title: 'Reset Finance Policy to Defaults?',
      message:
          'This will reset all workflow permissions, approval stages, and limits to standard company defaults.',
      confirmLabel: 'Reset to Defaults',
      confirmColor: FinDT.danger,
      onConfirm: () async {
        const defaultPolicy = FinancePolicyEntity();
        await _savePolicy(
            finProv, defaultPolicy, 'Policy reset to standard defaults');
      },
    );
  }

  Future<void> _savePolicy(
    FinanceProvider finProv,
    FinancePolicyEntity updatedPolicy,
    String successMessage,
  ) async {
    try {
      await finProv.saveFinancePolicy(updatedPolicy);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: FinDT.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save policy: $e'),
            backgroundColor: FinDT.danger,
          ),
        );
      }
    }
  }
}

class _PolicyCategoryItem {
  final String title;
  final IconData icon;
  final String subtitle;

  const _PolicyCategoryItem({
    required this.title,
    required this.icon,
    required this.subtitle,
  });
}
