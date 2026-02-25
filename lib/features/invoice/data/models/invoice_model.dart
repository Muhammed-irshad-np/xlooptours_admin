import '../../../../features/company/data/models/company_model.dart';
import '../../../../features/company/domain/entities/company_entity.dart';
import '../../domain/entities/invoice_entity.dart';
import '../../domain/entities/line_item_entity.dart';
import 'line_item_model.dart';

class InvoiceModel extends InvoiceEntity {
  const InvoiceModel({
    super.id,
    required super.date,
    required super.invoiceNumber,
    required super.contractReference,
    required super.paymentTerms,
    super.company,
    required super.lineItems,
    super.taxRate = 5.0,
    super.discount = 3.0,
  });

  Map<String, dynamic> toJson() {
    final map = {
      'date': date.toIso8601String(),
      'invoiceNumber': invoiceNumber,
      'contractReference': contractReference,
      'paymentTerms': paymentTerms,
      'taxRate': taxRate,
      'discount': discount,
      'lineItems': lineItems.map((item) {
        if (item is LineItemModel) {
          return item.toJson();
        }
        return LineItemModel.fromEntity(item).toJson();
      }).toList(),
    };

    if (id != null) {
      map['id'] = id!;
    }

    if (company != null) {
      if (company is CompanyModel) {
        map['company'] = (company as CompanyModel).toJson();
        map['companyId'] = company!.id;
        map['customerId'] = company!.id; // Legacy Sync
      } else {
        map['company'] = CompanyModel.fromEntity(company!).toJson();
        map['companyId'] = company!.id;
        map['customerId'] = company!.id; // Legacy Sync
      }
    }

    return map;
  }

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    return InvoiceModel(
      id: json['id'] as String?,
      date: DateTime.parse(json['date'] as String),
      invoiceNumber: json['invoiceNumber'] as String,
      contractReference: json['contractReference'] as String,
      paymentTerms: json['paymentTerms'] as String,
      taxRate: (json['taxRate'] as num?)?.toDouble() ?? 5.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      company: json['company'] != null
          ? CompanyModel.fromJson(json['company'] as Map<String, dynamic>)
          : (json['customer'] != null
                ? CompanyModel.fromJson(
                    json['customer'] as Map<String, dynamic>,
                  )
                : null), // Fallback for old data
      lineItems: (json['lineItems'] as List)
          .map((item) => LineItemModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  factory InvoiceModel.fromMap(
    Map<String, dynamic> map, {
    CompanyEntity? company,
    List<LineItemEntity>? items,
  }) {
    DateTime dateValue;
    if (map['date'] is int) {
      dateValue = DateTime.fromMillisecondsSinceEpoch(map['date'] as int);
    } else if (map['date'] is String) {
      dateValue = DateTime.parse(map['date'] as String);
    } else {
      dateValue = DateTime.now();
    }

    return InvoiceModel(
      id: map['id'] as String?,
      date: dateValue,
      invoiceNumber: map['invoiceNumber'] as String,
      contractReference: map['contractReference'] as String,
      paymentTerms: map['paymentTerms'] as String,
      taxRate: (map['taxRate'] as num?)?.toDouble() ?? 5.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      company: company,
      lineItems: items ?? [],
    );
  }

  factory InvoiceModel.fromEntity(InvoiceEntity entity) {
    return InvoiceModel(
      id: entity.id,
      date: entity.date,
      invoiceNumber: entity.invoiceNumber,
      contractReference: entity.contractReference,
      paymentTerms: entity.paymentTerms,
      company: entity.company,
      lineItems: entity.lineItems,
      taxRate: entity.taxRate,
      discount: entity.discount,
    );
  }

  InvoiceModel copyWith({
    String? id,
    DateTime? date,
    String? invoiceNumber,
    String? contractReference,
    String? paymentTerms,
    CompanyEntity? company,
    List<LineItemEntity>? lineItems,
    double? taxRate,
    double? discount,
  }) {
    return InvoiceModel(
      id: id ?? this.id,
      date: date ?? this.date,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      contractReference: contractReference ?? this.contractReference,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      company: company ?? this.company,
      lineItems: lineItems ?? this.lineItems,
      taxRate: taxRate ?? this.taxRate,
      discount: discount ?? this.discount,
    );
  }
}
