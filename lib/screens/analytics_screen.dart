import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../features/analytics/presentation/providers/analytics_provider.dart';
import '../features/analytics/domain/entities/analytics_entity.dart';
import '../widgets/responsive_layout.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final ValueNotifier<int?> _selectedMonth = ValueNotifier<int?>(null);
  final ValueNotifier<int?> _selectedYear = ValueNotifier<int?>(null);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _selectedMonth.dispose();
    _selectedYear.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      await context.read<AnalyticsProvider>().fetchAnalytics(
        month: _selectedMonth.value,
        year: _selectedYear.value,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading analytics: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      symbol: 'SR ',
      decimalDigits: 2,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics'), elevation: 0),
      body: Consumer<AnalyticsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(child: Text('Error: ${provider.error}'));
          }

          final analytics = provider.analytics;
          if (analytics == null) {
            return const Center(child: Text('No analytics data available'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filters
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ResponsiveLayout(
                      mobile: ValueListenableBuilder<int?>(
                        valueListenable: _selectedYear,
                        builder: (context, selectedYear, _) {
                          return ValueListenableBuilder<int?>(
                            valueListenable: _selectedMonth,
                            builder: (context, selectedMonth, _) {
                              return Column(
                                children: _buildFilterChildren(
                                  selectedYear: selectedYear,
                                  selectedMonth: selectedMonth,
                                ),
                              );
                            },
                          );
                        },
                      ),
                      desktop: ValueListenableBuilder<int?>(
                        valueListenable: _selectedYear,
                        builder: (context, selectedYear, _) {
                          return ValueListenableBuilder<int?>(
                            valueListenable: _selectedMonth,
                            builder: (context, selectedMonth, _) {
                              return Row(
                                children: _buildFilterChildren(
                                  isRow: true,
                                  selectedYear: selectedYear,
                                  selectedMonth: selectedMonth,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Summary Cards
                ResponsiveLayout(
                  mobile: Column(
                    children: _buildSummaryCards(analytics, currencyFormat),
                  ),
                  desktop: Row(
                    children: _buildSummaryCards(
                      analytics,
                      currencyFormat,
                      isRow: true,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Charts
                ResponsiveLayout(
                  mobile: Column(
                    children: [
                      _buildMonthlyRevenueChart(analytics, currencyFormat),
                      const SizedBox(height: 24),
                      _buildTopCompaniesChart(analytics, currencyFormat),
                    ],
                  ),
                  desktop: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildMonthlyRevenueChart(
                          analytics,
                          currencyFormat,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _buildTopCompaniesChart(
                          analytics,
                          currencyFormat,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildFilterChildren({
    bool isRow = false,
    int? selectedYear,
    int? selectedMonth,
  }) {
    final children = [
      Expanded(
        child: DropdownButtonFormField<int>(
          initialValue: selectedYear,
          decoration: const InputDecoration(
            labelText: 'Year',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: List.generate(5, (index) {
            final year = DateTime.now().year - 2 + index;
            return DropdownMenuItem(value: year, child: Text(year.toString()));
          }),
          onChanged: (value) {
            if (value != null) {
              _selectedYear.value = value;
              _loadData();
            }
          },
        ),
      ),
      if (!isRow) const SizedBox(height: 16) else const SizedBox(width: 16),
      Expanded(
        child: DropdownButtonFormField<int?>(
          initialValue: selectedMonth,
          decoration: const InputDecoration(
            labelText: 'Month (Optional)',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('All Months')),
            ...List.generate(12, (index) {
              return DropdownMenuItem(
                value: index + 1,
                child: Text(
                  DateFormat('MMMM').format(DateTime(2024, index + 1)),
                ),
              );
            }),
          ],
          onChanged: (value) {
            _selectedMonth.value = value;
            _loadData();
          },
        ),
      ),
    ];

    return children;
  }

  List<Widget> _buildSummaryCards(
    AnalyticsEntity analytics,
    NumberFormat currencyFormat, {
    bool isRow = false,
  }) {
    final children = [
      _buildSummaryCard(
        'Total Revenue',
        currencyFormat.format(analytics.totalRevenue),
        Icons.attach_money,
        Colors.green,
      ),
      if (!isRow) const SizedBox(height: 16) else const SizedBox(width: 16),
      _buildSummaryCard(
        'Total Invoices',
        analytics.invoiceCount.toString(),
        Icons.receipt_long,
        Colors.blue,
      ),
      if (!isRow) const SizedBox(height: 16) else const SizedBox(width: 16),
      _buildSummaryCard(
        'Average Invoice',
        currencyFormat.format(analytics.averageInvoiceValue),
        Icons.trending_up,
        Colors.orange,
      ),
      if (!isRow) const SizedBox(height: 16) else const SizedBox(width: 16),
      _buildSummaryCard(
        'Total Tax',
        currencyFormat.format(analytics.totalTax),
        Icons.account_balance,
        Colors.purple,
      ),
    ];

    if (isRow) {
      return children
          .map((c) => c is SizedBox ? c : Expanded(child: c))
          .toList();
    }
    return children;
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyRevenueChart(
    AnalyticsEntity analytics,
    NumberFormat currencyFormat,
  ) {
    // Sort to ensure the order is correct for the chart (oldest to newest)
    final sortedRevenue = List.of(analytics.monthlyRevenue)
      ..sort(
        (a, b) =>
            DateTime(a.year, a.month).compareTo(DateTime(b.year, b.month)),
      );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Revenue',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: sortedRevenue.isEmpty
                      ? 100
                      : sortedRevenue
                                .map((e) => e.revenue)
                                .reduce((a, b) => a > b ? a : b) *
                            1.2,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => Colors.blueGrey,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          currencyFormat.format(rod.toY),
                          const TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value < 0 || value >= sortedRevenue.length) {
                            return const Text('');
                          }
                          final item = sortedRevenue[value.toInt()];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              DateFormat(
                                'MMM',
                              ).format(DateTime(item.year, item.month)),
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            NumberFormat.compact().format(value),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: sortedRevenue.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.revenue,
                          color: Colors.blue,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCompaniesChart(
    AnalyticsEntity analytics,
    NumberFormat currencyFormat,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Companies',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: analytics.topCompanies.isEmpty
                  ? const Center(child: Text('No data available'))
                  : PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: analytics.topCompanies.asMap().entries.map((
                          entry,
                        ) {
                          final index = entry.key;
                          final company = entry.value;
                          final colors = [
                            Colors.blue,
                            Colors.red,
                            Colors.green,
                            Colors.orange,
                            Colors.purple,
                          ];
                          return PieChartSectionData(
                            color: colors[index % colors.length],
                            value: company.revenue,
                            title: analytics.totalRevenue > 0
                                ? '${(company.revenue / analytics.totalRevenue * 100).toStringAsFixed(0)}%'
                                : '0%',
                            radius: 100,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            if (analytics.topCompanies.isNotEmpty)
              Column(
                children: analytics.topCompanies.asMap().entries.map((entry) {
                  final index = entry.key;
                  final company = entry.value;
                  final colors = [
                    Colors.blue,
                    Colors.red,
                    Colors.green,
                    Colors.orange,
                    Colors.purple,
                  ];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: colors[index % colors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            company.companyName,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          currencyFormat.format(company.revenue),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
