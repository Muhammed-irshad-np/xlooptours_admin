import 'package:equatable/equatable.dart';

class LineItemEntity extends Equatable {
  final String description;
  final String unit;
  final String unitType;
  final String? referenceCode;
  final double subtotalAmount;
  final double totalAmount;

  const LineItemEntity({
    required this.description,
    required this.unit,
    required this.unitType,
    this.referenceCode,
    required this.subtotalAmount,
    required this.totalAmount,
  });

  LineItemEntity copyWith({
    String? description,
    String? unit,
    String? unitType,
    String? referenceCode,
    double? subtotalAmount,
    double? totalAmount,
  }) {
    return LineItemEntity(
      description: description ?? this.description,
      unit: unit ?? this.unit,
      unitType: unitType ?? this.unitType,
      referenceCode: referenceCode ?? this.referenceCode,
      subtotalAmount: subtotalAmount ?? this.subtotalAmount,
      totalAmount: totalAmount ?? this.totalAmount,
    );
  }

  static double calculateTotal(double unitPrice, String quantity) {
    if (quantity.isEmpty) return 0.0;

    // Parse quantity, handle both integer and decimal values
    final qty = double.tryParse(quantity) ?? 0.0;
    return unitPrice * qty;
  }

  @override
  List<Object?> get props => [
    description,
    unit,
    unitType,
    referenceCode,
    subtotalAmount,
    totalAmount,
  ];
}
