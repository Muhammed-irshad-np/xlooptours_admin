import '../entities/analytics_entity.dart';
import '../../../invoice/domain/usecases/get_all_invoices_usecase.dart';

class GetAnalyticsUseCase {
  final GetAllInvoicesUseCase getAllInvoicesUseCase;

  GetAnalyticsUseCase(this.getAllInvoicesUseCase);

  Future<AnalyticsEntity> call({int? month, int? year}) async {
    final invoices = await getAllInvoicesUseCase(month: month, year: year);

    double totalRevenue = 0;
    double totalTax = 0;
    double totalDiscount = 0;
    int invoiceCount = invoices.length;

    for (var invoice in invoices) {
      totalRevenue += invoice.grandTotal;
      totalTax += invoice.taxAmount;
      totalDiscount += invoice.totalDiscount;
    }

    double averageInvoiceValue = invoiceCount > 0
        ? totalRevenue / invoiceCount
        : 0;

    // Monthly revenue (last 6 months)
    final now = DateTime.now();
    List<MonthlyRevenueEntity> monthlyRevenue = [];

    for (int i = 5; i >= 0; i--) {
      final targetMonth = DateTime(now.year, now.month - i, 1);
      final monthInvoices = await getAllInvoicesUseCase(
        month: targetMonth.month,
        year: targetMonth.year,
      );

      double monthTotal = 0;
      for (var invoice in monthInvoices) {
        monthTotal += invoice.grandTotal;
      }

      monthlyRevenue.add(
        MonthlyRevenueEntity(
          month: targetMonth.month,
          year: targetMonth.year,
          revenue: monthTotal,
          count: monthInvoices.length,
        ),
      );
    }

    // Top Companies by Revenue
    Map<String, Map<String, dynamic>> companyRevenue = {};

    for (var invoice in invoices) {
      if (invoice.company != null) {
        // Use company ID as the key, or company name if ID is missing (fallback)
        final id = invoice.company!.id;
        if (!companyRevenue.containsKey(id)) {
          companyRevenue[id] = {
            'companyName': invoice.company!.companyName,
            'revenue': 0.0,
            'invoiceCount': 0,
          };
        }
        companyRevenue[id]!['revenue'] += invoice.grandTotal;
        companyRevenue[id]!['invoiceCount'] += 1;
      }
    }

    final topCompaniesList = companyRevenue.values.toList()
      ..sort(
        (a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double),
      );

    final top5 = topCompaniesList
        .take(5)
        .map(
          (e) => TopCompanyEntity(
            companyName: e['companyName'] as String,
            revenue: e['revenue'] as double,
            invoiceCount: e['invoiceCount'] as int,
          ),
        )
        .toList();

    return AnalyticsEntity(
      totalRevenue: totalRevenue,
      invoiceCount: invoiceCount,
      averageInvoiceValue: averageInvoiceValue,
      totalTax: totalTax,
      totalDiscount: totalDiscount,
      monthlyRevenue: monthlyRevenue,
      topCompanies: top5,
    );
  }
}
