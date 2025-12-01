import 'customer_model.dart';
import 'line_item_model.dart';

class InvoiceModel {
  final String? id; // UUID for database
  final DateTime date;
  final String invoiceNumber;
  final String contractReference;
  final String paymentTerms;
  final CustomerModel? customer;
  final List<LineItemModel> lineItems;
  final double taxRate; // WHT Rate, default 5.0
  final double discount; // Global discount rate (%)

  InvoiceModel({
    this.id,
    required this.date,
    required this.invoiceNumber,
    required this.contractReference,
    required this.paymentTerms,
    this.customer,
    required this.lineItems,
    this.taxRate = 5.0,
    this.discount = 0.0,
  });

  Map<String, dynamic> toJson() {
    final map = {
      'date': date.toIso8601String(),
      'invoiceNumber': invoiceNumber,
      'contractReference': contractReference,
      'paymentTerms': paymentTerms,
      'taxRate': taxRate,
      'discount': discount,
      'lineItems': lineItems.map((item) => item.toJson()).toList(),
    };

    if (id != null) {
      map['id'] = id!;
    }

    if (customer != null) {
      map['customer'] = customer!.toJson();
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
      customer: json['customer'] != null
          ? CustomerModel.fromJson(json['customer'] as Map<String, dynamic>)
          : null,
      lineItems: (json['lineItems'] as List)
          .map((item) => LineItemModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  // Factory for creating from Firestore document data
  factory InvoiceModel.fromMap(
    Map<String, dynamic> map, {
    CustomerModel? customer,
    List<LineItemModel>? items,
  }) {
    // Handle date conversion - can be int (millisecondsSinceEpoch) or Timestamp
    DateTime dateValue;
    if (map['date'] is int) {
      dateValue = DateTime.fromMillisecondsSinceEpoch(map['date'] as int);
    } else if (map['date'] is String) {
      dateValue = DateTime.parse(map['date'] as String);
    } else {
      // Fallback to current date if format is unexpected
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
      customer: customer,
      lineItems: items ?? [],
    );
  }

  // Calculate totals
  double get subtotalAmount {
    return lineItems.fold(0.0, (sum, item) => sum + item.subtotalAmount);
  }

  double get totalDiscount {
    return lineItems.fold(0.0, (sum, item) {
      return sum + (item.subtotalAmount * discount / 100);
    });
  }

  double get totalAmount {
    return subtotalAmount - totalDiscount;
  }

  double get taxAmount {
    return totalAmount * (taxRate / 100);
  }

  double get grandTotal {
    return totalAmount + taxAmount;
  }

  InvoiceModel copyWith({
    String? id,
    DateTime? date,
    String? invoiceNumber,
    String? contractReference,
    String? paymentTerms,
    CustomerModel? customer,
    List<LineItemModel>? lineItems,
    double? taxRate,
    double? discount,
  }) {
    return InvoiceModel(
      id: id ?? this.id,
      date: date ?? this.date,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      contractReference: contractReference ?? this.contractReference,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      customer: customer ?? this.customer,
      lineItems: lineItems ?? this.lineItems,
      taxRate: taxRate ?? this.taxRate,
      discount: discount ?? this.discount,
    );
  }
}
