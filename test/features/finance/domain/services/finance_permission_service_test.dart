import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/features/auth/domain/entities/user_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/approval_stage_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/finance_policy_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/fund_account_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/workflow_permission_config.dart';
import 'package:xloop_invoice/features/finance/domain/services/finance_permission_service.dart';

void main() {
  group('FinancePermissionService Tests', () {
    const adminUser = UserEntity(
      id: 'admin_1',
      roleId: 'admin',
      displayName: 'Admin User',
    );

    const coordinatorUser = UserEntity(
      id: 'coord_1',
      roleId: 'coordinator',
      displayName: 'Coordinator John',
    );

    const otherCoordinatorUser = UserEntity(
      id: 'coord_2',
      roleId: 'coordinator',
      displayName: 'Coordinator Jane',
    );

    const managerUser = UserEntity(
      id: 'mgr_1',
      roleId: 'manager',
      displayName: 'Manager Alex',
    );

    const customPersonUser = UserEntity(
      id: 'special_user_100',
      roleId: 'office_staff',
      displayName: 'Special Auditor',
    );

    final pettyAccount = FundAccountEntity(
      id: 'pc_riyadh',
      name: 'Riyadh Petty Cash',
      code: 'PC001',
      type: FundAccountType.pettyCash,
      currency: 'SAR',
      assignedToId: 'coord_1',
      assignedTo: 'Coordinator John',
      createdAt: DateTime(2026, 1, 1),
    );

    test('canOpenSession respects assigned coordinator and admin bypass', () {
      const policy = FinancePolicyEntity(
        sessionOpen: WorkflowPermissionConfig(
          allowedRoles: ['admin', 'super_admin'],
        ),
      );

      // Admin always can
      expect(
        FinancePermissionService.canOpenSession(
          user: adminUser,
          account: pettyAccount,
          policy: policy,
        ),
        isTrue,
      );

      // Assigned coordinator for this account can open
      expect(
        FinancePermissionService.canOpenSession(
          user: coordinatorUser,
          account: pettyAccount,
          policy: policy,
        ),
        isTrue,
      );

      // Non-assigned coordinator denied when not in allowedRoles
      expect(
        FinancePermissionService.canOpenSession(
          user: otherCoordinatorUser,
          account: pettyAccount,
          policy: policy,
        ),
        isFalse,
      );
    });

    test('canOpenSession respects specific user assignment overrides', () {
      const policy = FinancePolicyEntity(
        sessionOpen: WorkflowPermissionConfig(
          allowedRoles: [],
          allowedUserIds: ['special_user_100'],
        ),
      );

      expect(
        FinancePermissionService.canOpenSession(
          user: customPersonUser,
          account: pettyAccount,
          policy: policy,
        ),
        isTrue,
      );
    });

    test('canVerifySession enforces verify permissions', () {
      const policy = FinancePolicyEntity(
        sessionVerify: WorkflowPermissionConfig(
          allowedRoles: ['admin', 'super_admin', 'manager'],
        ),
      );

      expect(
        FinancePermissionService.canVerifySession(
          user: adminUser,
          policy: policy,
        ),
        isTrue,
      );

      expect(
        FinancePermissionService.canVerifySession(
          user: managerUser,
          policy: policy,
        ),
        isTrue,
      );

      expect(
        FinancePermissionService.canVerifySession(
          user: coordinatorUser,
          policy: policy,
        ),
        isFalse,
      );
    });

    test('canApproveExpense with single-step role limits', () {
      const policy = FinancePolicyEntity(
        expenseApproval: WorkflowPermissionConfig(
          allowedRoles: ['manager', 'finance', 'admin'],
        ),
        approvalLimits: {
          'manager': 5000,
          'finance': 50000,
          'admin': 999999999,
        },
      );

      // Manager approving 3000 SAR -> allowed
      expect(
        FinancePermissionService.canApproveExpense(
          user: managerUser,
          policy: policy,
          amount: 3000,
        ),
        isTrue,
      );

      // Manager approving 8000 SAR -> denied (exceeds limit 5000)
      expect(
        FinancePermissionService.canApproveExpense(
          user: managerUser,
          policy: policy,
          amount: 8000,
        ),
        isFalse,
      );

      // Coordinator (not in approval roles) -> denied
      expect(
        FinancePermissionService.canApproveExpense(
          user: coordinatorUser,
          policy: policy,
          amount: 50,
        ),
        isFalse,
      );

      // Admin always allowed unlimited
      expect(
        FinancePermissionService.canApproveExpense(
          user: adminUser,
          policy: policy,
          amount: 500000,
        ),
        isTrue,
      );
    });

    test('canApproveExpense with Multi-Level Approval Chain', () {
      const policy = FinancePolicyEntity(
        multiLevelApprovalEnabled: true,
        expenseApproval: WorkflowPermissionConfig(
          allowedRoles: ['coordinator', 'manager', 'finance', 'admin', 'super_admin'],
        ),
        approvalChain: [
          ApprovalStageEntity(
            name: 'Stage 1: Coordinator Review',
            order: 0,
            maxAmount: 1000,
            approverRoles: ['coordinator'],
          ),
          ApprovalStageEntity(
            name: 'Stage 2: Manager Sign-off',
            order: 1,
            maxAmount: 10000,
            approverRoles: ['manager'],
          ),
          ApprovalStageEntity(
            name: 'Stage 3: Executive Approval',
            order: 2,
            maxAmount: null, // Unlimited
            approverRoles: ['admin'],
          ),
        ],
      );

      // Coordinator approving 500 SAR (Stage 1 max is 1000) -> allowed
      expect(
        FinancePermissionService.canApproveExpense(
          user: coordinatorUser,
          policy: policy,
          amount: 500,
        ),
        isTrue,
      );

      // Coordinator approving 2500 SAR (Stage 1 is max 1000) -> denied
      expect(
        FinancePermissionService.canApproveExpense(
          user: coordinatorUser,
          policy: policy,
          amount: 2500,
        ),
        isFalse,
      );

      // Manager approving 2500 SAR (Stage 2 max is 10000) -> allowed
      expect(
        FinancePermissionService.canApproveExpense(
          user: managerUser,
          policy: policy,
          amount: 2500,
        ),
        isTrue,
      );
    });

    test('canVoidExpense enforces void permissions', () {
      const policy = FinancePolicyEntity(
        expenseVoid: WorkflowPermissionConfig(
          allowedRoles: ['admin', 'finance'],
          allowedUserIds: ['special_user_100'],
        ),
      );

      expect(
        FinancePermissionService.canVoidExpense(
          user: adminUser,
          policy: policy,
        ),
        isTrue,
      );

      expect(
        FinancePermissionService.canVoidExpense(
          user: customPersonUser,
          policy: policy,
        ),
        isTrue,
      );

      expect(
        FinancePermissionService.canVoidExpense(
          user: coordinatorUser,
          policy: policy,
        ),
        isFalse,
      );
    });

    test('canSeeAccount shows admins everything, others only their own', () {
      final nameOnlyAccount = FundAccountEntity(
        id: 'pc_jeddah',
        name: 'Jeddah Petty Cash',
        code: 'PC002',
        type: FundAccountType.pettyCash,
        currency: 'SAR',
        assignedTo: 'Driver Sami',
        createdAt: DateTime(2026, 1, 1),
      );
      final unassignedAccount = FundAccountEntity(
        id: 'bank_main',
        name: 'Main Bank',
        code: 'BK001',
        type: FundAccountType.bank,
        currency: 'SAR',
        createdAt: DateTime(2026, 1, 1),
      );

      const superAdmin = UserEntity(id: 'sa_1', roleId: 'super_admin');
      for (final account in [pettyAccount, nameOnlyAccount, unassignedAccount]) {
        expect(
          FinancePermissionService.canSeeAccount(user: adminUser, account: account),
          isTrue,
        );
        expect(
          FinancePermissionService.canSeeAccount(user: superAdmin, account: account),
          isTrue,
        );
      }

      // Assigned by id
      expect(
        FinancePermissionService.canSeeAccount(user: coordinatorUser, account: pettyAccount),
        isTrue,
      );
      expect(
        FinancePermissionService.canSeeAccount(
          user: otherCoordinatorUser,
          account: pettyAccount,
        ),
        isFalse,
      );

      // Assigned by the linked employee's name, ignoring case
      const linkedUser = UserEntity(
        id: 'drv_1',
        roleId: 'driver',
        displayName: 'sami@xloop',
        employeeId: 'emp_9',
      );
      expect(
        FinancePermissionService.canSeeAccount(user: linkedUser, account: nameOnlyAccount),
        isFalse,
      );
      expect(
        FinancePermissionService.canSeeAccount(
          user: linkedUser,
          account: nameOnlyAccount,
          employeeName: 'driver sami ',
        ),
        isTrue,
      );

      // Nobody but admins sees an unassigned account
      expect(
        FinancePermissionService.canSeeAccount(user: managerUser, account: unassignedAccount),
        isFalse,
      );
      expect(
        FinancePermissionService.canSeeAccount(user: null, account: pettyAccount),
        isFalse,
      );
    });
  });

  group('Two-step salary permissions', () {
    const admin = UserEntity(id: 'a1', roleId: 'admin', displayName: 'Admin');
    const finance =
        UserEntity(id: 'f1', roleId: 'finance', displayName: 'Finance Fay');
    const coordinator =
        UserEntity(id: 'c1', roleId: 'coordinator', displayName: 'Coord Cal');
    const driver =
        UserEntity(id: 'd1', roleId: 'driver', displayName: 'Driver Dan');

    test('defaults: finance finalizes, the coordinator pays', () {
      const policy = FinancePolicyEntity();

      expect(
        FinancePermissionService.canFinalizeSalaries(
            user: finance, policy: policy),
        isTrue,
      );
      expect(
        FinancePermissionService.canPaySalaries(user: finance, policy: policy),
        isFalse,
      );
      expect(
        FinancePermissionService.canFinalizeSalaries(
            user: coordinator, policy: policy),
        isFalse,
      );
      expect(
        FinancePermissionService.canPaySalaries(
            user: coordinator, policy: policy),
        isTrue,
      );
      expect(
        FinancePermissionService.canPaySalaries(user: driver, policy: policy),
        isFalse,
      );
    });

    test('admin can do both steps whatever the settings', () {
      const policy = FinancePolicyEntity(
        salaryManagement: WorkflowPermissionConfig(),
        salaryPayment: WorkflowPermissionConfig(),
      );
      expect(
        FinancePermissionService.canFinalizeSalaries(user: admin, policy: policy),
        isTrue,
      );
      expect(
        FinancePermissionService.canPaySalaries(user: admin, policy: policy),
        isTrue,
      );
    });

    test('a specific person can be named as payer in master data', () {
      const policy = FinancePolicyEntity(
        salaryPayment: WorkflowPermissionConfig(
          allowedUserIds: ['d1'],
          allowedUserNames: ['Driver Dan'],
        ),
      );
      expect(
        FinancePermissionService.canPaySalaries(user: driver, policy: policy),
        isTrue,
      );
      expect(
        FinancePermissionService.canPaySalaries(
            user: coordinator, policy: policy),
        isFalse,
      );
    });

    test('a payer-only user can still open Finance', () {
      const policy = FinancePolicyEntity(
        sessionClose: WorkflowPermissionConfig(),
        expenseSubmit: WorkflowPermissionConfig(),
        fundMovement: WorkflowPermissionConfig(),
        salaryPayment: WorkflowPermissionConfig(allowedRoles: ['coordinator']),
      );
      expect(
        FinancePermissionService.canViewFinance(
            user: coordinator, policy: policy),
        isTrue,
      );
    });

    test('pay permission survives a JSON round trip; old policies default it',
        () {
      const policy = FinancePolicyEntity(
        salaryPayment: WorkflowPermissionConfig(allowedRoles: ['manager']),
      );
      final parsed = FinancePolicyEntity.fromJson(policy.toJson());
      expect(parsed.salaryPayment.allowedRoles, ['manager']);

      // A policy saved before the split keeps its salary setting as the
      // finalize permission and gets the default payers.
      final legacy = FinancePolicyEntity.fromJson({
        'salaryManagement': {
          'allowedRoles': ['finance'],
        },
      });
      expect(legacy.salaryManagement.allowedRoles, ['finance']);
      expect(legacy.salaryPayment.allowedRoles, contains('coordinator'));
    });
  });

  group('FinancePolicyEntity Serialization & Backward Compatibility', () {
    test('toJson and fromJson preserves all workflow configs and approval chain', () {
      const original = FinancePolicyEntity(
        multiLevelApprovalEnabled: true,
        receiptRequiredAbove: 250.0,
        requireVehicleForFuel: false,
        requireEmployeeForSalary: true,
        blockSelfApprove: false,
        sessionOpen: WorkflowPermissionConfig(
          allowedRoles: ['admin', 'coordinator'],
          allowedUserIds: ['user_abc'],
          allowedUserNames: ['Alice'],
        ),
        approvalChain: [
          ApprovalStageEntity(
            name: 'Level 1 Review',
            order: 0,
            maxAmount: 5000,
            approverRoles: ['coordinator'],
            approverUserIds: ['user_xyz'],
            approverUserNames: ['Bob'],
          ),
        ],
      );

      final json = original.toJson();
      final parsed = FinancePolicyEntity.fromJson(json);

      expect(parsed.multiLevelApprovalEnabled, isTrue);
      expect(parsed.receiptRequiredAbove, equals(250.0));
      expect(parsed.requireVehicleForFuel, isFalse);
      expect(parsed.requireEmployeeForSalary, isTrue);
      expect(parsed.blockSelfApprove, isFalse);
      expect(parsed.sessionOpen.allowedRoles, containsAll(['admin', 'coordinator']));
      expect(parsed.sessionOpen.allowedUserIds, contains('user_abc'));
      expect(parsed.sessionOpen.allowedUserNames, contains('Alice'));
      expect(parsed.approvalChain.length, equals(1));
      expect(parsed.approvalChain.first.name, equals('Level 1 Review'));
      expect(parsed.approvalChain.first.maxAmount, equals(5000.0));
      expect(parsed.approvalChain.first.approverUserIds, contains('user_xyz'));
    });

    test('fromJson gracefully falls back on legacy empty map', () {
      final legacyJson = <String, dynamic>{
        'approvalLimits': {'manager': 4000.0, 'finance': 35000.0},
        'receiptRequiredAbove': 150.0,
      };

      final parsed = FinancePolicyEntity.fromJson(legacyJson);
      expect(parsed.receiptRequiredAbove, equals(150.0));
      expect(parsed.limitForRole('manager'), equals(4000.0));
      expect(parsed.limitForRole('finance'), equals(35000.0));
      expect(parsed.multiLevelApprovalEnabled, isFalse);
      expect(parsed.sessionOpen.allowedRoles, isNotEmpty);
      expect(parsed.sessionVerify.allowedRoles, isNotEmpty);
    });
  });
}
