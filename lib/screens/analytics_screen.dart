import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/invoice_model.dart';
import '../models/company_model.dart';
import '../services/database_service.dart';
import '../widgets/responsive_layout.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isLoading = true;
  int? _selectedMonth;
  int? _selectedYear;

  // Analytics Data
  double _totalRevenue = 0;
  int _totalInvoices = 0;
  double _averageInvoiceValue = 0;
  double _totalTax = 0;
  Map<int, double> _monthlyRevenue = {};
  Map<String, double> _topCompanies = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final analytics = await DatabaseService.instance.getAnalytics(
        month: _selectedMonth,
        year: _selectedYear,
      );

      setState(() {
        _totalRevenue = (analytics['totalRevenue'] as num?)?.toDouble() ?? 0;
        _totalInvoices = (analytics['invoiceCount'] as num?)?.toInt() ?? 0;
        _averageInvoiceValue =
            (analytics['averageInvoiceValue'] as num?)?.toDouble() ?? 0;
        _totalTax = (analytics['totalTax'] as num?)?.toDouble() ?? 0;

        // Process monthly revenue
        _monthlyRevenue = {};
        final monthlyData = analytics['monthlyRevenue'] as List? ?? [];
        for (var item in monthlyData) {
          if (item is Map) {
            final month = (item['month'] as num?)?.toInt();
            final revenue = (item['revenue'] as num?)?.toDouble();
            if (month != null && revenue != null) {
              _monthlyRevenue[month] = revenue;
            }
          }
        }

        // Process top companies
        _topCompanies = {};
        final topCompaniesData = analytics['topCompanies'] as List? ?? [];
        for (var item in topCompaniesData) {
          if (item is Map) {
            final company = item['company'];
            final revenue = (item['revenue'] as num?)?.toDouble();
            if (company != null && revenue != null) {
              String name = 'Unknown';
              if (company is CompanyModel) {
                name = company.companyName;
              } else if (company is Map) {
                name = company['companyName']?.toString() ?? 'Unknown';
              }
              _topCompanies[name] = revenue;
            }
          }
        }

        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filters
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ResponsiveLayout(
                        mobile: Column(children: _buildFilterChildren()),
                        desktop: Row(
                          children: _buildFilterChildren(isRow: true),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Summary Cards
                  ResponsiveLayout(
                    mobile: Column(
                      children: _buildSummaryCards(currencyFormat),
                    ),
                    desktop: Row(
                      children: _buildSummaryCards(currencyFormat, isRow: true),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Charts
                  ResponsiveLayout(
                    mobile: Column(
                      children: [
                        _buildMonthlyRevenueChart(currencyFormat),
                        const SizedBox(height: 24),
                        _buildTopCompaniesChart(currencyFormat),
                      ],
                    ),
                    desktop: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildMonthlyRevenueChart(currencyFormat),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _buildTopCompaniesChart(currencyFormat),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildFilterChildren({bool isRow = false}) {
    final children = [
      Expanded(
        child: DropdownButtonFormField<int>(
          value: _selectedYear,
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
              setState(() => _selectedYear = value);
              _loadData();
            }
          },
        ),
      ),
      if (!isRow) const SizedBox(height: 16) else const SizedBox(width: 16),
      Expanded(
        child: DropdownButtonFormField<int?>(
          value: _selectedMonth,
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
            setState(() => _selectedMonth = value);
            _loadData();
          },
        ),
      ),
    ];

    return children;
  }

  List<Widget> _buildSummaryCards(
    NumberFormat currencyFormat, {
    bool isRow = false,
  }) {
    final children = [
      _buildSummaryCard(
        'Total Revenue',
        currencyFormat.format(_totalRevenue),
        Icons.attach_money,
        Colors.green,
      ),
      if (!isRow) const SizedBox(height: 16) else const SizedBox(width: 16),
      _buildSummaryCard(
        'Total Invoices',
        _totalInvoices.toString(),
        Icons.receipt_long,
        Colors.blue,
      ),
      if (!isRow) const SizedBox(height: 16) else const SizedBox(width: 16),
      _buildSummaryCard(
        'Average Invoice',
        currencyFormat.format(_averageInvoiceValue),
        Icons.trending_up,
        Colors.orange,
      ),
      if (!isRow) const SizedBox(height: 16) else const SizedBox(width: 16),
      _buildSummaryCard(
        'Total Tax',
        currencyFormat.format(_totalTax),
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

  Widget _buildMonthlyRevenueChart(NumberFormat currencyFormat) {
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
                  maxY: _monthlyRevenue.values.isEmpty
                      ? 100
                      : _monthlyRevenue.values.reduce((a, b) => a > b ? a : b) *
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
                          if (value < 1 || value > 12) return const Text('');
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              DateFormat(
                                'MMM',
                              ).format(DateTime(2024, value.toInt())),
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
                  barGroups: _monthlyRevenue.entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value,
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

  Widget _buildTopCompaniesChart(NumberFormat currencyFormat) {
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
              child: _topCompanies.isEmpty
                  ? const Center(child: Text('No data available'))
                  : PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: _topCompanies.entries.map((entry) {
                          final index = _topCompanies.keys.toList().indexOf(
                            entry.key,
                          );
                          final colors = [
                            Colors.blue,
                            Colors.red,
                            Colors.green,
                            Colors.orange,
                            Colors.purple,
                          ];
                          return PieChartSectionData(
                            color: colors[index % colors.length],
                            value: entry.value,
                            title: _totalRevenue > 0
                                ? '${(entry.value / _totalRevenue * 100).toStringAsFixed(0)}%'
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
            if (_topCompanies.isNotEmpty)
              Column(
                children: _topCompanies.entries.map((entry) {
                  final index = _topCompanies.keys.toList().indexOf(entry.key);
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
                            entry.key,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          currencyFormat.format(entry.value),
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
