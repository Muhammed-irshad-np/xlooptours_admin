import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/features/employee/domain/entities/document_renewal_entity.dart';
import 'package:xloop_invoice/features/employee/domain/entities/employee_documents.dart';
import 'package:xloop_invoice/features/employee/domain/entities/employee_entity.dart';

void main() {
  final base = EmployeeEntity.empty().copyWith(id: 'e1', fullName: 'Ali');
  final at = DateTime(2026, 11, 7, 10);
  var n = 0;
  String newId() => 'r${n++}';

  List<DocumentRenewalEntity> detect(EmployeeEntity a, EmployeeEntity b) =>
      DocumentRenewalEntity.detect(
        a,
        b,
        renewedAt: at,
        newId: newId,
        renewedBy: 'Admin',
        source: 'Employee form',
      );

  final iqama = IqamaDocument(
    number: '123',
    expiryDate: DateTime(2026, 12, 1),
    attachmentUrl: 'old.pdf',
  );

  test('records a renewal when an existing expiry moves', () {
    final before = base.copyWith(iqama: iqama);
    final after = base.copyWith(
      iqama: IqamaDocument(
        number: '123',
        expiryDate: DateTime(2027, 12, 1),
        attachmentUrl: 'new.pdf',
      ),
    );

    final result = detect(before, after);

    expect(result, hasLength(1));
    final r = result.single;
    expect(r.documentType, 'Iqama');
    expect(r.employeeId, 'e1');
    expect(r.previousExpiryDate, DateTime(2026, 12, 1));
    expect(r.newExpiryDate, DateTime(2027, 12, 1));
    expect(r.previousAttachmentUrl, 'old.pdf');
    expect(r.newAttachmentUrl, 'new.pdf');
    expect(r.renewedBy, 'Admin');
    expect(r.source, 'Employee form');
    expect(r.numberChanged, isFalse);
  });

  test('ignores adding, removing, and number-only edits', () {
    expect(detect(base, base.copyWith(iqama: iqama)), isEmpty);
    expect(detect(base.copyWith(iqama: iqama), base), isEmpty);
    expect(
      detect(
        base.copyWith(iqama: iqama),
        base.copyWith(
          iqama: IqamaDocument(number: '999', expiryDate: iqama.expiryDate),
        ),
      ),
      isEmpty,
    );
  });

  test('ignores a time-of-day change on the same expiry date', () {
    final after = base.copyWith(
      iqama: IqamaDocument(
        number: '123',
        expiryDate: DateTime(2026, 12, 1, 15),
      ),
    );
    expect(detect(base.copyWith(iqama: iqama), after), isEmpty);
  });

  test('records each renewed document separately, visas included', () {
    final visa = VisaDocument(
      number: 'V1',
      expiryDate: DateTime(2026, 1, 1),
      type: VisaType.multipleEntry,
    );
    final before = base.copyWith(
      iqama: iqama,
      saudiVisa: visa,
      healthInsurance: HealthInsuranceDocument(expiryDate: DateTime(2026, 5)),
    );
    final after = before.copyWith(
      iqama: IqamaDocument(number: '456', expiryDate: DateTime(2027, 12, 1)),
      saudiVisa: VisaDocument(
        number: 'V2',
        expiryDate: DateTime(2027, 1, 1),
        type: VisaType.multipleEntry,
      ),
    );

    final result = detect(before, after);

    expect(result.map((r) => r.documentType), ['Iqama', 'Saudi Visa']);
    expect(result.first.numberChanged, isTrue);
    expect(result.map((r) => r.id).toSet(), hasLength(2));
  });
}
