import 'package:equatable/equatable.dart';

class AnalyticsEntity extends Equatable {
  final double totalRevenue;
  final int invoiceCount;
  final double averageInvoiceValue;
  final double totalTax;
  final double totalDiscount;
  final List<MonthlyRevenueEntity> monthlyRevenue;
  final List<TopCompanyEntity> topCompanies;

  const AnalyticsEntity({
    required this.totalRevenue,
    required this.invoiceCount,
    required this.averageInvoiceValue,
    required this.totalTax,
    required this.totalDiscount,
    required this.monthlyRevenue,
    required this.topCompanies,
  });

  @override
  List<Object?> get props => [
    totalRevenue,
    invoiceCount,
    averageInvoiceValue,
    totalTax,
    totalDiscount,
    monthlyRevenue,
    topCompanies,
  ];
}

class MonthlyRevenueEntity extends Equatable {
  final int month;
  final int year;
  final double revenue;
  final int count;

  const MonthlyRevenueEntity({
    required this.month,
    required this.year,
    required this.revenue,
    required this.count,
  });

  @override
  List<Object?> get props => [month, year, revenue, count];
}

class TopCompanyEntity extends Equatable {
  final String companyName;
  final double revenue;
  final int invoiceCount;

  const TopCompanyEntity({
    required this.companyName,
    required this.revenue,
    required this.invoiceCount,
  });

  @override
  List<Object?> get props => [companyName, revenue, invoiceCount];
}
