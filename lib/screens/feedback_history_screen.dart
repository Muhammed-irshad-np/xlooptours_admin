import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../features/customer/domain/entities/customer_entity.dart';
import '../features/customer/presentation/providers/customer_provider.dart';
import '../features/employee/presentation/providers/employee_provider.dart';
import '../features/employee/domain/entities/employee_entity.dart';
import '../features/feedback/domain/entities/feedback_entity.dart';
import '../features/feedback/presentation/providers/feedback_provider.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../widgets/responsive_layout.dart';

class FeedbackHistoryScreen extends StatefulWidget {
  const FeedbackHistoryScreen({super.key});

  @override
  State<FeedbackHistoryScreen> createState() => _FeedbackHistoryScreenState();
}

class _FeedbackHistoryScreenState extends State<FeedbackHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Filters
  bool _onlyIncidents = false;
  String? _selectedDriver;
  String? _selectedCustomer;
  DateTimeRange? _selectedDateRange;
  double _minRating = 0.0;

  // Design Tokens consistent with dashboard_screen.dart
  static const Color _bgPage = Color(0xFFF4F6FB);
  static const Color _bgCard = Colors.white;
  static const Color _brand = Color(0xFF4F46E5);
  static const Color _danger = Color(0xFFDC2626);
  static const Color _dangerBg = Color(0xFFFFF1F2);
  static const Color _dangerBorder = Color(0xFFFFCDD2);
  static const Color _warning = Color(0xFFD97706);
  static const Color _textPrimary = Color(0xFF111827);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _textMuted = Color(0xFF9CA3AF);
  static const Color _border = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeedbackProvider>().fetchLatestFeedbacks(limit: 100);
    });
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  double _calculateAverageRating(FeedbackEntity f) {
    return (f.safetyRating +
            f.professionalismRating +
            f.communicationRating +
            f.punctualityRating +
            f.vehicleConditionRating) /
        5.0;
  }

  void _showFilterSheet(List<FeedbackEntity> allFeedbacks) {
    final drivers = allFeedbacks.map((e) => e.driverName).toSet().toList()
      ..sort();
    final customers = allFeedbacks.map((e) => e.clientName).toSet().toList()
      ..sort();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filter Feedbacks',
                          style: GoogleFonts.inter(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: _textPrimary,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedDriver = null;
                              _selectedCustomer = null;
                              _selectedDateRange = null;
                              _minRating = 0.0;
                              _onlyIncidents = false;
                            });
                            setSheetState(() {});
                          },
                          child: Text(
                            'Reset',
                            style: GoogleFonts.inter(
                              color: _brand,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20.h),
                    // Driver Dropdown
                    _buildDropdown(
                      label: 'Driver',
                      value: _selectedDriver,
                      items: drivers,
                      onChanged: (val) {
                        setState(() => _selectedDriver = val);
                        setSheetState(() {});
                      },
                    ),
                    SizedBox(height: 16.h),
                    // Customer Dropdown
                    _buildDropdown(
                      label: 'Customer',
                      value: _selectedCustomer,
                      items: customers,
                      onChanged: (val) {
                        setState(() => _selectedCustomer = val);
                        setSheetState(() {});
                      },
                    ),
                    SizedBox(height: 16.h),
                    // Date Range
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trip Date Range',
                          style: GoogleFonts.inter(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: _textSecondary,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        InkWell(
                          onTap: () async {
                            final range = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              initialDateRange: _selectedDateRange,
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: _brand,
                                      onPrimary: Colors.white,
                                      onSurface: _textPrimary,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (range != null) {
                              setState(() => _selectedDateRange = range);
                              setSheetState(() {});
                            }
                          },
                          borderRadius: BorderRadius.circular(10.r),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 14.h,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: _border),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 18.sp,
                                  color: _textSecondary,
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  _selectedDateRange != null
                                      ? '${DateFormat('MMM d').format(_selectedDateRange!.start)} - ${DateFormat('MMM d, y').format(_selectedDateRange!.end)}'
                                      : 'Select Date Range',
                                  style: GoogleFonts.inter(
                                    fontSize: 14.sp,
                                    color: _selectedDateRange != null
                                        ? _textPrimary
                                        : _textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    // Min Rating Slider
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Minimum Average Rating',
                              style: GoogleFonts.inter(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                                color: _textSecondary,
                              ),
                            ),
                            Text(
                              _minRating > 0
                                  ? '${_minRating.toStringAsFixed(1)}+'
                                  : 'Any',
                              style: GoogleFonts.inter(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.bold,
                                color: _brand,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _minRating,
                          min: 0,
                          max: 5,
                          divisions: 10,
                          activeColor: _brand,
                          onChanged: (val) {
                            setState(() => _minRating = val);
                            setSheetState(() {});
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 24.h),
                    SizedBox(
                      width: double.infinity,
                      height: 48.h,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brand,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Apply Filters',
                          style: GoogleFonts.inter(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: _textSecondary,
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          decoration: BoxDecoration(
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              hint: Text('All', style: GoogleFonts.inter(color: _textMuted)),
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text(
                    'All',
                    style: GoogleFonts.inter(color: _textPrimary),
                  ),
                ),
                ...items.map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(
                      e,
                      style: GoogleFonts.inter(color: _textPrimary),
                    ),
                  ),
                ),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().user?.isAdmin ?? false;
    if (!isAdmin) {
      return Scaffold(
        backgroundColor: _bgPage,
        appBar: AppBar(
          title: Text(
            'Feedback History',
            style: GoogleFonts.inter(
              color: _textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 64,
                color: _danger,
              ),
              const SizedBox(height: 16),
              Text(
                'Access Denied',
                style: GoogleFonts.inter(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Only administrators are allowed to view this screen.',
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bgPage,
      appBar: _buildAppBar(),
      body: Consumer<FeedbackProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingFeedbacks) {
            return const Center(
              child: CircularProgressIndicator(color: _brand),
            );
          }

          final feedbacks = provider.latestFeedbacks;

          if (feedbacks.isEmpty) {
            return _buildEmptyState();
          }

          // Filter feedbacks
          final filteredFeedbacks = feedbacks.where((f) {
            final matchesQuery =
                f.clientName.toLowerCase().contains(_searchQuery) ||
                f.driverName.toLowerCase().contains(_searchQuery) ||
                (f.areasOfExcellence?.toLowerCase().contains(_searchQuery) ??
                    false) ||
                (f.areasOfImprovement?.toLowerCase().contains(_searchQuery) ??
                    false);
            final matchesIncident = !_onlyIncidents || f.incidentReported;
            final matchesDriver =
                _selectedDriver == null || f.driverName == _selectedDriver;
            final matchesCustomer =
                _selectedCustomer == null || f.clientName == _selectedCustomer;
            final matchesMinRating = _calculateAverageRating(f) >= _minRating;

            bool matchesDate = true;
            if (_selectedDateRange != null) {
              matchesDate =
                  f.dateOfTrip.isAfter(
                    _selectedDateRange!.start.subtract(const Duration(days: 1)),
                  ) &&
                  f.dateOfTrip.isBefore(
                    _selectedDateRange!.end.add(const Duration(days: 1)),
                  );
            }

            return matchesQuery &&
                matchesIncident &&
                matchesDriver &&
                matchesCustomer &&
                matchesMinRating &&
                matchesDate;
          }).toList();

          return Column(
            children: [
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: _brand,
                  indicatorWeight: 3,
                  labelColor: _brand,
                  unselectedLabelColor: _textSecondary,
                  labelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                  unselectedLabelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                    fontSize: 14.sp,
                  ),
                  tabs: const [
                    Tab(text: 'Feedback List'),
                    Tab(text: 'Evaluation Dashboard'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildListView(filteredFeedbacks, feedbacks),
                    _buildEvaluationDashboard(filteredFeedbacks),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showGenerateFeedbackLinkDialog() {
    showDialog(
      context: context,
      builder: (context) => const _GenerateFeedbackLinkDialog(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      title: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(
              Icons.rate_review_rounded,
              color: Colors.white,
              size: 20.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Text(
            'Customer Feedbacks',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 22.sp,
              color: _textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _brand,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
              elevation: 0,
            ),
            onPressed: _showGenerateFeedbackLinkDialog,
            icon: Icon(Icons.link, size: 18.sp),
            label: Text(
              'Generate Link',
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(1.h),
        child: Container(height: 1.h, color: _border),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: _brand.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.rate_review_outlined, size: 48.sp, color: _brand),
          ),
          SizedBox(height: 20.h),
          Text(
            'No feedback received yet',
            style: GoogleFonts.inter(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Generate custom links from the customer registry to share with clients.',
            style: GoogleFonts.inter(fontSize: 14.sp, color: _textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ==== TAB 1: LIST VIEW ====
  Widget _buildListView(
    List<FeedbackEntity> filteredFeedbacks,
    List<FeedbackEntity> allFeedbacks,
  ) {
    final totalCount = filteredFeedbacks.length;
    final incidentCount = filteredFeedbacks
        .where((f) => f.incidentReported)
        .length;
    double overallSum = 0;
    for (var f in filteredFeedbacks) {
      overallSum += _calculateAverageRating(f);
    }
    final averageRating = totalCount > 0 ? overallSum / totalCount : 0.0;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 40.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnalyticsCards(
            total: totalCount,
            average: averageRating,
            incidents: incidentCount,
          ),
          SizedBox(height: 32.h),
          _buildSearchAndFilters(allFeedbacks),
          SizedBox(height: 20.h),
          _buildFeedbackList(filteredFeedbacks),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCards({
    required int total,
    required double average,
    required int incidents,
  }) {
    final cards = [
      _AnalyticsItem(
        label: 'Total Feedback',
        value: total.toString(),
        icon: Icons.chat_bubble_outline_rounded,
        color: _brand,
      ),
      _AnalyticsItem(
        label: 'Average Score',
        value: '${average.toStringAsFixed(1)} / 5.0',
        icon: Icons.star_border_rounded,
        color: _warning,
        isStars: true,
        starsVal: average,
      ),
      _AnalyticsItem(
        label: 'Incidents Flagged',
        value: incidents.toString(),
        icon: Icons.warning_amber_rounded,
        color: _danger,
        isWarning: incidents > 0,
      ),
    ];

    return ResponsiveLayout(
      mobile: Column(
        children: cards
            .map(
              (c) => Padding(
                padding: EdgeInsets.only(bottom: 16.h),
                child: _AnalyticsCard(item: c),
              ),
            )
            .toList(),
      ),
      tablet: Wrap(
        spacing: 16.w,
        runSpacing: 16.h,
        children: cards
            .map(
              (c) => SizedBox(
                width: 240.w,
                child: _AnalyticsCard(item: c),
              ),
            )
            .toList(),
      ),
      desktop: Row(
        children:
            cards
                .expand(
                  (c) => [
                    Expanded(child: _AnalyticsCard(item: c)),
                    SizedBox(width: 20.w),
                  ],
                )
                .toList()
              ..removeLast(),
      ),
    );
  }

  Widget _buildSearchAndFilters(List<FeedbackEntity> allFeedbacks) {
    int activeFiltersCount = 0;
    if (_onlyIncidents) activeFiltersCount++;
    if (_selectedDriver != null) activeFiltersCount++;
    if (_selectedCustomer != null) activeFiltersCount++;
    if (_selectedDateRange != null) activeFiltersCount++;
    if (_minRating > 0) activeFiltersCount++;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          // Search Field
          Expanded(
            child: Container(
              height: 48.h,
              decoration: BoxDecoration(
                color: _bgPage,
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: _border),
              ),
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: _textMuted, size: 20.sp),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search query...',
                        hintStyle: GoogleFonts.inter(
                          color: _textMuted,
                          fontSize: 14.sp,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      style: GoogleFonts.inter(
                        color: _textPrimary,
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        Icons.clear_rounded,
                        size: 18.sp,
                        color: _textMuted,
                      ),
                      onPressed: () => _searchController.clear(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(width: 12.w),
          // Filter Button
          InkWell(
            onTap: () => _showFilterSheet(allFeedbacks),
            borderRadius: BorderRadius.circular(10.r),
            child: Container(
              height: 48.h,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              decoration: BoxDecoration(
                color: activeFiltersCount > 0
                    ? _brand.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: activeFiltersCount > 0 ? _brand : _border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.filter_list_rounded,
                    color: activeFiltersCount > 0 ? _brand : _textSecondary,
                    size: 18.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Filters',
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      fontWeight: activeFiltersCount > 0
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: activeFiltersCount > 0 ? _brand : _textSecondary,
                    ),
                  ),
                  if (activeFiltersCount > 0) ...[
                    SizedBox(width: 6.w),
                    Container(
                      padding: EdgeInsets.all(4.w),
                      decoration: const BoxDecoration(
                        color: _brand,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        activeFiltersCount.toString(),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackList(List<FeedbackEntity> filteredFeedbacks) {
    if (filteredFeedbacks.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 48.h),
        decoration: BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, color: _textMuted, size: 40.sp),
            SizedBox(height: 12.h),
            Text(
              'No matches found',
              style: GoogleFonts.inter(
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
                color: _textSecondary,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Try clearing your search query or toggling filters.',
              style: GoogleFonts.inter(color: _textMuted, fontSize: 13.sp),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredFeedbacks.length,
      separatorBuilder: (_, __) => SizedBox(height: 16.h),
      itemBuilder: (context, index) {
        return _FeedbackTile(
          feedback: filteredFeedbacks[index],
          avgRating: _calculateAverageRating(filteredFeedbacks[index]),
        );
      },
    );
  }

  // ==== TAB 2: EVALUATION DASHBOARD ====
  Widget _buildEvaluationDashboard(List<FeedbackEntity> filteredFeedbacks) {
    if (filteredFeedbacks.isEmpty) {
      return Center(
        child: Text(
          'No data to evaluate based on current filters.',
          style: GoogleFonts.inter(color: _textSecondary, fontSize: 14.sp),
        ),
      );
    }

    double safety = 0;
    double professionalism = 0;
    double communication = 0;
    double punctuality = 0;
    double vehicle = 0;

    Map<String, List<double>> driverRatings = {};

    for (var f in filteredFeedbacks) {
      safety += f.safetyRating;
      professionalism += f.professionalismRating;
      communication += f.communicationRating;
      punctuality += f.punctualityRating;
      vehicle += f.vehicleConditionRating;

      final avg = _calculateAverageRating(f);
      driverRatings.putIfAbsent(f.driverName, () => []).add(avg);
    }

    final total = filteredFeedbacks.length;
    safety /= total;
    professionalism /= total;
    communication /= total;
    punctuality /= total;
    vehicle /= total;

    // Driver averages
    List<MapEntry<String, double>> driverAvg = [];
    for (var entry in driverRatings.entries) {
      final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
      driverAvg.add(MapEntry(entry.key, avg));
    }
    driverAvg.sort((a, b) => b.value.compareTo(a.value)); // descending

    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overall Category Averages',
            style: GoogleFonts.inter(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: _bgCard,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: _border),
            ),
            child: Column(
              children: [
                _buildBarChartRow('Safety', safety),
                SizedBox(height: 16.h),
                _buildBarChartRow('Professionalism', professionalism),
                SizedBox(height: 16.h),
                _buildBarChartRow('Communication', communication),
                SizedBox(height: 16.h),
                _buildBarChartRow('Punctuality', punctuality),
                SizedBox(height: 16.h),
                _buildBarChartRow('Vehicle Cleanliness', vehicle),
              ],
            ),
          ),
          SizedBox(height: 32.h),
          Text(
            'Driver Leaderboard (Average Rating)',
            style: GoogleFonts.inter(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
          ),
          SizedBox(height: 16.h),
          Container(
            decoration: BoxDecoration(
              color: _bgCard,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: _border),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: driverAvg.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = driverAvg[index];
                final isTop = index < 3;
                return ListTile(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 24.w,
                    vertical: 8.h,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: isTop
                        ? _warning.withOpacity(0.1)
                        : _bgPage,
                    child: Text(
                      '#${index + 1}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: isTop ? _warning : _textSecondary,
                      ),
                    ),
                  ),
                  title: Text(
                    entry.key,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        color: Colors.amber[600],
                        size: 18.sp,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        entry.value.toStringAsFixed(1),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.sp,
                          color: _textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChartRow(String label, double value) {
    return Row(
      children: [
        SizedBox(
          width: 140.w,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: _textSecondary,
            ),
          ),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 12.h,
                decoration: BoxDecoration(
                  color: _bgPage,
                  borderRadius: BorderRadius.circular(6.r),
                ),
              ),
              FractionallySizedBox(
                widthFactor: value / 5.0,
                child: Container(
                  height: 12.h,
                  decoration: BoxDecoration(
                    color: _brand,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 16.w),
        SizedBox(
          width: 40.w,
          child: Text(
            value.toStringAsFixed(1),
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _AnalyticsItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isStars;
  final double starsVal;
  final bool isWarning;

  const _AnalyticsItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isStars = false,
    this.starsVal = 0,
    this.isWarning = false,
  });
}

class _AnalyticsCard extends StatelessWidget {
  final _AnalyticsItem item;

  const _AnalyticsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: item.isWarning
              ? Colors.red.withOpacity(0.3)
              : const Color(0xFFE5E7EB),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: item.color, size: 24.sp),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.label,
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      item.value,
                      style: GoogleFonts.inter(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    if (item.isStars && item.starsVal > 0) ...[
                      SizedBox(width: 8.w),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (index) {
                          final isActive = index < item.starsVal.round();
                          return Icon(
                            isActive ? Icons.star : Icons.star_border,
                            color: isActive
                                ? Colors.amber[600]
                                : Colors.grey[300],
                            size: 14.sp,
                          );
                        }),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackTile extends StatefulWidget {
  final FeedbackEntity feedback;
  final double avgRating;

  const _FeedbackTile({required this.feedback, required this.avgRating});

  @override
  State<_FeedbackTile> createState() => _FeedbackTileState();
}

class _FeedbackTileState extends State<_FeedbackTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.feedback;
    final hasDetails =
        f.areasOfExcellence != null || f.areasOfImprovement != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: f.incidentReported
              ? const Color(0xFFDC2626).withOpacity(0.3)
              : const Color(0xFFE5E7EB),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card Details
          Padding(
            padding: EdgeInsets.all(20.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22.r,
                  backgroundColor: f.incidentReported
                      ? const Color(0xFFFFF1F2)
                      : const Color(0xFFF0FDF4),
                  child: Text(
                    f.clientName.isNotEmpty
                        ? f.clientName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: f.incidentReported
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF16A34A),
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  f.clientName,
                                  style: GoogleFonts.inter(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF111827),
                                  ),
                                ),
                                if (f.submitterName != null &&
                                    f.submitterName!.isNotEmpty) ...[
                                  SizedBox(height: 2.h),
                                  Text(
                                    'Client: ${f.submitterName}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF4F46E5),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (f.incidentReported) ...[
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1F2),
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(
                                  color: const Color(0xFFFFCDD2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: const Color(0xFFDC2626),
                                    size: 12.sp,
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    'Incident Reported',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFDC2626),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Wrap(
                        spacing: 16.w,
                        runSpacing: 6.h,
                        children: [
                          _buildMetaChip(
                            icon: Icons.person_outline_rounded,
                            label: 'Driver: ${f.driverName}',
                          ),
                          _buildMetaChip(
                            icon: Icons.calendar_today_outlined,
                            label:
                                'Trip: ${DateFormat('dd-MM-yyyy').format(f.dateOfTrip)}',
                          ),
                          _buildMetaChip(
                            icon: Icons.access_time_rounded,
                            label: timeago.format(f.createdAt),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: Colors.amber[600],
                          size: 20.sp,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          widget.avgRating.toStringAsFixed(1),
                          style: GoogleFonts.inter(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        Text(
                          ' / 5',
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            color: const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    IconButton(
                      icon: Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: const Color(0xFF6B7280),
                      ),
                      onPressed: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isExpanded) ...[
            Container(height: 1.h, color: const Color(0xFFF3F4F6)),
            Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (f.incidentReported) ...[
                    Container(
                      padding: EdgeInsets.all(16.w),
                      margin: EdgeInsets.only(bottom: 20.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        border: Border.all(color: const Color(0xFFFFCDD2)),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: const Color(0xFFDC2626),
                                size: 18.sp,
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                'Reported Incident Details',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFDC2626),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.sp,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            f.incidentDescription ?? 'No details provided.',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF991B1B),
                              fontSize: 13.sp,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Text(
                    'SERVICE RATINGS BREAKDOWN',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  ResponsiveLayout(
                    mobile: Column(
                      children: [
                        _buildBreakdownTile('Safety', f.safetyRating),
                        _buildBreakdownTile(
                          'Professionalism',
                          f.professionalismRating,
                        ),
                        _buildBreakdownTile(
                          'Communication',
                          f.communicationRating,
                        ),
                        _buildBreakdownTile('Punctuality', f.punctualityRating),
                        _buildBreakdownTile(
                          'Vehicle Cleanliness',
                          f.vehicleConditionRating,
                        ),
                      ],
                    ),
                    desktop: Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _buildBreakdownTile('Safety', f.safetyRating),
                              _buildBreakdownTile(
                                'Professionalism',
                                f.professionalismRating,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 32.w),
                        Expanded(
                          child: Column(
                            children: [
                              _buildBreakdownTile(
                                'Communication',
                                f.communicationRating,
                              ),
                              _buildBreakdownTile(
                                'Punctuality',
                                f.punctualityRating,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 32.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              _buildBreakdownTile(
                                'Vehicle Cleanliness',
                                f.vehicleConditionRating,
                              ),
                              const SizedBox(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasDetails) ...[
                    SizedBox(height: 20.h),
                    const Divider(),
                    SizedBox(height: 16.h),
                    if (f.areasOfExcellence != null) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.star,
                            color: const Color(0xFF16A34A),
                            size: 16.sp,
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Areas of Excellence',
                                  style: GoogleFonts.inter(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF16A34A),
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  f.areasOfExcellence!,
                                  style: GoogleFonts.inter(
                                    fontSize: 13.sp,
                                    height: 1.5,
                                    color: const Color(0xFF4B5563),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (f.areasOfImprovement != null) SizedBox(height: 16.h),
                    ],
                    if (f.areasOfImprovement != null) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: const Color(0xFFDC2626),
                            size: 16.sp,
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Areas of Improvement',
                                  style: GoogleFonts.inter(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFDC2626),
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  f.areasOfImprovement!,
                                  style: GoogleFonts.inter(
                                    fontSize: 13.sp,
                                    height: 1.5,
                                    color: const Color(0xFF4B5563),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaChip({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF9CA3AF), size: 14.sp),
        SizedBox(width: 6.w),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownTile(String label, int val) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                color: const Color(0xFF4B5563),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: val / 5.0,
                    backgroundColor: const Color(0xFFF3F4F6),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      val >= 4
                          ? const Color(0xFF16A34A)
                          : (val >= 3
                                ? const Color(0xFFD97706)
                                : const Color(0xFFDC2626)),
                    ),
                    minHeight: 6.h,
                    borderRadius: BorderRadius.circular(3.r),
                  ),
                ),
                SizedBox(width: 12.w),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (idx) {
                    return Icon(
                      idx < val
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: idx < val ? Colors.amber[600] : Colors.grey[300],
                      size: 14.sp,
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GenerateFeedbackLinkDialog extends StatefulWidget {
  const _GenerateFeedbackLinkDialog();

  @override
  State<_GenerateFeedbackLinkDialog> createState() => _GenerateFeedbackLinkDialogState();
}

class _GenerateFeedbackLinkDialogState extends State<_GenerateFeedbackLinkDialog> {
  final TextEditingController _customerSearchController = TextEditingController();
  final TextEditingController _driverSearchController = TextEditingController();
  String _customerQuery = '';
  String _driverQuery = '';

  CustomerEntity? _selectedCustomer;
  EmployeeEntity? _selectedDriver;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().fetchAllCustomers();
      context.read<EmployeeProvider>().fetchAllEmployees();
    });
    _customerSearchController.addListener(() {
      setState(() {
        _customerQuery = _customerSearchController.text.trim();
      });
    });
    _driverSearchController.addListener(() {
      setState(() {
        _driverQuery = _driverSearchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _customerSearchController.dispose();
    _driverSearchController.dispose();
    super.dispose();
  }

  String _generateFeedbackUrl(CustomerEntity customer, EmployeeEntity driver) {
    final currentUrl = Uri.base.toString();
    final baseUrl = currentUrl.contains('#')
        ? currentUrl.substring(0, currentUrl.indexOf('#'))
        : currentUrl;
    final finalBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    final uri = Uri.parse(finalBaseUrl);
    final hostUrl = '${uri.scheme}://${uri.host}${uri.hasPort ? ":${uri.port}" : ""}';
    final clientNameEncoded = Uri.encodeComponent(customer.name);
    final companyNameEncoded = customer.companyName != null ? Uri.encodeComponent(customer.companyName!) : '';
    final driverNameEncoded = Uri.encodeComponent(driver.fullName);
    return '$hostUrl/feedback?clientName=$clientNameEncoded&companyName=$companyNameEncoded&driverName=$driverNameEncoded';
  }

  Future<void> _shareToWhatsApp(CustomerEntity customer, EmployeeEntity driver, String url) async {
    String country = driver.countryCode ?? '';
    country = country.replaceAll(RegExp(r'[^0-9]'), '');
    if (country.isEmpty) country = '966'; // Default KSA country code
    String phone = driver.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.startsWith('0')) {
      phone = phone.substring(1);
    }
    final cleanPhone = '$country$phone';

    final text = 'Hi ${driver.fullName},\n\nPlease ask the customer (${customer.name}) to fill out their feedback using this link:\n\n$url';
    final whatsappUrl = 'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(text)}';
    
    final Uri uri = Uri.parse(whatsappUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch WhatsApp link');
    }
  }

  Future<void> _shareViaEmail(CustomerEntity customer, EmployeeEntity driver, String url) async {
    final subject = Uri.encodeComponent('Feedback Link for Customer ${customer.name}');
    final body = Uri.encodeComponent(
      'Hi ${driver.fullName},\n\nPlease share this link with the customer (${customer.name}) to collect their feedback:\n\n$url\n\nBest regards,\nAdmin Team',
    );
    final emailUrl = 'mailto:${driver.email}?subject=$subject&body=$body';
    final Uri uri = Uri.parse(emailUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch Email link');
    }
  }

  Future<void> _copyToClipboard(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Feedback link copied to clipboard!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedCustomer != null && _selectedDriver != null) {
      return _buildShareDialog(_selectedCustomer!, _selectedDriver!);
    }

    if (_selectedCustomer != null) {
      return _buildSelectDriverDialog(_selectedCustomer!);
    }

    return _buildSelectCustomerDialog();
  }

  Widget _buildSelectCustomerDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        width: 500.w,
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Generate Feedback Link',
                  style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              'Step 1 of 2: Select a customer to generate a unique feedback link.',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
            ),
            Divider(height: 32.h),
            // Search field
            TextField(
              controller: _customerSearchController,
              decoration: InputDecoration(
                hintText: 'Search customer by name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _customerQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _customerSearchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              ),
            ),
            SizedBox(height: 16.h),
            // Customers List
            Flexible(
              child: Consumer<CustomerProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.w),
                        child: const CircularProgressIndicator(),
                      ),
                    );
                  }

                  final activeCustomers = provider.customers
                      .where((c) => c.status == 'ACTIVE')
                      .toList();

                  final filteredCustomers = activeCustomers.where((c) {
                    return c.name.toLowerCase().contains(_customerQuery.toLowerCase()) ||
                        (c.companyName?.toLowerCase().contains(_customerQuery.toLowerCase()) ?? false);
                  }).toList();

                  if (filteredCustomers.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.w),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline, size: 48.sp, color: Colors.grey[400]),
                            SizedBox(height: 8.h),
                            Text(
                              'No active customers found',
                              style: TextStyle(color: Colors.grey[600], fontSize: 15.sp),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: filteredCustomers.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final customer = filteredCustomers[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF4F46E5).withOpacity(0.1),
                            child: Text(
                              customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'C',
                              style: const TextStyle(
                                color: Color(0xFF4F46E5),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            customer.name,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          subtitle: Text(
                            customer.companyName != null && customer.companyName!.isNotEmpty
                                ? '${customer.companyName} • ${customer.phone}'
                                : customer.phone,
                            style: TextStyle(color: Colors.grey[500], fontSize: 13.sp),
                          ),
                          onTap: () {
                            setState(() {
                              _selectedCustomer = customer;
                            });
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectDriverDialog(CustomerEntity customer) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        width: 500.w,
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Driver',
                  style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Text(
                  'Customer: ',
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
                ),
                Text(
                  customer.name,
                  style: TextStyle(fontSize: 14.sp, color: const Color(0xFF4F46E5), fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedCustomer = null;
                    });
                  },
                  child: const Text('Change'),
                ),
              ],
            ),
            Text(
              'Step 2 of 2: Select a driver to generate the unique feedback link.',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
            ),
            Divider(height: 20.h),
            // Search field
            TextField(
              controller: _driverSearchController,
              decoration: InputDecoration(
                hintText: 'Search driver by name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _driverQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _driverSearchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              ),
            ),
            SizedBox(height: 16.h),
            // Drivers List
            Flexible(
              child: Consumer<EmployeeProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.w),
                        child: const CircularProgressIndicator(),
                      ),
                    );
                  }

                  final allEmployees = provider.employees;
                  final drivers = allEmployees.where((e) =>
                      e.isActive &&
                      (e.position.toLowerCase().contains('driver') ||
                          e.driverType != null)).toList();

                  final filteredDrivers = drivers.where((driver) {
                    return driver.fullName.toLowerCase().contains(_driverQuery.toLowerCase());
                  }).toList();

                  if (filteredDrivers.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.w),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_off_outlined, size: 48.sp, color: Colors.grey[400]),
                            SizedBox(height: 8.h),
                            Text(
                              'No drivers found',
                              style: TextStyle(color: Colors.grey[600], fontSize: 15.sp),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: filteredDrivers.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final driver = filteredDrivers[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF1C9E73).withOpacity(0.1),
                            backgroundImage: driver.imageUrl != null && driver.imageUrl!.isNotEmpty
                                ? NetworkImage(driver.imageUrl!)
                                : null,
                            child: driver.imageUrl == null || driver.imageUrl!.isEmpty
                                ? Text(
                                    driver.fullName.isNotEmpty ? driver.fullName[0].toUpperCase() : 'D',
                                    style: const TextStyle(
                                      color: Color(0xFF1B4E41),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          title: Text(
                            driver.fullName,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          subtitle: Text(
                            driver.phoneNumber,
                            style: TextStyle(color: Colors.grey[500], fontSize: 13.sp),
                          ),
                          onTap: () {
                            setState(() {
                              _selectedDriver = driver;
                            });
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareDialog(CustomerEntity customer, EmployeeEntity driver) {
    final feedbackUrl = _generateFeedbackUrl(customer, driver);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        width: 450.w,
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Feedback Link Ready!',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF4F46E5),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            // Customer and Driver Info
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withOpacity(0.03),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, color: Color(0xFF4F46E5), size: 18),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'Customer: ${customer.name}',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.directions_car, color: Color(0xFF1C9E73), size: 18),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'Driver: ${driver.fullName}',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),
            // Link container box
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F6F2),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      feedbackUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey[700],
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  IconButton(
                    icon: Icon(Icons.copy, color: const Color(0xFF4F46E5), size: 18.sp),
                    onPressed: () => _copyToClipboard(feedbackUrl),
                    tooltip: 'Copy Feedback Link',
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),
            // Share actions list
            InkWell(
              onTap: () => _shareToWhatsApp(customer, driver, feedbackUrl),
              borderRadius: BorderRadius.circular(12.r),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[200]!),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8F5E9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.chat_bubble_outline, color: const Color(0xFF25D366), size: 22.w),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Text(
                        'Send to Driver via WhatsApp',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10.h),
            InkWell(
              onTap: () => _shareViaEmail(customer, driver, feedbackUrl),
              borderRadius: BorderRadius.circular(12.r),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[200]!),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFEBEE),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.email_outlined, color: Colors.redAccent, size: 22.w),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Text(
                        'Share with Driver via Email',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10.h),
            InkWell(
              onTap: () => _copyToClipboard(feedbackUrl),
              borderRadius: BorderRadius.circular(12.r),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[200]!),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE3F2FD),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.link, color: const Color(0xFF4F46E5), size: 22.w),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Text(
                        'Copy Link to Clipboard',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24.h),
            // Dialog Footer navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedDriver = null;
                    });
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Change Driver'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
