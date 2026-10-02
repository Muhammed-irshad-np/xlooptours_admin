import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/features/finance/domain/entities/fund_account_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/fund_account_type_entity.dart';
import 'package:xloop_invoice/features/finance/domain/usecases/delete_fund_account_type_usecase.dart';
import 'package:xloop_invoice/features/finance/domain/usecases/generate_account_code_usecase.dart';
import 'package:xloop_invoice/features/finance/domain/usecases/get_fund_account_types_usecase.dart';
import 'package:xloop_invoice/features/finance/domain/usecases/insert_fund_account_type_usecase.dart';
import 'package:xloop_invoice/features/finance/domain/usecases/update_fund_account_type_usecase.dart';
import 'test_finance_repository.dart';

void main() {
  group('FundAccountTypeEntity Defaults', () {
    test('strictly defines default 3 account types: Bank, Petty Cash, STC Pay', () {
      final defaults = FundAccountTypeEntity.defaultTypes;
      expect(defaults.length, 3);

      expect(defaults[0].name, 'Bank');
      expect(defaults[0].codePrefix, 'BNK');
      expect(defaults[0].isSystemDefault, isTrue);

      expect(defaults[1].name, 'Petty Cash');
      expect(defaults[1].codePrefix, 'PC');
      expect(defaults[1].isSystemDefault, isTrue);

      expect(defaults[2].name, 'STC Pay');
      expect(defaults[2].codePrefix, 'STC');
      expect(defaults[2].isSystemDefault, isTrue);
    });
  });

  group('FundAccountType UseCases', () {
    late FakeFinanceRepository fakeRepo;
    late GetFundAccountTypesUseCase getUseCase;
    late InsertFundAccountTypeUseCase insertUseCase;
    late UpdateFundAccountTypeUseCase updateUseCase;
    late DeleteFundAccountTypeUseCase deleteUseCase;
    late GenerateAccountCodeUseCase generateCodeUseCase;

    setUp(() {
      fakeRepo = FakeFinanceRepository();
      getUseCase = GetFundAccountTypesUseCase(fakeRepo);
      insertUseCase = InsertFundAccountTypeUseCase(fakeRepo);
      updateUseCase = UpdateFundAccountTypeUseCase(fakeRepo);
      deleteUseCase = DeleteFundAccountTypeUseCase(fakeRepo);
      generateCodeUseCase = const GenerateAccountCodeUseCase();
    });

    test('getFundAccountTypes returns default types from repo', () async {
      final types = await getUseCase();
      expect(types.length, 3);
      expect(types.map((t) => t.name).toList(), containsAll(['Bank', 'Petty Cash', 'STC Pay']));
    });

    test('insertFundAccountType and updateFundAccountType succeed', () async {
      final customType = FundAccountTypeEntity(
        id: 'driver_account',
        name: 'Driver Account',
        codePrefix: 'DRV',
        description: 'Driver vehicle floats',
        isSystemDefault: false,
        createdAt: DateTime.now(),
      );

      await expectLater(insertUseCase(customType), completes);
      await expectLater(updateUseCase(customType.copyWith(name: 'Operations Driver Account')), completes);
      await expectLater(deleteUseCase(customType.id), completes);
    });

    test('GenerateAccountCodeUseCase generates next code for custom FundAccountTypeEntity', () {
      final customType = FundAccountTypeEntity(
        id: 'driver_account',
        name: 'Driver Account',
        codePrefix: 'DRV',
        isSystemDefault: false,
        createdAt: DateTime.now(),
      );

      final code1 = generateCodeUseCase(customType, []);
      expect(code1, 'DRV-001');

      final dummy1 = FundAccountEntity(
        id: '1',
        name: 'Driver 1',
        code: 'DRV-001',
        type: FundAccountType.driverAccount,
        currency: 'SAR',
        createdAt: DateTime.now(),
      );
      final dummy2 = FundAccountEntity(
        id: '2',
        name: 'Driver 2',
        code: 'DRV-002',
        type: FundAccountType.driverAccount,
        currency: 'SAR',
        createdAt: DateTime.now(),
      );

      final code2 = generateCodeUseCase(customType, [dummy1, dummy2]);
      expect(code2, 'DRV-003');
    });
  });
}
