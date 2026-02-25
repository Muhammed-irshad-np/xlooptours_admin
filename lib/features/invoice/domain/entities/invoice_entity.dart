import 'package:equatable/equatable.dart';
import '../../../../features/company/domain/entities/company_entity.dart';
import 'line_item_entity.dart';

class InvoiceEntity extends Equatable {
  final String? id;
  final DateTime date;
  final String invoiceNumber;
  final String contractReference;
  final String paymentTerms;
  final CompanyEntity? company;
  final List<LineItemEntity> lineItems;
  final double taxRate;
  final double discount;

  const InvoiceEntity({
    this.id,
    required this.date,
    required this.invoiceNumber,
    required this.contractReference,
    required this.paymentTerms,
    this.company,
    required this.lineItems,
    this.taxRate = 5.0,
    this.discount = 3.0,
  });

  double get subtotalAmount {
    return lineItems.fold(0.0, (sum, item) => sum + item.totalAmount);
  }

  double get totalDiscount {
    return lineItems.fold(0.0, (sum, item) {
      return sum + (item.totalAmount * discount / 100);
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

  @override
  List<Object?> get props => [
    id,
    date,
    invoiceNumber,
    contractReference,
    paymentTerms,
    company,
    lineItems,
    taxRate,
    discount,
  ];
}
