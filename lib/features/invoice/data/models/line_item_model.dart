import '../../domain/entities/line_item_entity.dart';

class LineItemModel extends LineItemEntity {
  const LineItemModel({
    required super.description,
    required super.unit,
    required super.unitType,
    super.referenceCode,
    required super.subtotalAmount,
    required super.totalAmount,
  });

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'unit': unit,
      'unitType': unitType,
      'referenceCode': referenceCode,
      'subtotalAmount': subtotalAmount,
      'totalAmount': totalAmount,
    };
  }

  factory LineItemModel.fromJson(Map<String, dynamic> json) {
    return LineItemModel(
      description: json['description'] as String,
      unit: json['unit'] as String,
      unitType: (json['unitType'] ?? 'LOT') as String,
      referenceCode: json['referenceCode'] as String?,
      subtotalAmount: (json['subtotalAmount'] as num).toDouble(),
      totalAmount: (json['totalAmount'] as num).toDouble(),
    );
  }

  factory LineItemModel.fromEntity(LineItemEntity entity) {
    return LineItemModel(
      description: entity.description,
      unit: entity.unit,
      unitType: entity.unitType,
      referenceCode: entity.referenceCode,
      subtotalAmount: entity.subtotalAmount,
      totalAmount: entity.totalAmount,
    );
  }

  LineItemModel copyWith({
    String? description,
    String? unit,
    String? unitType,
    String? referenceCode,
    double? subtotalAmount,
    double? totalAmount,
  }) {
    return LineItemModel(
      description: description ?? this.description,
      unit: unit ?? this.unit,
      unitType: unitType ?? this.unitType,
      referenceCode: referenceCode ?? this.referenceCode,
      subtotalAmount: subtotalAmount ?? this.subtotalAmount,
      totalAmount: totalAmount ?? this.totalAmount,
    );
  }

  static double calculateTotal(double unitPrice, String quantity) {
    final qty = double.tryParse(quantity) ?? 0.0;
    return unitPrice * qty;
  }
}
