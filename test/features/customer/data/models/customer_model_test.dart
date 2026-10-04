import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/features/customer/data/models/customer_model.dart';

void main() {
  Map<String, dynamic> baseJson() => {
        'id': 'c1',
        'name': 'Wahid',
        'phone': '+966 500000000',
        'createdAt': '2026-01-01T00:00:00.000',
      };

  group('first and last name', () {
    test('round-trips through JSON', () {
      final json = CustomerModel.fromJson(
        baseJson()
          ..['name'] = 'Mohammed Ali'
          ..['firstName'] = 'Mohammed'
          ..['lastName'] = 'Ali',
      ).toJson();

      final restored = CustomerModel.fromJson(json);
      expect(restored.name, 'Mohammed Ali');
      expect(restored.firstName, 'Mohammed');
      expect(restored.lastName, 'Ali');
    });

    test('are null for customers saved before the name was split', () {
      final model = CustomerModel.fromJson(baseJson());

      expect(model.name, 'Wahid');
      expect(model.firstName, isNull);
      expect(model.lastName, isNull);
    });
  });
}
