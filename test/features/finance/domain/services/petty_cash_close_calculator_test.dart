import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/features/finance/data/models/petty_cash_session_model.dart';
import 'package:xloop_invoice/features/finance/domain/entities/finance_policy_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/fund_transaction_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/petty_cash_session_entity.dart';
import 'package:xloop_invoice/features/finance/domain/services/petty_cash_close_calculator.dart';

typedef C = PettyCashCloseCalculator;

void main() {
  group('parseMinor', () {
    test('parses whole, decimal, grouped and leading-dot amounts', () {
      expect(C.parseMinor('1200'), 120000);
      expect(C.parseMinor('1,200.5'), 120050);
      expect(C.parseMinor('1200.05'), 120005);
      expect(C.parseMinor('.75'), 75);
      expect(C.parseMinor('12.'), 1200);
      expect(C.parseMinor('0'), 0);
      expect(C.parseMinor('  9.99 '), 999);
    });

    test('rejects empty, negative, malformed and over-precise input', () {
      expect(C.parseMinor(null), isNull);
      expect(C.parseMinor(''), isNull);
      expect(C.parseMinor('.'), isNull);
      expect(C.parseMinor('-5'), isNull);
      expect(C.parseMinor('1.234'), isNull);
      expect(C.parseMinor('abc'), isNull);
      expect(C.parseMinor('1.2.3'), isNull);
    });

    test('is exact where double maths is not (0.1 + 0.2 style values)', () {
      expect(C.parseMinor('0.29'), 29);
      expect(C.parseMinor('1.15'), 115);
      expect(C.parseMinor('4.35'), 435);
    });
  });

  group('formatPlain', () {
    test('formats minor units with two decimals', () {
      expect(C.formatPlain(0), '0.00');
      expect(C.formatPlain(5), '0.05');
      expect(C.formatPlain(120050), '1200.50');
      expect(C.formatPlain(-12345), '-123.45');
    });
  });

  group('plan', () {
    test('balanced count posts nothing and leaves the account as is', () {
      final p = C.plan(
        accountTotalMinor: 150000,
        accountCashMinor: 100000,
        accountStcMinor: 50000,
        countedCashMinor: 100000,
        countedStcMinor: 50000,
      );
      expect(p.isBalanced, isTrue);
      expect(p.lines, isEmpty);
      expect(p.newTotalMinor, 150000);
      expect(p.totalVarianceMinor, 0);
    });

    test('cash shortage posts one debit and lowers the account to the count', () {
      final p = C.plan(
        accountTotalMinor: 150000,
        accountCashMinor: 100000,
        accountStcMinor: 50000,
        countedCashMinor: 80000,
        countedStcMinor: 50000,
      );
      expect(p.cashVarianceMinor, -20000);
      expect(p.stcVarianceMinor, 0);
      expect(p.totalVarianceMinor, -20000);
      expect(p.lines, hasLength(1));
      final l = p.lines.single;
      expect(l.kind, PettyCashLineKind.variance);
      expect(l.bucket, FundBucket.cash);
      expect(l.amountMinor, 20000);
      expect(l.isCredit, isFalse);
      expect(l.balanceBeforeMinor, 150000);
      expect(l.balanceAfterMinor, 130000);
      expect(p.newTotalMinor, 130000);
      expect(p.newCashMinor, 80000);
      expect(p.newStcMinor, 50000);
    });

    test('STC overage posts one credit', () {
      final p = C.plan(
        accountTotalMinor: 150000,
        accountCashMinor: 100000,
        accountStcMinor: 50000,
        countedCashMinor: 100000,
        countedStcMinor: 50550,
      );
      expect(p.totalVarianceMinor, 550);
      final l = p.lines.single;
      expect(l.bucket, FundBucket.stcPay);
      expect(l.isCredit, isTrue);
      expect(l.balanceAfterMinor, 150550);
      expect(p.newTotalMinor, 150550);
    });

    test('recorded transfer explains a mirrored difference: no variance', () {
      final p = C.plan(
        accountTotalMinor: 150000,
        accountCashMinor: 100000,
        accountStcMinor: 50000,
        countedCashMinor: 80000,
        countedStcMinor: 70000,
        transferCashToStcMinor: 20000,
      );
      expect(p.expectedCashMinor, 80000);
      expect(p.expectedStcMinor, 70000);
      expect(p.isBalanced, isTrue);
      expect(p.lines, hasLength(1));
      final t = p.lines.single;
      expect(t.kind, PettyCashLineKind.transfer);
      expect(t.bucket, FundBucket.cash);
      expect(t.toBucket, FundBucket.stcPay);
      expect(t.amountMinor, 20000);
      expect(t.balanceBeforeMinor, t.balanceAfterMinor);
      expect(p.newTotalMinor, 150000);
    });

    test('STC → Cash transfer uses a negative amount', () {
      final p = C.plan(
        accountTotalMinor: 150000,
        accountCashMinor: 100000,
        accountStcMinor: 50000,
        countedCashMinor: 130000,
        countedStcMinor: 20000,
        transferCashToStcMinor: -30000,
      );
      expect(p.isBalanced, isTrue);
      expect(p.lines.single.bucket, FundBucket.stcPay);
      expect(p.lines.single.toBucket, FundBucket.cash);
    });

    test('mirrored difference without a transfer re-splits the buckets, '
        'credit first so the running total never dips', () {
      final p = C.plan(
        accountTotalMinor: 150000,
        accountCashMinor: 100000,
        accountStcMinor: 50000,
        countedCashMinor: 80000,
        countedStcMinor: 70000,
      );
      expect(p.totalVarianceMinor, 0);
      expect(p.isBalanced, isFalse);
      expect(p.lines, hasLength(2));
      expect(p.lines[0].bucket, FundBucket.stcPay);
      expect(p.lines[0].isCredit, isTrue);
      expect(p.lines[0].balanceAfterMinor, 170000);
      expect(p.lines[1].bucket, FundBucket.cash);
      expect(p.lines[1].balanceAfterMinor, 150000);
      expect(p.newTotalMinor, 150000);
    });

    test('partial transfer plus remaining shortage', () {
      // Cash 200 short, STC 150 over: 150 was moved, 50 is really missing.
      final p = C.plan(
        accountTotalMinor: 150000,
        accountCashMinor: 100000,
        accountStcMinor: 50000,
        countedCashMinor: 80000,
        countedStcMinor: 65000,
        transferCashToStcMinor: 15000,
      );
      expect(p.expectedCashMinor, 85000);
      expect(p.expectedStcMinor, 65000);
      expect(p.cashVarianceMinor, -5000);
      expect(p.stcVarianceMinor, 0);
      expect(p.lines, hasLength(2));
      expect(p.lines[0].kind, PettyCashLineKind.transfer);
      expect(p.lines[1].amountMinor, 5000);
      expect(p.newTotalMinor, 145000);
    });

    test('drawer counted empty takes the account to zero', () {
      final p = C.plan(
        accountTotalMinor: 150000,
        accountCashMinor: 100000,
        accountStcMinor: 50000,
        countedCashMinor: 0,
        countedStcMinor: 0,
      );
      expect(p.newTotalMinor, 0);
      expect(p.lines.last.balanceAfterMinor, 0);
    });

    test('refuses negative counts and transfers larger than the source', () {
      expect(
        () => C.plan(
          accountTotalMinor: 100,
          accountCashMinor: 100,
          accountStcMinor: 0,
          countedCashMinor: -1,
          countedStcMinor: 0,
        ),
        throwsStateError,
      );
      expect(
        () => C.plan(
          accountTotalMinor: 150000,
          accountCashMinor: 100000,
          accountStcMinor: 50000,
          countedCashMinor: 0,
          countedStcMinor: 150000,
          transferCashToStcMinor: 100001,
        ),
        throwsStateError,
      );
      expect(
        () => C.plan(
          accountTotalMinor: 150000,
          accountCashMinor: 100000,
          accountStcMinor: 50000,
          countedCashMinor: 150000,
          countedStcMinor: 0,
          transferCashToStcMinor: -50001,
        ),
        throwsStateError,
      );
    });

    test('random closings always reconcile to the halala', () {
      final rnd = Random(42);
      for (var i = 0; i < 5000; i++) {
        final cash = rnd.nextInt(1000000);
        final stc = rnd.nextInt(1000000);
        final countedCash = rnd.nextInt(1000000);
        final countedStc = rnd.nextInt(1000000);
        final suggested = C.suggestedTransferCashToStc(
          cashDiffMinor: countedCash - cash,
          stcDiffMinor: countedStc - stc,
        );
        final transfer = (suggested != null && rnd.nextBool())
            ? (suggested > 0
                ? 1 + rnd.nextInt(suggested)
                : -(1 + rnd.nextInt(-suggested)))
            : 0;
        final p = C.plan(
          accountTotalMinor: cash + stc,
          accountCashMinor: cash,
          accountStcMinor: stc,
          countedCashMinor: countedCash,
          countedStcMinor: countedStc,
          transferCashToStcMinor: transfer,
        );

        // Account ends exactly at the count.
        expect(p.newTotalMinor, countedCash + countedStc);
        expect(p.newCashMinor + p.newStcMinor, p.newTotalMinor);
        // Variance is exactly counted − expected.
        expect(p.totalVarianceMinor,
            (countedCash + countedStc) - (cash + stc));
        // Ledger rows chain and add up.
        var running = cash + stc;
        for (final l in p.lines) {
          expect(l.balanceBeforeMinor, running);
          expect(l.amountMinor, greaterThan(0));
          final delta = l.balanceAfterMinor - l.balanceBeforeMinor;
          if (l.kind == PettyCashLineKind.transfer) {
            expect(delta, 0);
          } else {
            expect(delta.abs(), l.amountMinor);
          }
          expect(l.balanceAfterMinor, greaterThanOrEqualTo(0));
          running = l.balanceAfterMinor;
        }
        expect(running, p.newTotalMinor);
        // Per-bucket: account bucket + transfer + variance = count.
        expect(cash - p.transferCashToStcMinor + p.cashVarianceMinor, countedCash);
        expect(stc + p.transferCashToStcMinor + p.stcVarianceMinor, countedStc);
      }
    });
  });

  group('suggestedTransferCashToStc', () {
    test('detects mirrored differences in both directions', () {
      expect(C.suggestedTransferCashToStc(cashDiffMinor: -20000, stcDiffMinor: 20000), 20000);
      expect(C.suggestedTransferCashToStc(cashDiffMinor: -20000, stcDiffMinor: 15000), 15000);
      expect(C.suggestedTransferCashToStc(cashDiffMinor: 10000, stcDiffMinor: -30000), -10000);
    });

    test('no suggestion when both move the same way or one is zero', () {
      expect(C.suggestedTransferCashToStc(cashDiffMinor: -100, stcDiffMinor: -100), isNull);
      expect(C.suggestedTransferCashToStc(cashDiffMinor: 100, stcDiffMinor: 100), isNull);
      expect(C.suggestedTransferCashToStc(cashDiffMinor: 0, stcDiffMinor: 500), isNull);
      expect(C.suggestedTransferCashToStc(cashDiffMinor: 0, stcDiffMinor: 0), isNull);
    });
  });

  group('checks', () {
    test('any bucket difference needs a reason; none when balanced', () {
      expect(C.checks(cashVarianceMinor: 0, stcVarianceMinor: 0, recountAboveMinor: 500, adminCloseAboveMinor: 50000).needsReason, isFalse);
      expect(C.checks(cashVarianceMinor: -1, stcVarianceMinor: 0, recountAboveMinor: 500, adminCloseAboveMinor: 50000).needsReason, isTrue);
      expect(C.checks(cashVarianceMinor: -100, stcVarianceMinor: 100, recountAboveMinor: 500, adminCloseAboveMinor: 50000).needsReason, isTrue);
    });

    test('recount is strictly above the threshold, on the larger bucket', () {
      expect(C.checks(cashVarianceMinor: -500, stcVarianceMinor: 0, recountAboveMinor: 500, adminCloseAboveMinor: 0).needsRecount, isFalse);
      expect(C.checks(cashVarianceMinor: -501, stcVarianceMinor: 0, recountAboveMinor: 500, adminCloseAboveMinor: 0).needsRecount, isTrue);
      // Total is 0 but each bucket is off by 300 SAR: still recount.
      expect(C.checks(cashVarianceMinor: -30000, stcVarianceMinor: 30000, recountAboveMinor: 500, adminCloseAboveMinor: 0).needsRecount, isTrue);
    });

    test('admin close uses the total, and 0 turns it off', () {
      expect(C.checks(cashVarianceMinor: -50001, stcVarianceMinor: 0, recountAboveMinor: 500, adminCloseAboveMinor: 50000).needsAdmin, isTrue);
      expect(C.checks(cashVarianceMinor: -50000, stcVarianceMinor: 0, recountAboveMinor: 500, adminCloseAboveMinor: 50000).needsAdmin, isFalse);
      expect(C.checks(cashVarianceMinor: -60000, stcVarianceMinor: 60000, recountAboveMinor: 500, adminCloseAboveMinor: 50000).needsAdmin, isFalse);
      expect(C.checks(cashVarianceMinor: -999999, stcVarianceMinor: 0, recountAboveMinor: 500, adminCloseAboveMinor: 0).needsAdmin, isFalse);
    });
  });

  group('splitShortage', () {
    test('full recovery, full write-off and a split add up', () {
      expect(C.splitShortage(shortageMinor: 20000, recoveryMinor: 20000), (recoveryMinor: 20000, writeOffMinor: 0));
      expect(C.splitShortage(shortageMinor: 20000, recoveryMinor: 0), (recoveryMinor: 0, writeOffMinor: 20000));
      expect(C.splitShortage(shortageMinor: 20000, recoveryMinor: 12550), (recoveryMinor: 12550, writeOffMinor: 7450));
    });

    test('rejects recovering more than the shortage, negatives, no shortage', () {
      expect(() => C.splitShortage(shortageMinor: 20000, recoveryMinor: 20001), throwsStateError);
      expect(() => C.splitShortage(shortageMinor: 20000, recoveryMinor: -1), throwsStateError);
      expect(() => C.splitShortage(shortageMinor: 0, recoveryMinor: 0), throwsStateError);
    });
  });

  group('PettyCashSessionEntity with closing figures', () {
    final base = PettyCashSessionEntity(
      id: 's1',
      fundAccountId: 'a1',
      date: DateTime(2026, 11, 24),
      createdAt: DateTime(2026, 11, 24, 8),
      openingCashBalance: 1000,
      openingStcPayBalance: 500,
      cashDeposits: 0,
      cashExpenses: 100,
    );

    test('older sessions fall back to opening + ledger sums', () {
      expect(base.expectedCashClosing, 900);
      expect(base.expectedStcPayClosing, 500);
    });

    test('expected recorded at closing wins and drives the discrepancies', () {
      final closed = base.copyWith(
        expectedCashAtClose: 750,
        expectedStcPayAtClose: 650,
        cashInHand: 700,
        stcPayBalance: 650,
        closingBalance: 1350,
        discrepancy: -50,
      );
      expect(closed.expectedClosingBalance, 1400);
      expect(closed.cashDiscrepancy, -50);
      expect(closed.stcPayDiscrepancy, 0);
      expect(closed.closingBalance - closed.expectedClosingBalance, closed.discrepancy);
    });

    test('model round-trips the closing fields; legacy JSON gets defaults', () {
      final closed = PettyCashSessionModel.fromEntity(base.copyWith(
        status: PettyCashSessionStatus.closed,
        closedAt: DateTime(2026, 11, 24, 21),
        expectedCashAtClose: 750,
        expectedStcPayAtClose: 650,
        varianceCorrected: true,
        closeTransactionIds: const ['t1', 't2'],
        closeTransferCashToStc: 150,
        recountCount: 1,
        firstCountCash: 690,
        firstCountStcPay: 650,
        resolution: 'salaryRecovery',
        salaryRecoveryAmount: 50,
        writeOffAmount: 0,
        resolutionAdvanceId: 'adv1',
      ));
      final back = PettyCashSessionModel.fromJson(closed.toJson());
      expect(back, closed);

      final legacy = PettyCashSessionModel.fromJson({
        'id': 'old',
        'fundAccountId': 'a1',
        'date': '2026-11-18T00:00:00.000',
        'status': 'verified',
        'createdAt': '2026-11-18T08:00:00.000',
      });
      expect(legacy.varianceCorrected, isFalse);
      expect(legacy.closeTransactionIds, isEmpty);
      expect(legacy.closeTransferCashToStc, 0);
      expect(legacy.expectedCashAtClose, isNull);
    });
  });

  group('FinancePolicyEntity closing rules', () {
    test('defaults: recount above 5 SAR, admin close above 500 SAR', () {
      const p = FinancePolicyEntity();
      expect(p.pettyCashRecountAbove, 5);
      expect(p.pettyCashAdminCloseAbove, 500);
      final fromOld = FinancePolicyEntity.fromJson(const {});
      expect(fromOld.pettyCashRecountAbove, 5);
      expect(fromOld.pettyCashAdminCloseAbove, 500);
    });

    test('round-trips through JSON, including 0 = off', () {
      final p = const FinancePolicyEntity().copyWith(
        pettyCashRecountAbove: 2.5,
        pettyCashAdminCloseAbove: 0,
      );
      final back = FinancePolicyEntity.fromJson(p.toJson());
      expect(back.pettyCashRecountAbove, 2.5);
      expect(back.pettyCashAdminCloseAbove, 0);
    });
  });
}
