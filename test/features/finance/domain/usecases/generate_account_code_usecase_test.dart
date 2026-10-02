import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/features/finance/domain/entities/fund_account_entity.dart';
import 'package:xloop_invoice/features/finance/domain/usecases/generate_account_code_usecase.dart';

void main() {
  late GenerateAccountCodeUseCase useCase;

  setUp(() {
    useCase = const GenerateAccountCodeUseCase();
  });

  FundAccountEntity createDummyAccount({
    required String id,
    required String code,
    required FundAccountType type,
  }) {
    return FundAccountEntity(
      id: id,
      name: 'Test Account $code',
      code: code,
      type: type,
      currency: 'SAR',
      createdAt: DateTime.now(),
    );
  }

  group('GenerateAccountCodeUseCase', () {
    test('generates PC-001 when no existing accounts exist', () {
      final code = useCase(FundAccountType.pettyCash, []);
      expect(code, 'PC-001');
    });

    test('generates DRV-001 for driver account when empty', () {
      final code = useCase(FundAccountType.driverAccount, []);
      expect(code, 'DRV-001');
    });

    test('increments sequence sequentially for the same account type', () {
      final accounts = [
        createDummyAccount(id: '1', code: 'PC-001', type: FundAccountType.pettyCash),
        createDummyAccount(id: '2', code: 'PC-002', type: FundAccountType.pettyCash),
      ];

      final code = useCase(FundAccountType.pettyCash, accounts);
      expect(code, 'PC-003');
    });

    test('isolates sequence numbers per account type prefix', () {
      final accounts = [
        createDummyAccount(id: '1', code: 'PC-001', type: FundAccountType.pettyCash),
        createDummyAccount(id: '2', code: 'PC-002', type: FundAccountType.pettyCash),
        createDummyAccount(id: '3', code: 'DRV-001', type: FundAccountType.driverAccount),
        createDummyAccount(id: '4', code: 'STC-001', type: FundAccountType.stcPay),
        createDummyAccount(id: '5', code: 'BNK-001', type: FundAccountType.bank),
      ];

      expect(useCase(FundAccountType.pettyCash, accounts), 'PC-003');
      expect(useCase(FundAccountType.driverAccount, accounts), 'DRV-002');
      expect(useCase(FundAccountType.stcPay, accounts), 'STC-002');
      expect(useCase(FundAccountType.bank, accounts), 'BNK-002');
      expect(useCase(FundAccountType.tamkeen, accounts), 'TMK-001');
      expect(useCase(FundAccountType.fuelCard, accounts), 'FL-001');
      expect(useCase(FundAccountType.admin, accounts), 'ADM-001');
      expect(useCase(FundAccountType.other, accounts), 'ACC-001');
    });

    test('handles gaps in sequence and picks max sequence + 1', () {
      final accounts = [
        createDummyAccount(id: '1', code: 'PC-001', type: FundAccountType.pettyCash),
        createDummyAccount(id: '2', code: 'PC-005', type: FundAccountType.pettyCash),
      ];

      final code = useCase(FundAccountType.pettyCash, accounts);
      expect(code, 'PC-006');
    });

    test('handles legacy custom codes gracefully without error', () {
      final accounts = [
        createDummyAccount(id: '1', code: 'PETTY ACC#001', type: FundAccountType.pettyCash),
        createDummyAccount(id: '2', code: 'ACC-CUSTOM', type: FundAccountType.pettyCash),
        createDummyAccount(id: '3', code: 'PC-002', type: FundAccountType.pettyCash),
      ];

      final code = useCase(FundAccountType.pettyCash, accounts);
      expect(code, 'PC-003');
    });

    test('prevents collision if candidate code is already taken in another format or case', () {
      final accounts = [
        createDummyAccount(id: '1', code: 'pc-001', type: FundAccountType.other),
      ];

      // Even if type is pettyCash, PC-001 is taken (case-insensitively)
      final code = useCase(FundAccountType.pettyCash, accounts);
      expect(code, 'PC-002');
    });
  });
}
